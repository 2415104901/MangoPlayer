// MangoPlayer Windows Plugin
// FFmpeg Soft Decoder - Native Core Implementation

#include "ffmpeg_soft_decoder.h"
#include "ffmpeg_demuxer.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/frame.h>
#include <libavutil/time.h>
}

namespace mango_player {
namespace native_core {

FFmpegSoftDecoder::FFmpegSoftDecoder(std::shared_ptr<FFmpegDemuxer> demuxer)
    : demuxer_(demuxer) {
  video_frame_ = av_frame_alloc();
  audio_frame_ = av_frame_alloc();
}

FFmpegSoftDecoder::~FFmpegSoftDecoder() {
  Stop();
  
  if (video_frame_) {
    av_frame_free(&video_frame_);
  }
  if (audio_frame_) {
    av_frame_free(&audio_frame_);
  }
}

bool FFmpegSoftDecoder::Start() {
  if (is_running_.load()) {
    return true;
  }

  if (!demuxer_ || !demuxer_->IsOpen()) {
    if (error_callback_) {
      error_callback_(-1, "Demuxer not open");
    }
    return false;
  }

  should_stop_.store(false);
  is_running_.store(true);
  is_paused_.store(false);

  decoder_thread_ = std::thread(&FFmpegSoftDecoder::DecoderThread, this);
  return true;
}

void FFmpegSoftDecoder::Stop() {
  should_stop_.store(true);
  is_paused_.store(false);
  pause_cv_.notify_all();

  if (decoder_thread_.joinable()) {
    decoder_thread_.join();
  }

  is_running_.store(false);
}

void FFmpegSoftDecoder::SetPaused(bool paused) {
  is_paused_.store(paused);
  if (!paused) {
    pause_cv_.notify_all();
  }
}

void FFmpegSoftDecoder::Flush() {
  AVCodecContext* video_ctx = demuxer_->GetVideoCodecContext();
  AVCodecContext* audio_ctx = demuxer_->GetAudioCodecContext();

  if (video_ctx) {
    avcodec_flush_buffers(video_ctx);
  }
  if (audio_ctx) {
    avcodec_flush_buffers(audio_ctx);
  }
}

void FFmpegSoftDecoder::DecoderThread() {
  AVPacket* packet = av_packet_alloc();
  if (!packet) {
    if (error_callback_) {
      error_callback_(-1, "Failed to allocate packet");
    }
    is_running_.store(false);
    return;
  }

  while (!should_stop_.load()) {
    // Handle pause
    {
      std::unique_lock<std::mutex> lock(pause_mutex_);
      while (is_paused_.load() && !should_stop_.load()) {
        pause_cv_.wait(lock);
      }
    }

    if (should_stop_.load()) break;

    // Read and decode packet
    native_core::PacketInfo packet_info;
    if (demuxer_->ReadPacket(packet, &packet_info)) {
      DecodePacket(packet);
      av_packet_unref(packet);
    } else {
      // EOF or error - notify and stop
      break;
    }
  }

  av_packet_free(&packet);
  is_running_.store(false);
}

bool FFmpegSoftDecoder::DecodePacket(AVPacket* packet) {
  AVCodecContext* ctx = nullptr;
  AVFrame* frame = nullptr;
  bool is_video = false;

  if (packet->stream_index == demuxer_->GetVideoStreamIndex()) {
    ctx = demuxer_->GetVideoCodecContext();
    frame = video_frame_;
    is_video = true;
  } else if (packet->stream_index == demuxer_->GetAudioStreamIndex()) {
    ctx = demuxer_->GetAudioCodecContext();
    frame = audio_frame_;
    is_video = false;
  } else {
    return true;  // Skip other streams
  }

  if (!ctx) return false;

  // Send packet to decoder
  int ret = avcodec_send_packet(ctx, packet);
  if (ret < 0) {
    if (ret != AVERROR_EOF && ret != AVERROR(EAGAIN)) {
      if (error_callback_) {
        error_callback_(ret, "Error sending packet to decoder");
      }
    }
    return false;
  }

  // Receive decoded frames
  while (ret >= 0) {
    ret = avcodec_receive_frame(ctx, frame);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
      break;
    } else if (ret < 0) {
      if (error_callback_) {
        error_callback_(ret, "Error receiving frame from decoder");
      }
      return false;
    }

    // Process frame
    if (is_video) {
      ProcessVideoFrame(frame);
    } else {
      ProcessAudioFrame(frame);
    }

    av_frame_unref(frame);
  }

  return true;
}

void FFmpegSoftDecoder::ProcessVideoFrame(AVFrame* frame) {
  if (!video_frame_callback_) return;

  int64_t pts_ms = ConvertPts(frame->pts, true);
  video_frame_callback_(frame, pts_ms);
}

void FFmpegSoftDecoder::ProcessAudioFrame(AVFrame* frame) {
  if (!audio_frame_callback_) return;

  int64_t pts_ms = ConvertPts(frame->pts, false);
  audio_frame_callback_(frame, pts_ms);
}

int64_t FFmpegSoftDecoder::ConvertPts(int64_t pts, bool is_video) {
  if (pts == AV_NOPTS_VALUE) {
    return 0;
  }

  AVCodecContext* ctx = is_video ? 
    demuxer_->GetVideoCodecContext() : 
    demuxer_->GetAudioCodecContext();

  if (!ctx) return 0;

  // Convert to milliseconds
  AVRational time_base = ctx->pkt_timebase;
  return av_rescale_q(pts, time_base, {1, 1000});
}

}  // namespace native_core
}  // namespace mango_player
