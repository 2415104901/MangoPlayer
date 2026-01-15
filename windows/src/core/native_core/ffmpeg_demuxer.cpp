// MangoPlayer Windows Plugin
// FFmpeg Demuxer - Native Core Implementation

#include "ffmpeg_demuxer.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/dict.h>
#include <libavutil/opt.h>
}

#include <sstream>

namespace mango_player {
namespace native_core {

FFmpegDemuxer::FFmpegDemuxer() {}

FFmpegDemuxer::~FFmpegDemuxer() {
  Close();
}

bool FFmpegDemuxer::Open(const DemuxerConfig& config) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (is_open_) {
    Close();
  }

  // Initialize FFmpeg (deprecated in newer versions, but safe to call)
  #if LIBAVFORMAT_VERSION_INT < AV_VERSION_INT(58, 9, 100)
  av_register_all();
  #endif
  avformat_network_init();

  format_context_ = avformat_alloc_context();
  if (!format_context_) {
    NotifyError(-1, "Failed to allocate format context");
    return false;
  }

  // Set options
  AVDictionary* options = nullptr;
  
  // Add HTTP headers if provided
  if (!config.headers.empty()) {
    std::stringstream headers_str;
    for (const auto& pair : config.headers) {
      headers_str << pair.first << ": " << pair.second << "\r\n";
    }
    av_dict_set(&options, "headers", headers_str.str().c_str(), 0);
  }

  // Set probe size and analyze duration
  av_dict_set_int(&options, "probesize", config.probe_size, 0);
  av_dict_set_int(&options, "analyzeduration", config.analyze_duration, 0);

  // Open input
  int ret = avformat_open_input(&format_context_, config.uri.c_str(), nullptr, &options);
  av_dict_free(&options);

  if (ret < 0) {
    char err_buf[256];
    av_strerror(ret, err_buf, sizeof(err_buf));
    NotifyError(ret, std::string("Failed to open input: ") + err_buf);
    format_context_ = nullptr;
    return false;
  }

  // Find stream info
  ret = avformat_find_stream_info(format_context_, nullptr);
  if (ret < 0) {
    char err_buf[256];
    av_strerror(ret, err_buf, sizeof(err_buf));
    NotifyError(ret, std::string("Failed to find stream info: ") + err_buf);
    avformat_close_input(&format_context_);
    return false;
  }

  // Find video and audio streams
  if (!FindStreams()) {
    avformat_close_input(&format_context_);
    return false;
  }

  is_open_ = true;
  return true;
}

void FFmpegDemuxer::Close() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (video_codec_context_) {
    avcodec_free_context(&video_codec_context_);
  }
  if (audio_codec_context_) {
    avcodec_free_context(&audio_codec_context_);
  }
  if (format_context_) {
    avformat_close_input(&format_context_);
  }

  video_stream_index_ = -1;
  audio_stream_index_ = -1;
  is_open_ = false;
}

bool FFmpegDemuxer::FindStreams() {
  // Find best video stream
  video_stream_index_ = av_find_best_stream(format_context_, AVMEDIA_TYPE_VIDEO, 
                                             -1, -1, nullptr, 0);
  if (video_stream_index_ >= 0) {
    if (!OpenCodecContext(video_stream_index_, &video_codec_context_)) {
      video_stream_index_ = -1;
    } else {
      NotifyStreamInfo(video_stream_index_);
    }
  }

  // Find best audio stream
  audio_stream_index_ = av_find_best_stream(format_context_, AVMEDIA_TYPE_AUDIO,
                                             -1, -1, nullptr, 0);
  if (audio_stream_index_ >= 0) {
    if (!OpenCodecContext(audio_stream_index_, &audio_codec_context_)) {
      audio_stream_index_ = -1;
    } else {
      NotifyStreamInfo(audio_stream_index_);
    }
  }

  // We need at least video or audio
  if (video_stream_index_ < 0 && audio_stream_index_ < 0) {
    NotifyError(-1, "No video or audio stream found");
    return false;
  }

  return true;
}

bool FFmpegDemuxer::OpenCodecContext(int stream_index, AVCodecContext** ctx) {
  AVStream* stream = format_context_->streams[stream_index];
  const AVCodec* codec = avcodec_find_decoder(stream->codecpar->codec_id);
  
  if (!codec) {
    NotifyError(-1, "Decoder not found for stream");
    return false;
  }

  *ctx = avcodec_alloc_context3(codec);
  if (!*ctx) {
    NotifyError(-1, "Failed to allocate codec context");
    return false;
  }

  int ret = avcodec_parameters_to_context(*ctx, stream->codecpar);
  if (ret < 0) {
    avcodec_free_context(ctx);
    NotifyError(ret, "Failed to copy codec parameters");
    return false;
  }

  // Set time base
  (*ctx)->pkt_timebase = stream->time_base;

  ret = avcodec_open2(*ctx, codec, nullptr);
  if (ret < 0) {
    avcodec_free_context(ctx);
    NotifyError(ret, "Failed to open codec");
    return false;
  }

  return true;
}

