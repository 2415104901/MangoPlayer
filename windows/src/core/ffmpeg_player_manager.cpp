// MangoPlayer Windows Plugin
// FFmpeg Player Manager Implementation

#include "ffmpeg_player_manager.h"
#include "native_core/ffmpeg_demuxer.h"
#include "native_core/ffmpeg_soft_decoder.h"
#include "native_core/clock_sync.h"
#include "native_core/core_event_bridge.h"
#include "dxva_decoder.h"
#include "../renderer/d3d11_texture_renderer.h"

extern "C" {
#include <libavutil/frame.h>
}

#include <chrono>

namespace mango_player {

FFmpegPlayerManager::FFmpegPlayerManager() {
  clock_ = std::make_shared<native_core::ClockSync>();
  event_bridge_ = std::make_shared<native_core::CoreEventBridge>();
}

FFmpegPlayerManager::~FFmpegPlayerManager() {
  Release();
}

int64_t FFmpegPlayerManager::Initialize(const std::string& uri, const std::string& type,
                                         const std::map<std::string, std::string>& headers,
                                         std::optional<int64_t> texture_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  // Stop any existing playback
  if (is_initialized_.load()) {
    Release();
  }

  UpdateState("initializing");

  // Create demuxer
  demuxer_ = std::make_shared<native_core::FFmpegDemuxer>();
  demuxer_->SetErrorCallback([this](int code, const std::string& msg) {
    OnDecoderError(code, msg);
  });

  // Configure demuxer
  native_core::DemuxerConfig config;
  config.uri = uri;
  config.headers = headers;

  // Open media
  if (!demuxer_->Open(config)) {
    UpdateState("error");
    return 0;
  }

  duration_ms_ = demuxer_->GetDuration();

  // Try hardware decoding first
  use_hw_decoder_.store(false);
  // Note: Hardware decoding setup would require a D3D11 device
  // For now, we use software decoding

  // Create software decoder
  soft_decoder_ = std::make_shared<native_core::FFmpegSoftDecoder>(demuxer_);
  soft_decoder_->SetVideoFrameCallback([this](AVFrame* frame, int64_t pts_ms) {
    OnVideoFrame(frame, pts_ms);
  });
  soft_decoder_->SetAudioFrameCallback([this](AVFrame* frame, int64_t pts_ms) {
    OnAudioFrame(frame, pts_ms);
  });
  soft_decoder_->SetErrorCallback([this](int code, const std::string& msg) {
    OnDecoderError(code, msg);
  });

  // Reset clock
  clock_->Reset();

  is_initialized_.store(true);
  UpdateState("ready");

  return duration_ms_;
}

void FFmpegPlayerManager::Play() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_initialized_.load()) return;

  if (current_state_ == "paused") {
    // Resume
    if (soft_decoder_) {
      soft_decoder_->SetPaused(false);
    }
    clock_->Resume();
  } else if (current_state_ == "ready" || current_state_ == "completed") {
    // Start from beginning or current position
    if (soft_decoder_) {
      soft_decoder_->Start();
    }
    clock_->Resume();
    StartProgressTimer();
  }

  UpdateState("playing");
}

void FFmpegPlayerManager::Pause() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_initialized_.load()) return;
  if (current_state_ != "playing") return;

  if (soft_decoder_) {
    soft_decoder_->SetPaused(true);
  }
  clock_->Pause();

  UpdateState("paused");
}

void FFmpegPlayerManager::Stop() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_initialized_.load()) return;

  StopProgressTimer();

  if (soft_decoder_) {
    soft_decoder_->Stop();
  }

  clock_->Reset();

  UpdateState("idle");
}

int64_t FFmpegPlayerManager::SeekTo(int64_t position_ms) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_initialized_.load() || !demuxer_) return 0;

  // Clamp position
  if (position_ms < 0) position_ms = 0;
  if (position_ms > duration_ms_) position_ms = duration_ms_;

  // Seek in demuxer
  if (!demuxer_->SeekTo(position_ms)) {
    return clock_->GetCurrentPts();
  }

  // Flush decoder
  if (soft_decoder_) {
    soft_decoder_->Flush();
  }

  // Update clock
  clock_->Seek(position_ms);

  return position_ms;
}

void FFmpegPlayerManager::SetVolume(double volume) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  // Clamp volume
  if (volume < 0.0) volume = 0.0;
  if (volume > 1.0) volume = 1.0;
  
  volume_ = volume;
  // Audio volume would be applied in audio output module
}

void FFmpegPlayerManager::SetPlaybackSpeed(double speed) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  // Clamp speed
  if (speed < 0.5) speed = 0.5;
  if (speed > 2.0) speed = 2.0;
  
  playback_speed_ = speed;
  clock_->SetPlaybackSpeed(speed);
}

int64_t FFmpegPlayerManager::GetPosition() {
  return clock_->GetCurrentPts();
}

int64_t FFmpegPlayerManager::GetDuration() {
  return duration_ms_;
}

void FFmpegPlayerManager::Release() {
  StopProgressTimer();

  if (soft_decoder_) {
    soft_decoder_->Stop();
    soft_decoder_.reset();
  }

  if (hw_decoder_) {
    hw_decoder_->Release();
    hw_decoder_.reset();
  }

  if (demuxer_) {
    demuxer_->Close();
    demuxer_.reset();
  }

  clock_->Reset();
  is_initialized_.store(false);
  UpdateState("idle");
}

void FFmpegPlayerManager::SetTextureRenderer(std::shared_ptr<D3D11TextureRenderer> renderer) {
  std::lock_guard<std::mutex> lock(mutex_);
  texture_renderer_ = renderer;
}

void FFmpegPlayerManager::SetEventCallback(ProgressEventCallback progress_cb, 
                                           StateEventCallback state_cb) {
  std::lock_guard<std::mutex> lock(mutex_);
  progress_callback_ = progress_cb;
  state_callback_ = state_cb;
}

void FFmpegPlayerManager::StartProgressTimer() {
  if (progress_running_.load()) return;

  progress_running_.store(true);
  progress_thread_ = std::thread([this]() {
    while (progress_running_.load()) {
      if (progress_callback_ && is_initialized_.load()) {
        int64_t position = clock_->GetCurrentPts();
        int64_t duration = duration_ms_;
        int64_t buffered = position;  // Simplified, would track actual buffer
        double buffer_pct = duration > 0 ? static_cast<double>(buffered) / duration : 0.0;
        
        progress_callback_("progress", position, duration, buffered, buffer_pct);
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
  });
}

void FFmpegPlayerManager::StopProgressTimer() {
  progress_running_.store(false);
  if (progress_thread_.joinable()) {
    progress_thread_.join();
  }
}

void FFmpegPlayerManager::OnVideoFrame(AVFrame* frame, int64_t pts_ms) {
  // Update clock with video PTS
  clock_->SetMasterPts(pts_ms);

  // Render to texture
  if (texture_renderer_) {
    texture_renderer_->UpdateWithAVFrame(frame, pts_ms);
  }
}

void FFmpegPlayerManager::OnAudioFrame(AVFrame* frame, int64_t pts_ms) {
  // Audio playback would be handled here
  // For now, we just use audio for sync reference
}

void FFmpegPlayerManager::OnDecoderError(int code, const std::string& message) {
  UpdateState("error");
  
  if (event_bridge_) {
    event_bridge_->EmitError(std::to_string(code), message);
  }
}

void FFmpegPlayerManager::UpdateState(const std::string& state) {
  current_state_ = state;
  if (state_callback_) {
    state_callback_(state);
  }
}

}  // namespace mango_player
