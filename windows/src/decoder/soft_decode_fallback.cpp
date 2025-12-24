#include "soft_decode_fallback.h"

#include <chrono>

namespace mango_player {

namespace {

int64_t GetCurrentTimestamp() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

}  // namespace

SoftDecodeFallback::SoftDecodeFallback() {
  current_status_ = {DecoderType::kHardware, "", true, "", 0};
}

SoftDecodeFallback::~SoftDecodeFallback() = default;

void SoftDecodeFallback::SetFallbackStrategy(FallbackStrategy strategy) {
  std::lock_guard<std::mutex> lock(mutex_);
  strategy_ = strategy;
}

SoftDecodeFallback::FallbackStrategy SoftDecodeFallback::GetFallbackStrategy()
    const {
  std::lock_guard<std::mutex> lock(mutex_);
  return strategy_;
}

void SoftDecodeFallback::SetPerformanceThresholds(
    const PerformanceThresholds& thresholds) {
  std::lock_guard<std::mutex> lock(mutex_);
  thresholds_ = thresholds;
}

SoftDecodeFallback::PerformanceThresholds
SoftDecodeFallback::GetPerformanceThresholds() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return thresholds_;
}

bool SoftDecodeFallback::ReportDecodeError(int error_code,
                                           const std::string& error_message) {
  std::lock_guard<std::mutex> lock(mutex_);

  consecutive_errors_++;

  // 检查是否超过阈值
  if (consecutive_errors_ >= thresholds_.max_consecutive_errors) {
    return true;  // 应该触发回退
  }

  // 根据策略决定是否回退
  switch (strategy_) {
    case FallbackStrategy::kImmediate:
      return true;

    case FallbackStrategy::kRetryOnce:
      return consecutive_errors_ > 1;

    case FallbackStrategy::kGraceful:
    case FallbackStrategy::kManual:
    default:
      return false;
  }
}

void SoftDecodeFallback::ReportPerformanceMetrics(double decode_time_ms,
                                                  bool frame_dropped) {
  std::lock_guard<std::mutex> lock(mutex_);

  // 更新平均解码时间
  decode_count_++;
  avg_decode_time_ms_ =
      ((avg_decode_time_ms_ * (decode_count_ - 1)) + decode_time_ms) /
      decode_count_;

  // 更新丢帧统计
  if (frame_dropped) {
    recent_frame_drops_++;
  }

  // 成功解码，重置错误计数
  if (!frame_dropped && decode_time_ms < thresholds_.max_decode_time_ms) {
    consecutive_errors_ = 0;
  }
}

bool SoftDecodeFallback::ShouldFallback() const {
  std::lock_guard<std::mutex> lock(mutex_);

  // 已经是软解
  if (current_status_.type == DecoderType::kSoftware) {
    return false;
  }

  return IsPerformanceBelowThreshold();
}

bool SoftDecodeFallback::IsPerformanceBelowThreshold() const {
  // 检查连续错误
  if (consecutive_errors_ >= thresholds_.max_consecutive_errors) {
    return true;
  }

  // 检查平均解码时间
  if (decode_count_ > 10 &&
      avg_decode_time_ms_ > thresholds_.max_decode_time_ms) {
    return true;
  }

  // 检查丢帧数
  if (recent_frame_drops_ >= thresholds_.max_frame_drops) {
    return true;
  }

  return false;
}

void SoftDecodeFallback::ExecuteFallback(const std::string& reason) {
  std::lock_guard<std::mutex> lock(mutex_);

  UpdateStatus(DecoderType::kSoftware, "ffmpeg", reason);

  // 重置性能统计
  consecutive_errors_ = 0;
  recent_frame_drops_ = 0;
  avg_decode_time_ms_ = 0.0;
  decode_count_ = 0;
}

bool SoftDecodeFallback::TryRecoverToHardware() {
  std::lock_guard<std::mutex> lock(mutex_);

  // 已经是硬解
  if (current_status_.type == DecoderType::kHardware) {
    return true;
  }

  // 检查恢复尝试次数
  if (recovery_attempts_ >= kMaxRecoveryAttempts) {
    return false;
  }

  recovery_attempts_++;

  // 尝试恢复到硬解
  UpdateStatus(DecoderType::kHardware, "dxva2", "recovery_attempt");

  // 重置性能统计
  consecutive_errors_ = 0;
  recent_frame_drops_ = 0;
  avg_decode_time_ms_ = 0.0;
  decode_count_ = 0;

  return true;
}

SoftDecodeFallback::DecoderStatus SoftDecodeFallback::GetCurrentStatus() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return current_status_;
}

void SoftDecodeFallback::SetStatusCallback(StatusCallback callback) {
  std::lock_guard<std::mutex> lock(mutex_);
  status_callback_ = std::move(callback);
}

void SoftDecodeFallback::UpdateStatus(DecoderType type,
                                      const std::string& codec_name,
                                      const std::string& reason) {
  current_status_ = {type,
                     codec_name,
                     type == DecoderType::kHardware,
                     reason,
                     GetCurrentTimestamp()};

  if (status_callback_) {
    status_callback_(current_status_);
  }
}

void SoftDecodeFallback::Reset() {
  std::lock_guard<std::mutex> lock(mutex_);

  current_status_ = {DecoderType::kHardware, "", true, "", 0};
  consecutive_errors_ = 0;
  recent_frame_drops_ = 0;
  avg_decode_time_ms_ = 0.0;
  decode_count_ = 0;
  recovery_attempts_ = 0;
}

std::vector<std::pair<std::string, std::string>>
SoftDecodeFallback::GetSoftDecoderOptions(const std::string& codec_name) const {
  std::vector<std::pair<std::string, std::string>> options;

  // 禁用硬件加速
  options.push_back({"hwaccel", "none"});

  // 多线程解码
  options.push_back({"threads", "auto"});

  // 低延迟模式
  options.push_back({"flags", "low_delay"});

  // 参考帧
  options.push_back({"refcounted_frames", "1"});

  // 特定编解码器优化
  if (codec_name == "h264" || codec_name == "H.264") {
    // H.264 优化
    options.push_back({"skip_loop_filter", "noref"});
  } else if (codec_name == "hevc" || codec_name == "H.265") {
    // HEVC 优化
    options.push_back({"skip_loop_filter", "noref"});
  }

  return options;
}

}  // namespace mango_player
