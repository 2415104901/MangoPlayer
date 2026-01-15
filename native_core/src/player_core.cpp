/**
 * MangoPlayer Native Core - Player Core Implementation
 * 
 * 播放器核心实现 - 100% 跨平台逻辑
 * 通过接口调用平台实现
 */

#include "mango_player/player_core.h"

extern "C" {
#include <libavcodec/avcodec.h>
}

namespace mango_player {

PlayerCore::PlayerCore(
    std::unique_ptr<IHardwareDecoder> hw_decoder,
    std::unique_ptr<ITextureOutput> texture_output,
    std::unique_ptr<IAudioOutput> audio_output,
    const PlayerConfig& config
)
    : config_(config)
    , hw_decoder_(std::move(hw_decoder))
    , texture_output_(std::move(texture_output))
    , audio_output_(std::move(audio_output))
{
    demuxer_ = std::make_unique<Demuxer>();
    video_soft_decoder_ = std::make_unique<SoftDecoder>(DecoderType::Video);
    audio_decoder_ = std::make_unique<SoftDecoder>(DecoderType::Audio);
    clock_sync_ = std::make_unique<ClockSync>(config.sync_strategy);

    volume_ = config.initial_volume;
    loop_ = config.loop;
}

PlayerCore::~PlayerCore() {
    Release();
}

bool PlayerCore::Initialize(const std::string& uri, 
                            const std::string& headers,
                            void* texture_registry_handle) {
    SetState(PlayerState::Initializing);

    // 打开媒体源
    if (!demuxer_->Open(uri, headers)) {
        event_bridge_.EmitError(ErrorCode::InvalidSource, "Failed to open media source");
        SetState(PlayerState::Error);
        return false;
    }

    MediaInfo info = demuxer_->GetMediaInfo();
    event_bridge_.EmitDurationChanged(info.duration_ms);

    // 初始化解码器
    if (!InitializeDecoders()) {
        SetState(PlayerState::Error);
        return false;
    }

    // 初始化纹理输出
    if (texture_output_) {
        if (!texture_output_->Initialize(info.width, info.height, texture_registry_handle)) {
            event_bridge_.EmitError(ErrorCode::TextureCreationFailed, "Failed to initialize texture output");
            SetState(PlayerState::Error);
            return false;
        }
    }

    // 初始化音频输出
    if (audio_output_ && config_.enable_audio && demuxer_->GetAudioStreamIndex() >= 0) {
        auto* audio_params = demuxer_->GetAudioCodecParams();
        if (audio_params) {
            if (!audio_output_->Initialize(
                    audio_params->sample_rate,
                    audio_params->ch_layout.nb_channels,
                    16  // 16-bit PCM
                )) {
                // 音频失败不是致命错误，继续播放
                event_bridge_.EmitError(ErrorCode::AudioOutputError, "Audio output init failed, continuing without audio");
            }
            audio_output_->SetVolume(static_cast<float>(volume_.load()));
        }
    }

    SetState(PlayerState::Ready);
    return true;
}

bool PlayerCore::InitializeDecoders() {
    // 初始化视频解码器
    auto* video_params = demuxer_->GetVideoCodecParams();
    if (video_params) {
        // 尝试硬件解码
        if (config_.enable_hardware_decode && hw_decoder_) {
            if (hw_decoder_->IsSupported(video_params->codec_id)) {
                // TODO: 需要先创建 AVCodecContext 再传给硬件解码器
                // 这里简化处理，实际需要更复杂的流程
                use_hw_decoder_ = true;
            }
        }

        // 如果硬件解码不可用，使用软解
        if (!use_hw_decoder_) {
            if (!video_soft_decoder_->Initialize(video_params)) {
                event_bridge_.EmitError(ErrorCode::DecodeError, "Failed to initialize video decoder");
                return false;
            }
        }
    }

    // 初始化音频解码器
    auto* audio_params = demuxer_->GetAudioCodecParams();
    if (audio_params && config_.enable_audio) {
        if (!audio_decoder_->Initialize(audio_params)) {
            // 音频解码失败不是致命错误
            event_bridge_.EmitError(ErrorCode::DecodeError, "Failed to initialize audio decoder");
        }
    }

    return true;
}

void PlayerCore::Release() {
    StopThreads();

    if (texture_output_) {
        texture_output_->Release();
    }
    if (audio_output_) {
        audio_output_->Release();
    }
    if (hw_decoder_) {
        hw_decoder_->Release();
    }

    video_soft_decoder_->Release();
    audio_decoder_->Release();
    demuxer_->Close();

    SetState(PlayerState::Idle);
}

void PlayerCore::Play() {
    if (state_ == PlayerState::Ready || state_ == PlayerState::Paused) {
        if (state_ == PlayerState::Paused) {
            clock_sync_->Resume();
            if (audio_output_) {
                audio_output_->Resume();
            }
        } else {
            clock_sync_->Start();
            if (audio_output_) {
                audio_output_->Start();
            }
            StartThreads();
        }
        SetState(PlayerState::Playing);
    }
}

void PlayerCore::Pause() {
    if (state_ == PlayerState::Playing) {
        clock_sync_->Pause();
        if (audio_output_) {
            audio_output_->Pause();
        }
        SetState(PlayerState::Paused);
    }
}

void PlayerCore::Stop() {
    StopThreads();
    clock_sync_->Reset();
    if (audio_output_) {
        audio_output_->Stop();
    }
    demuxer_->Seek(0);
    video_soft_decoder_->Reset();
    audio_decoder_->Reset();
    if (hw_decoder_) {
        hw_decoder_->Reset();
    }
    SetState(PlayerState::Ready);
}

void PlayerCore::Seek(int64_t position_ms) {
    if (demuxer_->Seek(position_ms)) {
        clock_sync_->Reset();
        video_soft_decoder_->Reset();
        audio_decoder_->Reset();
        if (hw_decoder_) {
            hw_decoder_->Reset();
        }
        if (audio_output_) {
            audio_output_->Flush();
        }
        event_bridge_.EmitSeekCompleted(position_ms);
    }
}

void PlayerCore::SetSpeed(double speed) {
    clock_sync_->SetSpeed(speed);
}

void PlayerCore::SetVolume(double volume) {
    volume_ = std::max(0.0, std::min(1.0, volume));
    if (audio_output_) {
        audio_output_->SetVolume(static_cast<float>(volume_.load()));
    }
}

void PlayerCore::SetMute(bool mute) {
    muted_ = mute;
    if (audio_output_) {
        audio_output_->SetMute(mute);
    }
}

void PlayerCore::SetLoop(bool loop) {
    loop_ = loop;
}

int64_t PlayerCore::GetPosition() const {
    return clock_sync_->GetCurrentPositionMs();
}

int64_t PlayerCore::GetDuration() const {
    return demuxer_->GetMediaInfo().duration_ms;
}

double PlayerCore::GetVolume() const {
    return volume_.load();
}

bool PlayerCore::IsMuted() const {
    return muted_.load();
}

MediaInfo PlayerCore::GetMediaInfo() const {
    return demuxer_->GetMediaInfo();
}

int64_t PlayerCore::GetTextureId() const {
    return texture_output_ ? texture_output_->GetTextureId() : -1;
}

void PlayerCore::SetState(PlayerState new_state) {
    PlayerState old_state = state_.exchange(new_state);
    if (old_state != new_state) {
        event_bridge_.EmitStateChanged(new_state);
    }
}

void PlayerCore::StartThreads() {
    should_stop_ = false;
    demux_thread_ = std::make_unique<std::thread>(&PlayerCore::DemuxThreadFunc, this);
    video_decode_thread_ = std::make_unique<std::thread>(&PlayerCore::VideoDecodeThreadFunc, this);
    audio_decode_thread_ = std::make_unique<std::thread>(&PlayerCore::AudioDecodeThreadFunc, this);
}

void PlayerCore::StopThreads() {
    should_stop_ = true;
    cv_.notify_all();

    if (demux_thread_ && demux_thread_->joinable()) {
        demux_thread_->join();
    }
    if (video_decode_thread_ && video_decode_thread_->joinable()) {
        video_decode_thread_->join();
    }
    if (audio_decode_thread_ && audio_decode_thread_->joinable()) {
        audio_decode_thread_->join();
    }

    demux_thread_.reset();
    video_decode_thread_.reset();
    audio_decode_thread_.reset();
}

void PlayerCore::DemuxThreadFunc() {
    // TODO: 实现解复用线程
    // 从 demuxer 读取包，分发到视频/音频队列
    while (!should_stop_) {
        if (state_ != PlayerState::Playing) {
            std::unique_lock<std::mutex> lock(mutex_);
            cv_.wait(lock, [this] { 
                return should_stop_ || state_ == PlayerState::Playing; 
            });
            continue;
        }

        // 实际实现需要包队列管理
        // 这里是骨架代码
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

void PlayerCore::VideoDecodeThreadFunc() {
    // TODO: 实现视频解码线程
    while (!should_stop_) {
        if (state_ != PlayerState::Playing) {
            std::unique_lock<std::mutex> lock(mutex_);
            cv_.wait(lock, [this] { 
                return should_stop_ || state_ == PlayerState::Playing; 
            });
            continue;
        }

        // 实际实现需要从队列取包、解码、同步、渲染
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

void PlayerCore::AudioDecodeThreadFunc() {
    // TODO: 实现音频解码线程
    while (!should_stop_) {
        if (state_ != PlayerState::Playing) {
            std::unique_lock<std::mutex> lock(mutex_);
            cv_.wait(lock, [this] { 
                return should_stop_ || state_ == PlayerState::Playing; 
            });
            continue;
        }

        // 实际实现需要从队列取包、解码、输出
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

} // namespace mango_player
