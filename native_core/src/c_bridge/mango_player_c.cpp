/**
 * MangoPlayer Native Core - C Bridge Implementation
 * 
 * C 语言桥接层实现
 */

#include "mango_player/c_bridge/mango_player_c.h"
#include "mango_player/player_core.h"
#include "mango_player/interfaces/hw_decoder.h"
#include "mango_player/interfaces/texture_output.h"
#include "mango_player/interfaces/audio_output.h"

#include <cstring>

using namespace mango_player;

// =============================================================================
// 内部辅助函数
// =============================================================================

static MangoPlayerState ToMangoState(PlayerState state) {
    switch (state) {
        case PlayerState::Idle: return MANGO_STATE_IDLE;
        case PlayerState::Initializing: return MANGO_STATE_INITIALIZING;
        case PlayerState::Ready: return MANGO_STATE_READY;
        case PlayerState::Playing: return MANGO_STATE_PLAYING;
        case PlayerState::Paused: return MANGO_STATE_PAUSED;
        case PlayerState::Buffering: return MANGO_STATE_BUFFERING;
        case PlayerState::Completed: return MANGO_STATE_COMPLETED;
        case PlayerState::Error: return MANGO_STATE_ERROR;
        default: return MANGO_STATE_IDLE;
    }
}

static MangoErrorCode ToMangoError(ErrorCode code) {
    switch (code) {
        case ErrorCode::None: return MANGO_ERROR_NONE;
        case ErrorCode::InvalidSource: return MANGO_ERROR_INVALID_SOURCE;
        case ErrorCode::NetworkError: return MANGO_ERROR_NETWORK;
        case ErrorCode::DecodeError: return MANGO_ERROR_DECODE;
        case ErrorCode::HardwareDecoderUnavailable: return MANGO_ERROR_HW_UNAVAILABLE;
        case ErrorCode::RenderError: return MANGO_ERROR_RENDER;
        case ErrorCode::AudioOutputError: return MANGO_ERROR_AUDIO;
        default: return MANGO_ERROR_UNKNOWN;
    }
}

static MangoEventType ToMangoEventType(EventType type) {
    switch (type) {
        case EventType::StateChanged: return MANGO_EVENT_STATE_CHANGED;
        case EventType::PositionChanged: return MANGO_EVENT_POSITION_CHANGED;
        case EventType::BufferingUpdate: return MANGO_EVENT_BUFFERING_UPDATE;
        case EventType::DurationChanged: return MANGO_EVENT_DURATION_CHANGED;
        case EventType::VideoSizeChanged: return MANGO_EVENT_VIDEO_SIZE_CHANGED;
        case EventType::FirstFrameRendered: return MANGO_EVENT_FIRST_FRAME;
        case EventType::SeekCompleted: return MANGO_EVENT_SEEK_COMPLETED;
        case EventType::PlaybackCompleted: return MANGO_EVENT_COMPLETED;
        case EventType::Error: return MANGO_EVENT_ERROR;
        case EventType::PerformanceUpdate: return MANGO_EVENT_PERFORMANCE;
        default: return MANGO_EVENT_STATE_CHANGED;
    }
}

// =============================================================================
// 播放器包装结构
// =============================================================================

struct MangoPlayer {
    std::unique_ptr<PlayerCore> core;
    MangoEventCallback callback = nullptr;
    void* user_data = nullptr;
    int listener_id = -1;
    std::string error_message_buffer;  // 用于 C 字符串传递
};

// =============================================================================
// 播放器生命周期
// =============================================================================

MangoPlayerRef mango_player_create(
    MangoHWDecoderRef hw_decoder,
    MangoTextureOutputRef texture_output,
    MangoAudioOutputRef audio_output
) {
    auto player = new MangoPlayer();
    
    // 将不透明指针转换回 C++ 对象
    // 注意: 这里需要各平台实现自己的工厂函数来创建这些对象
    std::unique_ptr<IHardwareDecoder> hw(
        hw_decoder ? reinterpret_cast<IHardwareDecoder*>(hw_decoder) : nullptr
    );
    std::unique_ptr<ITextureOutput> tex(
        texture_output ? reinterpret_cast<ITextureOutput*>(texture_output) : nullptr
    );
    std::unique_ptr<IAudioOutput> audio(
        audio_output ? reinterpret_cast<IAudioOutput*>(audio_output) : nullptr
    );
    
    player->core = std::make_unique<PlayerCore>(
        std::move(hw),
        std::move(tex),
        std::move(audio)
    );
    
    return player;
}

