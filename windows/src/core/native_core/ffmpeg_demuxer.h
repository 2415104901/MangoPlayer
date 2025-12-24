// MangoPlayer Windows Plugin
// FFmpeg Demuxer - Native Core (Shared with macOS)

#ifndef FFMPEG_DEMUXER_H_
#define FFMPEG_DEMUXER_H_

#include <string>
#include <functional>
#include <memory>
#include <map>
#include <mutex>

// Forward declarations for FFmpeg types
extern "C" {
struct AVFormatContext;
struct AVCodecContext;
struct AVPacket;
struct AVFrame;
}

namespace mango_player {
namespace native_core {

// Callback types
using ErrorCallback = std::function<void(int code, const std::string& message)>;
using StreamInfoCallback = std::function<void(int stream_index, const std::string& codec_name, 
                                               int width, int height, double frame_rate, 
                                               int sample_rate, int channels)>;

struct DemuxerConfig {
  std::string uri;
  std::map<std::string, std::string> headers;
  int64_t start_time_ms = 0;
  int probe_size = 5000000;  // 5MB
  int analyze_duration = 5000000;  // 5 seconds in microseconds
};

struct PacketInfo {
  int stream_index;
  int64_t pts;
  int64_t dts;
  int64_t duration;
  bool is_keyframe;
};

class FFmpegDemuxer {
 public:
  FFmpegDemuxer();
  ~FFmpegDemuxer();

  // Initialize and open media source
  bool Open(const DemuxerConfig& config);
  void Close();

  // Read next packet
  bool ReadPacket(AVPacket* packet, PacketInfo* info);

  // Seek to position (in milliseconds)
  bool SeekTo(int64_t position_ms);

  // Get stream info
  int64_t GetDuration() const;  // in milliseconds
  int GetVideoStreamIndex() const { return video_stream_index_; }
  int GetAudioStreamIndex() const { return audio_stream_index_; }
  
  // Get codec context for decoder setup
  AVCodecContext* GetVideoCodecContext();
  AVCodecContext* GetAudioCodecContext();

  // Get video dimensions
  int GetVideoWidth() const;
  int GetVideoHeight() const;
  double GetVideoFrameRate() const;

  // Set callbacks
  void SetErrorCallback(ErrorCallback callback) { error_callback_ = callback; }
  void SetStreamInfoCallback(StreamInfoCallback callback) { stream_info_callback_ = callback; }

  bool IsOpen() const { return format_context_ != nullptr; }

 private:
  bool FindStreams();
  bool OpenCodecContext(int stream_index, AVCodecContext** ctx);
  void NotifyError(int code, const std::string& message);
  void NotifyStreamInfo(int stream_index);

  AVFormatContext* format_context_ = nullptr;
  AVCodecContext* video_codec_context_ = nullptr;
  AVCodecContext* audio_codec_context_ = nullptr;

  int video_stream_index_ = -1;
  int audio_stream_index_ = -1;

  ErrorCallback error_callback_;
  StreamInfoCallback stream_info_callback_;

  mutable std::mutex mutex_;
  bool is_open_ = false;
};

}  // namespace native_core
}  // namespace mango_player

#endif  // FFMPEG_DEMUXER_H_
