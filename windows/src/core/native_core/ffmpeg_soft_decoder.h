// MangoPlayer Windows Plugin
// FFmpeg Soft Decoder - Native Core (Shared with macOS)

#ifndef FFMPEG_SOFT_DECODER_H_
#define FFMPEG_SOFT_DECODER_H_

#include <functional>
#include <memory>
#include <mutex>
#include <queue>
#include <thread>
#include <atomic>
#include <condition_variable>

// Forward declarations for FFmpeg types
extern "C" {
struct AVCodecContext;
struct AVPacket;
struct AVFrame;
}

namespace mango_player {
namespace native_core {

class FFmpegDemuxer;

// Callback for decoded frames
using VideoFrameCallback = std::function<void(AVFrame* frame, int64_t pts_ms)>;
using AudioFrameCallback = std::function<void(AVFrame* frame, int64_t pts_ms)>;
using DecoderErrorCallback = std::function<void(int code, const std::string& message)>;

class FFmpegSoftDecoder {
 public:
  FFmpegSoftDecoder(std::shared_ptr<FFmpegDemuxer> demuxer);
  ~FFmpegSoftDecoder();

  // Start/stop decoding
  bool Start();
  void Stop();
  bool IsRunning() const { return is_running_.load(); }

  // Set callbacks for decoded frames
  void SetVideoFrameCallback(VideoFrameCallback callback) { video_frame_callback_ = callback; }
  void SetAudioFrameCallback(AudioFrameCallback callback) { audio_frame_callback_ = callback; }
  void SetErrorCallback(DecoderErrorCallback callback) { error_callback_ = callback; }

  // Flush decoder (after seek)
  void Flush();

  // Pause/resume decoding
  void SetPaused(bool paused);
  bool IsPaused() const { return is_paused_.load(); }

 private:
  void DecoderThread();
  bool DecodePacket(AVPacket* packet);
  void ProcessVideoFrame(AVFrame* frame);
  void ProcessAudioFrame(AVFrame* frame);
  int64_t ConvertPts(int64_t pts, bool is_video);

  std::shared_ptr<FFmpegDemuxer> demuxer_;

  VideoFrameCallback video_frame_callback_;
  AudioFrameCallback audio_frame_callback_;
  DecoderErrorCallback error_callback_;

  std::thread decoder_thread_;
  std::atomic<bool> is_running_{false};
  std::atomic<bool> is_paused_{false};
  std::atomic<bool> should_stop_{false};

  std::mutex pause_mutex_;
  std::condition_variable pause_cv_;

  // Pre-allocated frames
  AVFrame* video_frame_ = nullptr;
  AVFrame* audio_frame_ = nullptr;
};

}  // namespace native_core
}  // namespace mango_player

#endif  // FFMPEG_SOFT_DECODER_H_