bool FFmpegDemuxer::ReadPacket(AVPacket* packet, PacketInfo* info) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_open_ || !format_context_) {
    return false;
  }

  int ret = av_read_frame(format_context_, packet);
  if (ret < 0) {
    if (ret == AVERROR_EOF) {
      // End of file
      return false;
    }
    NotifyError(ret, "Error reading frame");
    return false;
  }

  if (info) {
    info->stream_index = packet->stream_index;
    info->pts = packet->pts;
    info->dts = packet->dts;
    info->duration = packet->duration;
    info->is_keyframe = (packet->flags & AV_PKT_FLAG_KEY) != 0;
  }

  return true;
}

bool FFmpegDemuxer::SeekTo(int64_t position_ms) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_open_ || !format_context_) {
    return false;
  }

  int64_t timestamp = position_ms * 1000;  // Convert to microseconds for AV_TIME_BASE
  
  int ret = av_seek_frame(format_context_, -1, timestamp, AVSEEK_FLAG_BACKWARD);
  if (ret < 0) {
    NotifyError(ret, "Seek failed");
    return false;
  }

  // Flush codec buffers
  if (video_codec_context_) {
    avcodec_flush_buffers(video_codec_context_);
  }
  if (audio_codec_context_) {
    avcodec_flush_buffers(audio_codec_context_);
  }

  return true;
}

int64_t FFmpegDemuxer::GetDuration() const {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!format_context_) {
    return 0;
  }

  if (format_context_->duration == AV_NOPTS_VALUE) {
    return 0;
  }

  // Convert from AV_TIME_BASE (microseconds) to milliseconds
  return format_context_->duration / 1000;
}

AVCodecContext* FFmpegDemuxer::GetVideoCodecContext() {
  return video_codec_context_;
}

AVCodecContext* FFmpegDemuxer::GetAudioCodecContext() {
  return audio_codec_context_;
}

int FFmpegDemuxer::GetVideoWidth() const {
  std::lock_guard<std::mutex> lock(mutex_);
  if (video_codec_context_) {
    return video_codec_context_->width;
  }
  return 0;
}

int FFmpegDemuxer::GetVideoHeight() const {
  std::lock_guard<std::mutex> lock(mutex_);
  if (video_codec_context_) {
    return video_codec_context_->height;
  }
  return 0;
}

double FFmpegDemuxer::GetVideoFrameRate() const {
  std::lock_guard<std::mutex> lock(mutex_);
  if (format_context_ && video_stream_index_ >= 0) {
    AVStream* stream = format_context_->streams[video_stream_index_];
    if (stream->avg_frame_rate.den != 0) {
      return av_q2d(stream->avg_frame_rate);
    }
    if (stream->r_frame_rate.den != 0) {
      return av_q2d(stream->r_frame_rate);
    }
  }
  return 30.0;  // Default
}

void FFmpegDemuxer::NotifyError(int code, const std::string& message) {
  if (error_callback_) {
    error_callback_(code, message);
  }
}

void FFmpegDemuxer::NotifyStreamInfo(int stream_index) {
  if (!stream_info_callback_ || !format_context_) return;

  AVStream* stream = format_context_->streams[stream_index];
  AVCodecParameters* codecpar = stream->codecpar;

  const AVCodec* codec = avcodec_find_decoder(codecpar->codec_id);
  std::string codec_name = codec ? codec->name : "unknown";

  int width = 0, height = 0;
  double frame_rate = 0;
  int sample_rate = 0, channels = 0;

  if (codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
    width = codecpar->width;
    height = codecpar->height;
    if (stream->avg_frame_rate.den != 0) {
      frame_rate = av_q2d(stream->avg_frame_rate);
    }
  } else if (codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
    sample_rate = codecpar->sample_rate;
    #if LIBAVCODEC_VERSION_INT >= AV_VERSION_INT(59, 24, 100)
    channels = codecpar->ch_layout.nb_channels;
    #else
    channels = codecpar->channels;
    #endif
  }

  stream_info_callback_(stream_index, codec_name, width, height, frame_rate, sample_rate, channels);
}

}  // namespace native_core
}  // namespace mango_player
