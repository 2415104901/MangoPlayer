// MangoPlayer Windows Plugin
// D3D11 Texture Renderer Implementation

#include "d3d11_texture_renderer.h"

extern "C" {
#include <libavutil/frame.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
}

#pragma comment(lib, "d3d11.lib")

namespace mango_player {

D3D11TextureRenderer::D3D11TextureRenderer(
    flutter::TextureRegistrar* texture_registrar)
    : texture_registrar_(texture_registrar) {}

D3D11TextureRenderer::~D3D11TextureRenderer() {
  Dispose();
}

bool D3D11TextureRenderer::Initialize() {
  return Initialize(1920, 1080);  // Default to 1080p
}

bool D3D11TextureRenderer::Initialize(int width, int height) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (is_initialized_.load()) {
    return true;
  }

  width_ = width;
  height_ = height;

  // Create D3D11 device
  if (!CreateD3D11Device()) {
    return false;
  }

  // Create textures
  if (!CreateTexture(width, height)) {
    return false;
  }

  // Allocate pixel buffer for Flutter
  pixel_buffer_ = std::make_unique<FlutterDesktopPixelBuffer>();
  pixel_data_.resize(width * height * 4);  // RGBA

  pixel_buffer_->buffer = pixel_data_.data();
  pixel_buffer_->width = width;
  pixel_buffer_->height = height;

  // Register with Flutter texture registry
  auto texture_variant = flutter::TextureVariant(flutter::PixelBufferTexture(
      [this](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
        return this->CopyPixelBuffer(width, height);
      }));

  texture_id_ = texture_registrar_->RegisterTexture(&texture_variant);

  is_initialized_.store(true);
  return true;
}

bool D3D11TextureRenderer::CreateD3D11Device() {
  D3D_FEATURE_LEVEL feature_levels[] = {
    D3D_FEATURE_LEVEL_11_1,
    D3D_FEATURE_LEVEL_11_0,
    D3D_FEATURE_LEVEL_10_1,
    D3D_FEATURE_LEVEL_10_0,
  };

  UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
  #ifdef _DEBUG
  flags |= D3D11_CREATE_DEVICE_DEBUG;
  #endif

  D3D_FEATURE_LEVEL feature_level;
  HRESULT hr = D3D11CreateDevice(
      nullptr,
      D3D_DRIVER_TYPE_HARDWARE,
      nullptr,
      flags,
      feature_levels,
      ARRAYSIZE(feature_levels),
      D3D11_SDK_VERSION,
      &device_,
      &feature_level,
      &context_);

  if (FAILED(hr)) {
    // Try WARP driver as fallback
    hr = D3D11CreateDevice(
        nullptr,
        D3D_DRIVER_TYPE_WARP,
        nullptr,
        flags,
        feature_levels,
        ARRAYSIZE(feature_levels),
        D3D11_SDK_VERSION,
        &device_,
        &feature_level,
        &context_);
  }

  return SUCCEEDED(hr);
}

bool D3D11TextureRenderer::CreateTexture(int width, int height) {
  // Create render texture
  D3D11_TEXTURE2D_DESC desc = {};
  desc.Width = width;
  desc.Height = height;
  desc.MipLevels = 1;
  desc.ArraySize = 1;
  desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count = 1;
  desc.Usage = D3D11_USAGE_DEFAULT;
  desc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_RENDER_TARGET;

  HRESULT hr = device_->CreateTexture2D(&desc, nullptr, &render_texture_);
  if (FAILED(hr)) {
    return false;
  }

  // Create staging texture for CPU access
  desc.Usage = D3D11_USAGE_STAGING;
  desc.BindFlags = 0;
  desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;

  hr = device_->CreateTexture2D(&desc, nullptr, &staging_texture_);
  if (FAILED(hr)) {
    return false;
  }

  return true;
}

