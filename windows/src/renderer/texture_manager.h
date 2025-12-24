#ifndef MANGO_PLAYER_TEXTURE_MANAGER_H_
#define MANGO_PLAYER_TEXTURE_MANAGER_H_

#include <windows.h>
#include <d3d11.h>
#include <wrl/client.h>

#include <functional>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vector>

namespace mango_player {

/// D3D11 纹理管理器
///
/// 管理 D3D11 纹理资源，用于视频帧渲染和 Flutter External Texture 对接。
/// 支持纹理创建、共享、格式转换等功能。
///
/// 任务: T117 [US6]
class TextureManager {
 public:
  /// 纹理格式
  enum class TextureFormat {
    kNV12,    // YUV 4:2:0
    kBGRA,    // BGRA 32-bit
    kRGBA,    // RGBA 32-bit
    kYUY2,    // YUV 4:2:2
    kP010     // 10-bit YUV
  };

  /// 纹理信息
  struct TextureInfo {
    int64_t id;
    UINT width;
    UINT height;
    TextureFormat format;
    HANDLE shared_handle;
    bool is_shared;
  };

  /// 纹理描述
  struct TextureDesc {
    UINT width;
    UINT height;
    TextureFormat format;
    bool enable_sharing;
  };

  /// 帧更新回调
  using FrameCallback = std::function<void(int64_t texture_id)>;

 public:
  explicit TextureManager(ID3D11Device* device);
  ~TextureManager();

  // 禁止复制
  TextureManager(const TextureManager&) = delete;
  TextureManager& operator=(const TextureManager&) = delete;

  /// 初始化
  bool Initialize();

  /// 创建纹理
  /// @param desc 纹理描述
  /// @return 纹理 ID，失败返回 -1
  int64_t CreateTexture(const TextureDesc& desc);

  /// 删除纹理
  bool DeleteTexture(int64_t texture_id);

  /// 获取纹理信息
  const TextureInfo* GetTextureInfo(int64_t texture_id) const;

  /// 获取 D3D11 Texture2D
  ID3D11Texture2D* GetTexture(int64_t texture_id);

  /// 获取 D3D11 ShaderResourceView
  ID3D11ShaderResourceView* GetShaderResourceView(int64_t texture_id);

  /// 更新纹理内容
  /// @param texture_id 纹理 ID
  /// @param data 像素数据
  /// @param pitch 行字节数
  bool UpdateTexture(int64_t texture_id, const void* data, UINT pitch);

  /// 从视频帧更新纹理 (D3D11 Texture)
  /// @param texture_id 目标纹理 ID
  /// @param src_texture 源纹理
  bool CopyFromTexture(int64_t texture_id, ID3D11Texture2D* src_texture);

  /// 获取共享句柄 (用于跨进程共享)
  HANDLE GetSharedHandle(int64_t texture_id) const;

  /// 从共享句柄打开纹理
  int64_t OpenSharedTexture(HANDLE shared_handle, UINT width, UINT height,
                            TextureFormat format);

  /// 设置帧更新回调
  void SetFrameCallback(FrameCallback callback);

  /// 通知帧已更新
  void NotifyFrameReady(int64_t texture_id);

  /// 获取所有纹理
  std::vector<TextureInfo> GetAllTextures() const;

  /// 清理所有纹理
  void ReleaseAll();

  /// 获取 D3D11 设备
  ID3D11Device* GetDevice() const { return d3d_device_.Get(); }

  /// 获取 D3D11 设备上下文
  ID3D11DeviceContext* GetContext() const { return d3d_context_.Get(); }

 private:
  /// 内部纹理结构
  struct InternalTexture {
    TextureInfo info;
    Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
    Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> srv;
    Microsoft::WRL::ComPtr<ID3D11Texture2D> staging_texture;  // 用于 CPU 访问
  };

  /// 获取 DXGI 格式
  static DXGI_FORMAT GetDxgiFormat(TextureFormat format);

  /// 生成纹理 ID
  int64_t GenerateTextureId();

 private:
  mutable std::mutex mutex_;
  
  Microsoft::WRL::ComPtr<ID3D11Device> d3d_device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> d3d_context_;
  
  std::unordered_map<int64_t, std::unique_ptr<InternalTexture>> textures_;
  int64_t next_texture_id_ = 1;
  
  FrameCallback frame_callback_;
  bool initialized_ = false;
};

}  // namespace mango_player

#endif  // MANGO_PLAYER_TEXTURE_MANAGER_H_
