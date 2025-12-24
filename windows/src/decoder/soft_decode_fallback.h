#ifndef MANGO_PLAYER_SOFT_DECODE_FALLBACK_H_
#define MANGO_PLAYER_SOFT_DECODE_FALLBACK_H_

#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace mango_player {

/// 软解回退处理器
///
/// 当硬件解码失败或不可用时，自动切换到 FFmpeg 软件解码。
/// 提供解码器选择策略和性能监控。
///
/// 任务: T112 [US6]
class SoftDecodeFallback {
 public:
  /// 解码器类型
  enum class DecoderType {
    kHardware,  // 硬件解码 (DXVA2/D3D11VA)
    kSoftware,  // 软件解码 (FFmpeg)
    kHybrid     // 混合模式
  };

  /// 解码器状态
  struct DecoderStatus {
    DecoderType type;
    std::string codec_name;
    bool is_hardware_accelerated;
    std::string fallback_reason;
    int64_t switch_timestamp;
  };

  /// 回退策略
  enum class FallbackStrategy {
    kImmediate,     // 立即切换
    kGraceful,      // 优雅切换 (等待当前帧完成)
    kRetryOnce,     // 重试一次后再切换
    kManual         // 手动控制
  };

  /// 性能阈值
  struct PerformanceThresholds {
    double max_decode_time_ms = 50.0;    // 最大解码时间
    int max_consecutive_errors = 3;       // 最大连续错误数
    double min_fps = 20.0;                // 最低帧率
    int max_frame_drops = 10;             // 最大丢帧数
  };

  /// 状态变更回调
  using StatusCallback = std::function<void(const DecoderStatus&)>;

 public:
  SoftDecodeFallback();
  ~SoftDecodeFallback();

  // 禁止复制
  SoftDecodeFallback(const SoftDecodeFallback&) = delete;
  SoftDecodeFallback& operator=(const SoftDecodeFallback&) = delete;

  /// 设置回退策略
  void SetFallbackStrategy(FallbackStrategy strategy);

  /// 获取当前回退策略
  FallbackStrategy GetFallbackStrategy() const;

  /// 设置性能阈值
  void SetPerformanceThresholds(const PerformanceThresholds& thresholds);

  /// 获取性能阈值
  PerformanceThresholds GetPerformanceThresholds() const;

  /// 报告解码错误
  /// @param error_code 错误码
  /// @param error_message 错误消息
  /// @return 是否应该触发回退
  bool ReportDecodeError(int error_code, const std::string& error_message);

  /// 报告解码性能指标
  /// @param decode_time_ms 解码耗时（毫秒）
  /// @param frame_dropped 是否丢帧
  void ReportPerformanceMetrics(double decode_time_ms, bool frame_dropped);

  /// 检查是否应该触发回退
  bool ShouldFallback() const;

  /// 执行回退
  /// @param reason 回退原因
  void ExecuteFallback(const std::string& reason);

  /// 尝试恢复到硬件解码
  /// @return 是否成功恢复
  bool TryRecoverToHardware();

  /// 获取当前解码器状态
  DecoderStatus GetCurrentStatus() const;

  /// 设置状态变更回调
  void SetStatusCallback(StatusCallback callback);

  /// 重置状态
  void Reset();

  /// 获取 FFmpeg 软解码器选项
  std::vector<std::pair<std::string, std::string>> GetSoftDecoderOptions(
      const std::string& codec_name) const;

 private:
  /// 检查性能是否低于阈值
  bool IsPerformanceBelowThreshold() const;

  /// 更新状态
  void UpdateStatus(DecoderType type, const std::string& codec_name,
                    const std::string& reason);

 private:
  mutable std::mutex mutex_;

  // 配置
  FallbackStrategy strategy_ = FallbackStrategy::kGraceful;
  PerformanceThresholds thresholds_;

  // 状态
  DecoderStatus current_status_;
  StatusCallback status_callback_;

  // 性能统计
  int consecutive_errors_ = 0;
  int recent_frame_drops_ = 0;
  double avg_decode_time_ms_ = 0.0;
  int decode_count_ = 0;

  // 恢复尝试
  int recovery_attempts_ = 0;
  static const int kMaxRecoveryAttempts = 3;
};

}  // namespace mango_player

#endif  // MANGO_PLAYER_SOFT_DECODE_FALLBACK_H_
