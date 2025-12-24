#ifndef MANGO_PLAYER_DXVA_CONFIG_MANAGER_H_
#define MANGO_PLAYER_DXVA_CONFIG_MANAGER_H_

#include <windows.h>
#include <d3d11.h>
#include <dxva2api.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>

#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace mango_player {

/// DXVA 配置管理器
///
/// 负责配置 FFmpeg 的 DXVA2/D3D11VA 硬件解码选项，
/// 监听解码器降级事件，并提供解码器能力查询接口。
///
/// 任务: T111 [US6]
class DxvaConfigManager {
 public:
  /// 支持的视频编解码器
  struct SupportedCodecs {
    bool h264 = true;
    bool hevc = false;
    bool vp9 = false;
    bool av1 = false;
  };

  /// 硬件解码器能力信息
  struct HardwareDecoderCapability {
    std::string codec_name;
    std::string codec_type;  // "H.264", "HEVC", etc.
    bool is_supported;
    int max_width;
    int max_height;
    std::vector<std::string> supported_profiles;
  };

  /// 解码配置
  struct DecoderConfiguration {
    bool enable_hardware_decode = true;
    bool enable_hevc = true;
    bool prefer_d3d11va = true;  // 优先使用 D3D11VA，否则使用 DXVA2
    int output_format = 0;  // 0 = NV12
    std::vector<std::string> preferred_profiles;
  };

  /// 降级原因
  enum class FallbackReason {
    kCodecNotSupported,
    kResolutionTooHigh,
    kDecodeError,
    kTimeout,
    kUnknown
  };

  /// 降级事件
  struct FallbackEvent {
    std::string from_codec;
    std::string to_codec;
    FallbackReason reason;
    int64_t timestamp;
  };

  /// 回调类型
  using FallbackCallback = std::function<void(const FallbackEvent&)>;

 public:
  DxvaConfigManager();
  ~DxvaConfigManager();

  // 禁止复制
  DxvaConfigManager(const DxvaConfigManager&) = delete;
  DxvaConfigManager& operator=(const DxvaConfigManager&) = delete;

  /// 初始化 D3D11 设备
  bool Initialize();

  /// 获取设备支持的硬件解码器列表
  std::vector<HardwareDecoderCapability> GetAvailableHardwareDecoders() const;

  /// 检查指定编解码器是否支持硬件解码
  bool IsHardwareDecodeSupported(const std::string& codec_type) const;

  /// 获取当前设备支持的编解码器
  SupportedCodecs GetSupportedCodecs() const;

  /// 获取 FFmpeg 的硬解配置选项
  /// 返回格式: 键值对列表，用于设置 AVCodecContext
  std::vector<std::pair<std::string, std::string>> GetFFmpegOptions(
      const DecoderConfiguration& config) const;

  /// 应用解码器配置
  void ApplyConfiguration(const DecoderConfiguration& config);

  /// 获取当前配置
  DecoderConfiguration GetCurrentConfiguration() const;

  /// 检查是否支持指定分辨率的硬件解码
  bool SupportsResolution(int width, int height,
                          const std::string& codec_type = "H.264") const;

  /// 获取推荐的解码配置
  DecoderConfiguration GetRecommendedConfiguration(
      int width, int height, const std::string& codec_type = "H.264") const;

  /// 记录降级事件
  void RecordFallback(const std::string& from_codec,
                      const std::string& to_codec, FallbackReason reason);

  /// 设置降级事件回调
  void SetFallbackCallback(FallbackCallback callback);

  /// 获取降级历史
  std::vector<FallbackEvent> GetFallbackHistory() const;

  /// 清除降级历史
  void ClearFallbackHistory();

  /// 获取 D3D11 设备 (用于纹理渲染)
  ID3D11Device* GetD3D11Device() const { return d3d_device_.Get(); }

  /// 获取 D3D11 设备上下文
  ID3D11DeviceContext* GetD3D11Context() const { return d3d_context_.Get(); }

 private:
  /// 检测 GPU 支持的解码能力
  void DetectHardwareCapabilities();

  /// 检查 DXVA2 支持
  bool CheckDxva2Support(const GUID& decoder_guid) const;

  /// 检查 D3D11VA 支持
  bool CheckD3d11vaSupport(const GUID& profile_guid) const;

 private:
  mutable std::mutex mutex_;
  
  // D3D11 资源
  Microsoft::WRL::ComPtr<ID3D11Device> d3d_device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> d3d_context_;
  Microsoft::WRL::ComPtr<ID3D11VideoDevice> video_device_;

  // 配置和状态
  DecoderConfiguration configuration_;
  std::vector<HardwareDecoderCapability> hardware_capabilities_;
  std::vector<FallbackEvent> fallback_history_;
  FallbackCallback fallback_callback_;
  bool initialized_ = false;
};

}  // namespace mango_player

#endif  // MANGO_PLAYER_DXVA_CONFIG_MANAGER_H_
