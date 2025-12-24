#include "texture_manager.h"

#include <dxgi1_2.h>

namespace mango_player {

TextureManager::TextureManager(ID3D11Device* device) {
  if (device) {
    d3d_device_ = device;
    device->GetImmediateContext(&d3d_context_);
  }
}

TextureManager::~TextureManager() {
  ReleaseAll();
}

bool TextureManager::Initialize() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (initialized_) {
    return true;
  }

  if (!d3d_device_) {
    return false;
  }

  initialized_ = true;
  return true;
}

int64_t TextureManager::CreateTexture(const TextureDesc& desc) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!initialized_) {
    return -1;
  }

  // 创建纹理描述
  D3D11_TEXTURE2D_DESC tex_desc = {};
  tex_desc.Width = desc.width;
  tex_desc.Height = desc.height;
  tex_desc.MipLevels = 1;
  tex_desc.ArraySize = 1;
  tex_desc.Format = GetDxgiFormat(desc.format);
  tex_desc.SampleDesc.Count = 1;
  tex_desc.SampleDesc.Quality = 0;
  tex_desc.Usage = D3D11_USAGE_DEFAULT;
  tex_desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
  tex_desc.CPUAccessFlags = 0;

  // 如果需要共享
  if (desc.enable_sharing) {
    tex_desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED_KEYEDMUTEX;
  }

  // 创建纹理
  Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
  HRESULT hr = d3d_device_->CreateTexture2D(&tex_desc, nullptr, &texture);
  if (FAILED(hr)) {
    return -1;
  }

  // 创建 Shader Resource View
  D3D11_SHADER_RESOURCE_VIEW_DESC srv_desc = {};
  srv_desc.Format = tex_desc.Format;
  srv_desc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
  srv_desc.Texture2D.MipLevels = 1;
  srv_desc.Texture2D.MostDetailedMip = 0;

  Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> srv;
  hr = d3d_device_->CreateShaderResourceView(texture.Get(), &srv_desc, &srv);
  if (FAILED(hr)) {
    return -1;
  }

  // 获取共享句柄
  HANDLE shared_handle = nullptr;
  if (desc.enable_sharing) {
    Microsoft::WRL::ComPtr<IDXGIResource> dxgi_resource;
    hr = texture.As(&dxgi_resource);
    if (SUCCEEDED(hr)) {
      dxgi_resource->GetSharedHandle(&shared_handle);
    }
  }

  // 生成纹理 ID
  int64_t texture_id = GenerateTextureId();

  // 创建内部纹理结构
  auto internal_texture = std::make_unique<InternalTexture>();
  internal_texture->info.id = texture_id;
  internal_texture->info.width = desc.width;
  internal_texture->info.height = desc.height;
  internal_texture->info.format = desc.format;
  internal_texture->info.shared_handle = shared_handle;
  internal_texture->info.is_shared = desc.enable_sharing;
  internal_texture->texture = std::move(texture);
  internal_texture->srv = std::move(srv);

  textures_[texture_id] = std::move(internal_texture);

  return texture_id;
}

bool TextureManager::DeleteTexture(int64_t texture_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = textures_.find(texture_id);
  if (it == textures_.end()) {
    return false;
  }

  textures_.erase(it);
  return true;
}

const TextureManager::TextureInfo* TextureManager::GetTextureInfo(
    int64_t texture_id) const {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = textures_.find(texture_id);
  if (it == textures_.end()) {
    return nullptr;
  }

  return &it->second->info;
}

ID3D11Texture2D* TextureManager::GetTexture(int64_t texture_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = textures_.find(texture_id);
  if (it == textures_.end()) {
    return nullptr;
  }

  return it->second->texture.Get();
}

ID3D11ShaderResourceView* TextureManager::GetShaderResourceView(
    int64_t texture_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = textures_.find(texture_id);
  if (it == textures_.end()) {
    return nullptr;
  }

  return it->second->srv.Get();
}

