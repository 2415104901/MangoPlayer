// MangoPlayer Windows Plugin
// DXVA Decoder Implementation

#include "dxva_decoder.h"
#include "native_core/ffmpeg_demuxer.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_d3d11va.h>
#include <libavutil/frame.h>
#include <libavutil/pixdesc.h>
}

namespace mango_player {

DXVADecoder::DXVADecoder(ID3D11Device* device,
                         std::shared_ptr<native_core::FFmpegDemuxer> demuxer)
    : device_(device), demuxer_(demuxer) {
  device_->GetImmediateContext(&device_context_);
  hw_frame_ = av_frame_alloc();
  sw_frame_ = av_frame_alloc();
}

DXVADecoder::~DXVADecoder() {
  Release();
}

bool DXVADecoder::IsSupported() {
  if (!demuxer_ || !demuxer_->IsOpen()) {
    return false;
  }

  AVCodecContext* video_ctx = demuxer_->GetVideoCodecContext();
  if (!video_ctx) {
    return false;
  }

  // Check if codec supports DXVA2/D3D11VA
  switch (video_ctx->codec_id) {
    case AV_CODEC_ID_H264:
    case AV_CODEC_ID_HEVC:
    case AV_CODEC_ID_VP9:
    case AV_CODEC_ID_AV1:
    case AV_CODEC_ID_VC1:
    case AV_CODEC_ID_WMV3:
    case AV_CODEC_ID_MPEG2VIDEO:
      return true;
    default:
      return false;
  }
}

bool DXVADecoder::Initialize() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (is_initialized_.load()) {
    return true;
  }

  if (!IsSupported()) {
    return false;
  }

  AVCodecContext* sw_ctx = demuxer_->GetVideoCodecContext();
  if (!sw_ctx) {
    return false;
  }

  // Find hardware decoder
  const AVCodec* codec = avcodec_find_decoder(sw_ctx->codec_id);
  if (!codec) {
    if (error_callback_) {
      error_callback_(-1, "Failed to find decoder");
    }
    return false;
  }

  // Allocate hardware codec context
  hw_codec_context_ = avcodec_alloc_context3(codec);
  if (!hw_codec_context_) {
    if (error_callback_) {
      error_callback_(-1, "Failed to allocate hardware codec context");
    }
    return false;
  }

  // Copy parameters from software context
  AVCodecParameters* codecpar = av_codecs_alloc_parameters();
  if (!codecpar) {
    avcodec_free_context(&hw_codec_context_);
    return false;
  }

  avcodec_parameters_from_context(codecpar, sw_ctx);
  int ret = avcodec_parameters_to_context(hw_codec_context_, codecpar);
  av_codecs_free(&codecpar);

  if (ret < 0) {
    avcodec_free_context(&hw_codec_context_);
    return false;
  }

  // Setup hardware device context
  if (!SetupHWDeviceContext()) {
    avcodec_free_context(&hw_codec_context_);
    return false;
  }

  hw_codec_context_->hw_device_ctx = av_buffer_ref(hw_device_ctx_);

  // Open codec
  ret = avcodec_open2(hw_codec_context_, codec, nullptr);
  if (ret < 0) {
    if (error_callback_) {
      error_callback_(ret, "Failed to open hardware codec");
    }
    av_buffer_unref(&hw_device_ctx_);
    avcodec_free_context(&hw_codec_context_);
    return false;
  }

  is_initialized_.store(true);
  return true;
}

bool DXVADecoder::SetupHWDeviceContext() {
  // Create D3D11VA device context
  int ret = av_hwdevice_ctx_create(&hw_device_ctx_, AV_HWDEVICE_TYPE_D3D11VA,
                                    nullptr, nullptr, 0);
  if (ret < 0) {
    if (error_callback_) {
      error_callback_(ret, "Failed to create D3D11VA device context");
    }
    return false;
  }

  // Get the D3D11 device from FFmpeg's context and potentially share with our device
  AVHWDeviceContext* device_ctx = (AVHWDeviceContext*)hw_device_ctx_->data;
  AVD3D11VADeviceContext* d3d11_ctx = (AVD3D11VADeviceContext*)device_ctx->hwctx;

  // Note: In a production implementation, we might want to share the device
  // For now, we use FFmpeg's created device
  (void)d3d11_ctx;

  return true;
}

bool DXVADecoder::DecodePacket(AVPacket* packet, int64_t pts_ms) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_initialized_.load() || !hw_codec_context_) {
    return false;
  }

  int ret = avcodec_send_packet(hw_codec_context_, packet);
  if (ret < 0) {
    if (ret != AVERROR_EOF && ret != AVERROR(EAGAIN)) {
      // Hardware decode failed, trigger fallback
      NotifyFallback();
      return false;
    }
    return true;
  }

  while (ret >= 0) {
    ret = avcodec_receive_frame(hw_codec_context_, hw_frame_);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
      break;
    } else if (ret < 0) {
      NotifyFallback();
      return false;
    }

    ProcessFrame(hw_frame_, pts_ms);
    av_frame_unref(hw_frame_);
  }

  return true;
}

void DXVADecoder::ProcessFrame(AVFrame* frame, int64_t pts_ms) {
  if (!frame_callback_) return;

  // Check if frame is in GPU memory
  if (frame->format == AV_PIX_FMT_D3D11) {
    // Get D3D11 texture from frame
    ID3D11Texture2D* texture = (ID3D11Texture2D*)frame->data[0];
    int texture_index = (intptr_t)frame->data[1];
    
    // In a production implementation, we would copy to our own texture
    // or use the texture directly if sharing is possible
    frame_callback_(texture, pts_ms);
  } else {
    // Frame is not in expected format, might need conversion
    if (error_callback_) {
      error_callback_(-1, "Unexpected frame format from hardware decoder");
    }
  }
}

void DXVADecoder::Flush() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (hw_codec_context_) {
    avcodec_flush_buffers(hw_codec_context_);
  }
}

void DXVADecoder::Release() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (hw_frame_) {
    av_frame_free(&hw_frame_);
  }
  if (sw_frame_) {
    av_frame_free(&sw_frame_);
  }
  if (hw_codec_context_) {
    avcodec_free_context(&hw_codec_context_);
  }
  if (hw_frames_ctx_) {
    av_buffer_unref(&hw_frames_ctx_);
  }
  if (hw_device_ctx_) {
    av_buffer_unref(&hw_device_ctx_);
  }

  is_initialized_.store(false);
}

void DXVADecoder::NotifyFallback() {
  if (!fallback_triggered_.exchange(true)) {
    if (fallback_callback_) {
      fallback_callback_();
    }
  }
}

}  // namespace mango_player
