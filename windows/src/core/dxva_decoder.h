// MangoPlayer Windows Plugin
// DXVA Decoder - Hardware Video Decoding

#ifndef DXVA_DECODER_H_
#define DXVA_DECODER_H_

#include <d3d11.h>
#include <dxva2api.h>
#include <wrl/client.h>

#include <functional>
#include <memory>
#include <mutex>
#include <atomic>

// Forward declarations
extern "C" {
struct AVCodecContext;
struct AVFrame;
struct AVBufferRef;
}

namespace mango_player {
namespace native_core {
class FFmpegDemuxer;
}

// Callback for hardware decoded frames (D3D11 texture)
using HWFrameCallback = std::function<void(ID3D11Texture2D* texture, int64_t pts_ms)>;
using HWErrorCallback = std::function<void(int code, const std::string& message)>;
using FallbackCallback = std::function<void()>;  // Called when falling back to software decode

class DXVADecoder {
 public:
  DXVADecoder(ID3D11Device* device, 
              std::shared_ptr<native_core::FFmpegDemuxer> demuxer);
  ~DXVADecoder();

  // Check if hardware decoding is supported for current stream
  bool IsSupported();

  // Initialize hardware decoder
  bool Initialize();

  // Decode a packet and output to texture
  bool DecodePacket(struct AVPacket* packet, int64_t pts_ms);

  // Set callbacks
  void SetFrameCallback(HWFrameCallback callback) { frame_callback_ = callback; }
  void SetErrorCallback(HWErrorCallback callback) { error_callback_ = callback; }
  void SetFallbackCallback(FallbackCallback callback) { fallback_callback_ = callback; }

  // Flush decoder
  void Flush();

  // Release resources
  void Release();

  bool IsInitialized() const { return is_initialized_.load(); }

 private:
  bool SetupHWDeviceContext();
  bool SetupHWFramesContext();
  void ProcessFrame(AVFrame* frame, int64_t pts_ms);
  void NotifyFallback();

  ID3D11Device* device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> device_context_;
  std::shared_ptr<native_core::FFmpegDemuxer> demuxer_;

  AVCodecContext* hw_codec_context_ = nullptr;
  AVBufferRef* hw_device_ctx_ = nullptr;
  AVBufferRef* hw_frames_ctx_ = nullptr;
  AVFrame* hw_frame_ = nullptr;
  AVFrame* sw_frame_ = nullptr;

  HWFrameCallback frame_callback_;
  HWErrorCallback error_callback_;
  FallbackCallback fallback_callback_;

  std::atomic<bool> is_initialized_{false};
  std::atomic<bool> fallback_triggered_{false};
  std::mutex mutex_;
};

}  // namespace mango_player

#endif  // DXVA_DECODER_H_
