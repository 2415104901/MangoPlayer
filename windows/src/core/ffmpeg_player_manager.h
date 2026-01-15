// MangoPlayer Windows Plugin
// FFmpeg Player Manager - Core Player Logic

#ifndef FFMPEG_PLAYER_MANAGER_H_
#define FFMPEG_PLAYER_MANAGER_H_

#include <memory>
#include <string>
#include <map>
#include <functional>
#include <thread>
#include <atomic>
#include <mutex>
#include <optional>

namespace mango_player {

// Forward declarations
class D3D11TextureRenderer;

namespace native_core {
class FFmpegDemuxer;
class FFmpegSoftDecoder;
class ClockSync;
class CoreEventBridge;
}

class DXVADecoder;

// Callback types for event channel
using ProgressEventCallback = std::function<void(const std::string& type, int64_t position, 
                                                  int64_t duration, int64_t buffered, 
                                                  double buffer_pct)>;
using StateEventCallback = std::function<void(const std::string& state)>;

class FFmpegPlayerManager {
 public:
  FFmpegPlayerManager();
  ~FFmpegPlayerManager();

  // Player control
  int64_t Initialize(const std::string& uri, const std::string& type,
                     const std::map<std::string, std::string>& headers,
                     std::optional<int64_t> texture_id);
  void Play();
  void Pause();
  void Stop();
  int64_t SeekTo(int64_t position_ms);
  void SetVolume(double volume);
  void SetPlaybackSpeed(double speed);
  int64_t GetPosition();
  int64_t GetDuration();
  void Release();

  // Texture management
  void SetTextureRenderer(std::shared_ptr<D3D11TextureRenderer> renderer);

  // Event callbacks
  void SetEventCallback(ProgressEventCallback progress_cb, StateEventCallback state_cb);

 private:
  void StartProgressTimer();
  void StopProgressTimer();
  void OnVideoFrame(struct AVFrame* frame, int64_t pts_ms);
  void OnAudioFrame(struct AVFrame* frame, int64_t pts_ms);
  void OnDecoderError(int code, const std::string& message);
  void UpdateState(const std::string& state);

  std::shared_ptr<native_core::FFmpegDemuxer> demuxer_;
  std::shared_ptr<native_core::FFmpegSoftDecoder> soft_decoder_;
  std::shared_ptr<DXVADecoder> hw_decoder_;
  std::shared_ptr<native_core::ClockSync> clock_;
  std::shared_ptr<native_core::CoreEventBridge> event_bridge_;
  std::shared_ptr<D3D11TextureRenderer> texture_renderer_;

  ProgressEventCallback progress_callback_;
  StateEventCallback state_callback_;

  std::string current_state_ = "idle";
  double volume_ = 1.0;
  double playback_speed_ = 1.0;
  int64_t duration_ms_ = 0;

  std::thread progress_thread_;
  std::atomic<bool> progress_running_{false};

  std::mutex mutex_;
  std::atomic<bool> is_initialized_{false};
  std::atomic<bool> use_hw_decoder_{false};
};

}  // namespace mango_player

#endif  // FFMPEG_PLAYER_MANAGER_H_