void D3D11TextureRenderer::UpdateTexture(const uint8_t* data, int width, int height, int stride) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_initialized_.load()) {
    return;
  }

  // Resize if needed
  if (width != width_ || height != height_) {
    width_ = width;
    height_ = height;
    CreateTexture(width, height);
    pixel_data_.resize(width * height * 4);
    pixel_buffer_->width = width;
    pixel_buffer_->height = height;
  }

  // Copy data to pixel buffer
  for (int y = 0; y < height; ++y) {
    memcpy(pixel_data_.data() + y * width * 4, 
           data + y * stride, 
           width * 4);
  }

  needs_update_.store(true);
  texture_registrar_->MarkTextureFrameAvailable(texture_id_);
}

void D3D11TextureRenderer::UpdateWithAVFrame(AVFrame* frame, int64_t pts_ms) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_initialized_.load() || !frame) {
    return;
  }

  int src_width = frame->width;
  int src_height = frame->height;

  // Resize if needed
  if (src_width != width_ || src_height != height_) {
    width_ = src_width;
    height_ = src_height;
    CreateTexture(src_width, src_height);
    pixel_data_.resize(src_width * src_height * 4);
    pixel_buffer_->width = src_width;
    pixel_buffer_->height = src_height;
  }

  // Convert YUV to BGRA using swscale
  SwsContext* sws_ctx = sws_getContext(
      src_width, src_height, (AVPixelFormat)frame->format,
      src_width, src_height, AV_PIX_FMT_BGRA,
      SWS_BILINEAR, nullptr, nullptr, nullptr);

  if (!sws_ctx) {
    return;
  }

  uint8_t* dst_data[4] = { pixel_data_.data(), nullptr, nullptr, nullptr };
  int dst_linesize[4] = { src_width * 4, 0, 0, 0 };

  sws_scale(sws_ctx, frame->data, frame->linesize, 0, src_height,
            dst_data, dst_linesize);

  sws_freeContext(sws_ctx);

  needs_update_.store(true);
  texture_registrar_->MarkTextureFrameAvailable(texture_id_);
}

void D3D11TextureRenderer::UpdateWithD3D11Texture(ID3D11Texture2D* texture, int subresource_index) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_initialized_.load() || !texture || !context_) {
    return;
  }

  // Get texture description
  D3D11_TEXTURE2D_DESC src_desc;
  texture->GetDesc(&src_desc);

  // Resize if needed
  if ((int)src_desc.Width != width_ || (int)src_desc.Height != height_) {
    width_ = src_desc.Width;
    height_ = src_desc.Height;
    CreateTexture(width_, height_);
    pixel_data_.resize(width_ * height_ * 4);
    pixel_buffer_->width = width_;
    pixel_buffer_->height = height_;
  }

  // Copy texture to staging
  context_->CopySubresourceRegion(staging_texture_.Get(), 0, 0, 0, 0,
                                   texture, subresource_index, nullptr);

  // Map staging texture to read pixels
  D3D11_MAPPED_SUBRESOURCE mapped;
  HRESULT hr = context_->Map(staging_texture_.Get(), 0, D3D11_MAP_READ, 0, &mapped);
  if (FAILED(hr)) {
    return;
  }

  // Copy to pixel buffer
  for (int y = 0; y < height_; ++y) {
    memcpy(pixel_data_.data() + y * width_ * 4,
           static_cast<uint8_t*>(mapped.pData) + y * mapped.RowPitch,
           width_ * 4);
  }

  context_->Unmap(staging_texture_.Get(), 0);

  needs_update_.store(true);
  texture_registrar_->MarkTextureFrameAvailable(texture_id_);
}

const FlutterDesktopPixelBuffer* D3D11TextureRenderer::CopyPixelBuffer(
    size_t width, size_t height) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!needs_update_.load() || pixel_data_.empty()) {
    return nullptr;
  }

  pixel_buffer_->buffer = pixel_data_.data();
  needs_update_.store(false);
  return pixel_buffer_.get();
}

void D3D11TextureRenderer::Dispose() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (texture_id_ >= 0 && texture_registrar_) {
    texture_registrar_->UnregisterTexture(texture_id_);
    texture_id_ = -1;
  }

  render_texture_.Reset();
  staging_texture_.Reset();
  context_.Reset();
  device_.Reset();

  pixel_buffer_.reset();
  pixel_data_.clear();

  is_initialized_.store(false);
}

}  // namespace mango_player