void mango_player_destroy(MangoPlayerRef player) {
    if (player) {
        if (player->listener_id >= 0) {
            player->core->GetEventBridge().RemoveListener(player->listener_id);
        }
        delete player;
    }
}

bool mango_player_initialize(
    MangoPlayerRef player,
    const char* uri,
    const char* headers,
    void* texture_registry
) {
    if (!player || !uri) return false;
    
    std::string uri_str(uri);
    std::string headers_str = headers ? headers : "";
    
    return player->core->Initialize(uri_str, headers_str, texture_registry);
}

void mango_player_release(MangoPlayerRef player) {
    if (player) {
        player->core->Release();
    }
}

// =============================================================================
// 播放控制
// =============================================================================

void mango_player_play(MangoPlayerRef player) {
    if (player) player->core->Play();
}

void mango_player_pause(MangoPlayerRef player) {
    if (player) player->core->Pause();
}

void mango_player_stop(MangoPlayerRef player) {
    if (player) player->core->Stop();
}

void mango_player_seek(MangoPlayerRef player, int64_t position_ms) {
    if (player) player->core->Seek(position_ms);
}

void mango_player_set_speed(MangoPlayerRef player, double speed) {
    if (player) player->core->SetSpeed(speed);
}

void mango_player_set_volume(MangoPlayerRef player, double volume) {
    if (player) player->core->SetVolume(volume);
}

void mango_player_set_mute(MangoPlayerRef player, bool mute) {
    if (player) player->core->SetMute(mute);
}

void mango_player_set_loop(MangoPlayerRef player, bool loop) {
    if (player) player->core->SetLoop(loop);
}

// =============================================================================
// 状态查询
// =============================================================================

MangoPlayerState mango_player_get_state(MangoPlayerRef player) {
    if (!player) return MANGO_STATE_IDLE;
    return ToMangoState(player->core->GetState());
}

int64_t mango_player_get_position(MangoPlayerRef player) {
    if (!player) return 0;
    return player->core->GetPosition();
}

int64_t mango_player_get_duration(MangoPlayerRef player) {
    if (!player) return 0;
    return player->core->GetDuration();
}

double mango_player_get_volume(MangoPlayerRef player) {
    if (!player) return 0.0;
    return player->core->GetVolume();
}

bool mango_player_is_muted(MangoPlayerRef player) {
    if (!player) return false;
    return player->core->IsMuted();
}

int64_t mango_player_get_texture_id(MangoPlayerRef player) {
    if (!player) return -1;
    return player->core->GetTextureId();
}

bool mango_player_get_media_info(MangoPlayerRef player, MangoMediaInfo* out_info) {
    if (!player || !out_info) return false;
    
    MediaInfo info = player->core->GetMediaInfo();
    
    out_info->duration_ms = info.duration_ms;
    out_info->width = info.width;
    out_info->height = info.height;
    out_info->frame_rate = info.frame_rate;
    out_info->audio_channels = info.audio_channels;
    out_info->audio_sample_rate = info.audio_sample_rate;
    out_info->video_codec = info.video_codec.c_str();
    out_info->audio_codec = info.audio_codec.c_str();
    out_info->bitrate = info.bitrate;
    
    return true;
}

// =============================================================================
// 事件监听
// =============================================================================

void mango_player_set_event_callback(
    MangoPlayerRef player,
    MangoEventCallback callback,
    void* user_data
) {
    if (!player) return;
    
    // 移除旧的监听器
    if (player->listener_id >= 0) {
        player->core->GetEventBridge().RemoveListener(player->listener_id);
    }
    
    player->callback = callback;
    player->user_data = user_data;
    
    if (callback) {
        player->listener_id = player->core->GetEventBridge().AddListener(
            [player](const PlayerEvent& event) {
                if (player->callback) {
                    MangoPlayerEvent c_event{};
                    c_event.type = ToMangoEventType(event.type);
                    c_event.state = ToMangoState(event.state);
                    c_event.position_ms = event.position_ms;
                    c_event.buffering_percent = event.buffering_percent;
                    c_event.error_code = ToMangoError(event.error_code);
                    
                    // 存储错误消息以便传递 C 字符串
                    player->error_message_buffer = event.error_message;
                    c_event.error_message = player->error_message_buffer.c_str();
                    
                    c_event.metrics.fps = event.metrics.fps;
                    c_event.metrics.decode_latency_ms = event.metrics.decode_latency_ms;
                    c_event.metrics.render_latency_ms = event.metrics.render_latency_ms;
                    c_event.metrics.dropped_frames = event.metrics.dropped_frames;
                    
                    player->callback(&c_event, player->user_data);
                }
            }
        );
    }
}
