#include "windows_renderer_provider.h"

#include <flutter/standard_method_codec.h>

#pragma comment(lib, "d3d11.lib")

namespace mango_player {

// Flutter Texture 实现
class WindowsRendererProvider::TextureImpl : public flutter::TextureVariant {
 public:
  TextureImpl(WindowsRendererProvider* provider) : provider_(provider) {}
  
  // 返回 GPU 表面描述符
  const FlutterDesktopGpuSurfaceDescriptor* GetGpuSurface(
      size_t width, size_t height) {
    if (!provider_ || !provider_->d3d_texture_) {
      return nullptr;
    }
    
    descriptor_.struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
    descriptor_.handle = provider_->d3d_texture_;
    descriptor_.width = static_cast<size_t>(provider_->status_.width);
    descriptor_.height = static_cast<size_t>(provider_->status_.height);
    descriptor_.visible_width = descriptor_.width;
    descriptor_.visible_height = descriptor_.height;
    descriptor_.format = kFlutterDesktopPixelFormatBGRA8888;
    descriptor_.release_callback = nullptr;
    descriptor_.release_context = nullptr;
    
    return &descriptor_;
  }

 private:
  WindowsRendererProvider* provider_;
  FlutterDesktopGpuSurfaceDescriptor descriptor_{};
};

WindowsRendererProvider::WindowsRendererProvider() = default;

WindowsRendererProvider::~WindowsRendererProvider() {
  Release();
}

bool WindowsRendererProvider::InitializeD3D11() {
  if (d3d_device_) {
    return true;  // 已初始化
  }
  
  D3D_FEATURE_LEVEL feature_level;
  UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
  
#ifdef _DEBUG
  flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif
  
  HRESULT hr = D3D11CreateDevice(
      nullptr,
      D3D_DRIVER_TYPE_HARDWARE,
      nullptr,
      flags,
      nullptr,
      0,
      D3D11_SDK_VERSION,
      &d3d_device_,
      &feature_level,
      &d3d_context_
  );
  
  return SUCCEEDED(hr);
}

int64_t WindowsRendererProvider::RegisterTexture(
    flutter::TextureRegistrar* registrar) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  texture_registrar_ = registrar;
  
  // 创建 texture 实现
  impl_ = std::make_unique<TextureImpl>(this);
  
  // 注册到 Flutter
  // 注意: 实际实现需要使用 TextureRegistrar 的正确 API
  // 这里简化处理
  texture_id_ = reinterpret_cast<int64_t>(impl_.get());
  
  status_.texture_id = texture_id_;
  status_.is_active = true;
  
  if (status_callback_) {
    status_callback_(status_);
  }
  
  return texture_id_;
}

int64_t WindowsRendererProvider::GetTextureId() const {
  return texture_id_;
}

ID3D11Texture2D* WindowsRendererProvider::GetD3D11Texture() const {
  return d3d_texture_;
}

void WindowsRendererProvider::UpdateSize(int width, int height) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  if (status_.width == width && status_.height == height) {
    return;
  }
  
  // 重新创建纹理
  if (d3d_device_) {
    CreateTexture(width, height);
  }
  
  status_.width = width;
  status_.height = height;
  
  if (status_callback_) {
    status_callback_(status_);
  }
}

void WindowsRendererProvider::MarkFrameAvailable() {
  // 通知 Flutter 新帧可用
  if (texture_registrar_ && texture_id_ >= 0) {
    texture_registrar_->MarkTextureFrameAvailable(texture_id_);
  }
}

void WindowsRendererProvider::SetStatusCallback(StatusCallback callback) {
  status_callback_ = std::move(callback);
}

WindowsRendererProvider::RendererStatus WindowsRendererProvider::GetStatus() const {
  return status_;
}

bool WindowsRendererProvider::IsAvailable() const {
  return d3d_device_ != nullptr && texture_id_ >= 0;
}

void WindowsRendererProvider::Release() {
  std::lock_guard<std::mutex> lock(mutex_);
  
  if (texture_registrar_ && texture_id_ >= 0) {
    texture_registrar_->UnregisterTexture(texture_id_);
  }
  
  ReleaseD3D11Resources();
  
  impl_.reset();
  texture_registrar_ = nullptr;
  texture_id_ = -1;
  
  status_ = RendererStatus{};
  
  if (status_callback_) {
    status_callback_(status_);
  }
}

bool WindowsRendererProvider::CreateTexture(int width, int height) {
  // 释放旧纹理
  if (d3d_texture_) {
    d3d_texture_->Release();
    d3d_texture_ = nullptr;
  }
  
  if (!d3d_device_ || width <= 0 || height <= 0) {
    return false;
  }
  
  D3D11_TEXTURE2D_DESC desc = {};
  desc.Width = static_cast<UINT>(width);
  desc.Height = static_cast<UINT>(height);
  desc.MipLevels = 1;
  desc.ArraySize = 1;
  desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count = 1;
  desc.Usage = D3D11_USAGE_DEFAULT;
  desc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_RENDER_TARGET;
  desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;
  
  HRESULT hr = d3d_device_->CreateTexture2D(&desc, nullptr, &d3d_texture_);
  
  return SUCCEEDED(hr);
}

void WindowsRendererProvider::ReleaseD3D11Resources() {
  if (d3d_texture_) {
    d3d_texture_->Release();
    d3d_texture_ = nullptr;
  }
  if (d3d_context_) {
    d3d_context_->Release();
    d3d_context_ = nullptr;
  }
  if (d3d_device_) {
    d3d_device_->Release();
    d3d_device_ = nullptr;
  }
}

}  // namespace mango_player