bool TextureManager::UpdateTexture(int64_t texture_id, const void* data,
                                   UINT pitch) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = textures_.find(texture_id);
  if (it == textures_.end() || !data) {
    return false;
  }

  auto& internal = it->second;

  // 更新纹理数据
  d3d_context_->UpdateSubresource(internal->texture.Get(), 0, nullptr, data,
                                  pitch, 0);

  return true;
}

bool TextureManager::CopyFromTexture(int64_t texture_id,
                                     ID3D11Texture2D* src_texture) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = textures_.find(texture_id);
  if (it == textures_.end() || !src_texture) {
    return false;
  }

  auto& internal = it->second;

  // 复制纹理
  d3d_context_->CopyResource(internal->texture.Get(), src_texture);

  return true;
}

HANDLE TextureManager::GetSharedHandle(int64_t texture_id) const {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = textures_.find(texture_id);
  if (it == textures_.end()) {
    return nullptr;
  }

  return it->second->info.shared_handle;
}

int64_t TextureManager::OpenSharedTexture(HANDLE shared_handle, UINT width,
                                          UINT height, TextureFormat format) {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!initialized_ || !shared_handle) {
    return -1;
  }

  // 从共享句柄打开纹理
  Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
  HRESULT hr = d3d_device_->OpenSharedResource(
      shared_handle, __uuidof(ID3D11Texture2D),
      reinterpret_cast<void**>(texture.GetAddressOf()));

  if (FAILED(hr)) {
    return -1;
  }

  // 创建 Shader Resource View
  D3D11_SHADER_RESOURCE_VIEW_DESC srv_desc = {};
  srv_desc.Format = GetDxgiFormat(format);
  srv_desc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
  srv_desc.Texture2D.MipLevels = 1;
  srv_desc.Texture2D.MostDetailedMip = 0;

  Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> srv;
  hr = d3d_device_->CreateShaderResourceView(texture.Get(), &srv_desc, &srv);
  if (FAILED(hr)) {
    return -1;
  }

  // 生成纹理 ID
  int64_t texture_id = GenerateTextureId();

  // 创建内部纹理结构
  auto internal_texture = std::make_unique<InternalTexture>();
  internal_texture->info.id = texture_id;
  internal_texture->info.width = width;
  internal_texture->info.height = height;
  internal_texture->info.format = format;
  internal_texture->info.shared_handle = shared_handle;
  internal_texture->info.is_shared = true;
  internal_texture->texture = std::move(texture);
  internal_texture->srv = std::move(srv);

  textures_[texture_id] = std::move(internal_texture);

  return texture_id;
}

void TextureManager::SetFrameCallback(FrameCallback callback) {
  std::lock_guard<std::mutex> lock(mutex_);
  frame_callback_ = std::move(callback);
}

void TextureManager::NotifyFrameReady(int64_t texture_id) {
  FrameCallback callback;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    callback = frame_callback_;
  }

  if (callback) {
    callback(texture_id);
  }
}

std::vector<TextureManager::TextureInfo> TextureManager::GetAllTextures()
    const {
  std::lock_guard<std::mutex> lock(mutex_);

  std::vector<TextureInfo> result;
  result.reserve(textures_.size());

  for (const auto& pair : textures_) {
    result.push_back(pair.second->info);
  }

  return result;
}

void TextureManager::ReleaseAll() {
  std::lock_guard<std::mutex> lock(mutex_);
  textures_.clear();
}

DXGI_FORMAT TextureManager::GetDxgiFormat(TextureFormat format) {
  switch (format) {
    case TextureFormat::kNV12:
      return DXGI_FORMAT_NV12;
    case TextureFormat::kBGRA:
      return DXGI_FORMAT_B8G8R8A8_UNORM;
    case TextureFormat::kRGBA:
      return DXGI_FORMAT_R8G8B8A8_UNORM;
    case TextureFormat::kYUY2:
      return DXGI_FORMAT_YUY2;
    case TextureFormat::kP010:
      return DXGI_FORMAT_P010;
    default:
      return DXGI_FORMAT_B8G8R8A8_UNORM;
  }
}

int64_t TextureManager::GenerateTextureId() {
  return next_texture_id_++;
}

}  // namespace mango_player
