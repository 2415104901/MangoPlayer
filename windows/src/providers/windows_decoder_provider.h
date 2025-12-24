#ifndef WINDOWS_DECODER_PROVIDER_H_
#define WINDOWS_DECODER_PROVIDER_H_

#include <string>
#include <functional>
#include <optional>

namespace mango_player {

/**
 * Windows 解码器提供者实现
 * 
 * 实现 DecoderProvider 接口，负责配置和监控 FFmpeg 的解码器设置。
 * 支持硬件解码（DXVA2/D3D11VA）和软件解码之间的切换。
 */
class WindowsDecoderProvider {
 public:
  /**
   * 解码器类型
   */
  enum class DecoderType {
    kHardware,   // 硬件解码 (DXVA2/D3D11VA)
    kSoftware,   // 软件解码 (FFmpeg)
    kAuto        // 自动选择
  };

  /**
   * 硬件加速类型
   */
  enum class HardwareAccelType {
    kNone,       // 无硬件加速
    kDXVA2,      // DXVA2 (DirectX Video Acceleration 2)
    kD3D11VA,    // D3D11 Video Acceleration
    kCUDA,       // NVIDIA CUDA
    kQSV         // Intel Quick Sync Video
  };

  /**
   * 解码器配置
   */
  struct DecoderConfig {
    bool prefer_hardware = true;
    HardwareAccelType preferred_hw_type = HardwareAccelType::kD3D11VA;
    int thread_count = 0;  // 0 = auto
    bool enable_low_latency = false;
  };

  /**
   * 解码器状态
   */
  struct DecoderStatus {
    DecoderType type = DecoderType::kAuto;
    std::optional<std::string> codec_name;
    bool is_hardware_accelerated = false;
    HardwareAccelType hw_type = HardwareAccelType::kNone;
    std::optional<std::string> fallback_reason;
  };

  using StatusCallback = std::function<void(const DecoderStatus&)>;

  WindowsDecoderProvider();
  ~WindowsDecoderProvider();

  /**
   * 检查系统是否支持硬件解码
   */
  bool IsHardwareDecodingSupported() const;

  /**
   * 检查特定硬件加速类型是否可用
   */
  bool IsHardwareAccelAvailable(HardwareAccelType type) const;

  /**
   * 获取可用的硬件加速类型列表
   */
  std::vector<HardwareAccelType> GetAvailableHardwareAccel() const;

  /**
   * 获取 FFmpeg 硬件加速参数
   */
  std::string GetFFmpegHWAccelArg(HardwareAccelType type) const;

  /**
   * 配置解码器
   */
  void Configure(const DecoderConfig& config);

  /**
   * 获取当前配置
   */
  DecoderConfig GetConfig() const;

  /**
   * 更新解码器状态
   */
  void UpdateStatus(const DecoderStatus& status);

  /**
   * 处理解码器降级事件
   */
  void OnDecoderFallback(const std::string& reason);

  /**
   * 设置状态回调
   */
  void SetStatusCallback(StatusCallback callback);

  /**
   * 获取当前解码器状态
   */
  DecoderStatus GetStatus() const;

  /**
   * 获取推荐的解码配置
   */
  DecoderConfig GetRecommendedConfig() const;

 private:
  DecoderConfig config_;
  DecoderStatus status_;
  StatusCallback status_callback_;

  bool CheckDXVA2Support() const;
  bool CheckD3D11VASupport() const;
};

}  // namespace mango_player

#endif  // WINDOWS_DECODER_PROVIDER_H_
