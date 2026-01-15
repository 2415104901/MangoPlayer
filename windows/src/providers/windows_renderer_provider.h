#ifndef WINDOWS_RENDERER_PROVIDER_H_
#define WINDOWS_RENDERER_PROVIDER_H_

#include <flutter/texture_registrar.h>
#include <d3d11.h>
#include <memory>
#include <functional>
#include <mutex>

namespace mango_player {

/**
 * Windows 渲染器提供者实现
 * 
 * 实现 RendererProvider 接口，负责管理 Flutter External Texture 渲染。
 * 使用 D3D11 纹理实现零拷贝渲染。
 */
class WindowsRendererProvider {
 public:
  /**
   * 渲染器类型
   */
  enum class RendererType {
    kD3D11Texture,    // D3D11 纹理渲染 (默认)
    kPixelBuffer      // 像素缓冲区渲染 (备用)
  };

  /**
   * 渲染器配置
   */
  struct RendererConfig {
    RendererType type = RendererType::kD3D11Texture;
    bool enable_vsync = true;
    DXGI_FORMAT pixel_format = DXGI_FORMAT_B8G8R8A8_UNORM;
  };

  /**
   * 渲染状态
   */
  struct RendererStatus {
    int64_t texture_id = -1;
    bool is_active = false;
    int width = 0;
    int height = 0;
  };

  using StatusCallback = std::function<void(const RendererStatus&)>;

  WindowsRendererProvider();
  ~WindowsRendererProvider();

  /**
   * 初始化 D3D11 设备
   */
  bool InitializeD3D11();

  /**
   * 注册 Texture 到 Flutter
   */
  int64_t RegisterTexture(flutter::TextureRegistrar* registrar);

  /**
   * 获取 Texture ID
   */
  int64_t GetTextureId() const;

  /**
   * 获取 D3D11 纹理（供 FFmpeg 使用）
   */
  ID3D11Texture2D* GetD3D11Texture() const;

  /**
   * 更新视频尺寸
   */
  void UpdateSize(int width, int height);

  /**
   * 标记帧可用
   */
  void MarkFrameAvailable();

  /**
   * 设置状态回调
   */
  void SetStatusCallback(StatusCallback callback);

  /**
   * 获取当前渲染状态
   */
  RendererStatus GetStatus() const;

  /**
   * 检查渲染器是否可用
   */
  bool IsAvailable() const;

  /**
   * 释放渲染器资源
   */
  void Release();

 private:
  class TextureImpl;
  std::unique_ptr<TextureImpl> impl_;
  
  flutter::TextureRegistrar* texture_registrar_ = nullptr;
  int64_t texture_id_ = -1;
  RendererStatus status_;
  StatusCallback status_callback_;
  
  std::mutex mutex_;
  
  ID3D11Device* d3d_device_ = nullptr;
  ID3D11DeviceContext* d3d_context_ = nullptr;
  ID3D11Texture2D* d3d_texture_ = nullptr;

  bool CreateTexture(int width, int height);
  void ReleaseD3D11Resources();
};

}  // namespace mango_player

#endif  // WINDOWS_RENDERER_PROVIDER_H_
