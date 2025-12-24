#include "dxva_config_manager.h"

#include <algorithm>
#include <chrono>

namespace mango_player {

namespace {

// DXVA2/D3D11VA 解码器 GUID
const GUID DXVA2_ModeH264_VLD_NoFGT = {
    0x1b81be68, 0xa0c7, 0x11d3,
    {0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5}};

const GUID DXVA2_ModeHEVC_VLD_Main = {
    0x5b11d51b, 0x2f4c, 0x4452,
    {0xbc, 0xc3, 0x09, 0xf2, 0xa1, 0x16, 0x0c, 0xc0}};

const GUID DXVA2_ModeVP9_VLD_Profile0 = {
    0x463707f8, 0xa1d0, 0x4585,
    {0x87, 0x6d, 0x83, 0xaa, 0x6d, 0x60, 0xb8, 0x9e}};

int64_t GetCurrentTimestamp() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

std::string FallbackReasonToString(DxvaConfigManager::FallbackReason reason) {
  switch (reason) {
    case DxvaConfigManager::FallbackReason::kCodecNotSupported:
      return "codec_not_supported";
    case DxvaConfigManager::FallbackReason::kResolutionTooHigh:
      return "resolution_too_high";
    case DxvaConfigManager::FallbackReason::kDecodeError:
      return "decode_error";
    case DxvaConfigManager::FallbackReason::kTimeout:
      return "timeout";
    default:
      return "unknown";
  }
}

}  // namespace

DxvaConfigManager::DxvaConfigManager() = default;

DxvaConfigManager::~DxvaConfigManager() = default;

bool DxvaConfigManager::Initialize() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (initialized_) {
    return true;
  }

  // 创建 D3D11 设备
  D3D_FEATURE_LEVEL feature_levels[] = {
      D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1,
      D3D_FEATURE_LEVEL_10_0};

  D3D_FEATURE_LEVEL actual_feature_level;
  UINT flags = D3D11_CREATE_DEVICE_VIDEO_SUPPORT;

#ifdef _DEBUG
  flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

  HRESULT hr = D3D11CreateDevice(
      nullptr,                   // 默认适配器
      D3D_DRIVER_TYPE_HARDWARE,  // 硬件驱动
      nullptr,                   // 无软件模块
      flags, feature_levels, ARRAYSIZE(feature_levels), D3D11_SDK_VERSION,
      &d3d_device_, &actual_feature_level, &d3d_context_);

  if (FAILED(hr)) {
    return false;
  }

  // 获取视频设备接口
  hr = d3d_device_.As(&video_device_);
  if (FAILED(hr)) {
    // 某些设备可能不支持视频设备接口
    // 但仍然可以使用软件解码
  }

  // 检测硬件能力
  DetectHardwareCapabilities();

  initialized_ = true;
  return true;
}

void DxvaConfigManager::DetectHardwareCapabilities() {
  hardware_capabilities_.clear();

  // H.264 支持检测
  bool h264_supported = CheckD3d11vaSupport(DXVA2_ModeH264_VLD_NoFGT);
  hardware_capabilities_.push_back(HardwareDecoderCapability{
      "H264_DXVA2",
      "H.264",
      h264_supported,
      4096,
      2160,
      {"Baseline", "Main", "High"}});

  // HEVC 支持检测
  bool hevc_supported = CheckD3d11vaSupport(DXVA2_ModeHEVC_VLD_Main);
  hardware_capabilities_.push_back(HardwareDecoderCapability{
      "HEVC_DXVA2", "HEVC", hevc_supported, 8192, 4320, {"Main", "Main 10"}});

  // VP9 支持检测
  bool vp9_supported = CheckD3d11vaSupport(DXVA2_ModeVP9_VLD_Profile0);
  hardware_capabilities_.push_back(HardwareDecoderCapability{
      "VP9_DXVA2", "VP9", vp9_supported, 8192, 4320, {"Profile 0"}});
}

bool DxvaConfigManager::CheckD3d11vaSupport(const GUID& profile_guid) const {
  if (!video_device_) {
    return false;
  }

  // 检查视频设备是否支持指定的解码器配置
  UINT profile_count = video_device_->GetVideoDecoderProfileCount();

  for (UINT i = 0; i < profile_count; ++i) {
    GUID profile;
    HRESULT hr = video_device_->GetVideoDecoderProfile(i, &profile);
    if (SUCCEEDED(hr) && IsEqualGUID(profile, profile_guid)) {
      return true;
    }
  }

  return false;
}

bool DxvaConfigManager::CheckDxva2Support(const GUID& decoder_guid) const {
  // DXVA2 支持检查 (备用方案)
  // 这里简化处理，实际应该使用 IDirectXVideoDecoderService
  return false;
}

std::vector<DxvaConfigManager::HardwareDecoderCapability>
DxvaConfigManager::GetAvailableHardwareDecoders() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return hardware_capabilities_;
}

bool DxvaConfigManager::IsHardwareDecodeSupported(
    const std::string& codec_type) const {
  std::lock_guard<std::mutex> lock(mutex_);

  for (const auto& cap : hardware_capabilities_) {
    if (cap.codec_type == codec_type && cap.is_supported) {
      return true;
    }
  }
  return false;
}

DxvaConfigManager::SupportedCodecs DxvaConfigManager::GetSupportedCodecs()
    const {
  return SupportedCodecs{IsHardwareDecodeSupported("H.264"),
                         IsHardwareDecodeSupported("HEVC"),
                         IsHardwareDecodeSupported("VP9"), false};
}

std::vector<std::pair<std::string, std::string>>
DxvaConfigManager::GetFFmpegOptions(const DecoderConfiguration& config) const {
  std::vector<std::pair<std::string, std::string>> options;

  if (config.enable_hardware_decode) {
    // 使用 D3D11VA 硬件加速
    if (config.prefer_d3d11va) {
      options.push_back({"hwaccel", "d3d11va"});
      options.push_back({"hwaccel_output_format", "d3d11"});
    } else {
      options.push_back({"hwaccel", "dxva2"});
      options.push_back({"hwaccel_output_format", "dxva2_vld"});
    }

    // 设备句柄 (需要在实际使用时填入)
    options.push_back({"hwaccel_device", "auto"});
  }

  // 线程数
  options.push_back({"threads", "auto"});

  // 参考帧限制
  options.push_back({"refcounted_frames", "1"});

  return options;
}

void DxvaConfigManager::ApplyConfiguration(const DecoderConfiguration& config) {
  std::lock_guard<std::mutex> lock(mutex_);
  configuration_ = config;
}

DxvaConfigManager::DecoderConfiguration
DxvaConfigManager::GetCurrentConfiguration() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return configuration_;
}

bool DxvaConfigManager::SupportsResolution(int width, int height,
                                           const std::string& codec_type) const {
  std::lock_guard<std::mutex> lock(mutex_);

  for (const auto& cap : hardware_capabilities_) {
    if (cap.codec_type == codec_type && cap.is_supported &&
        cap.max_width >= width && cap.max_height >= height) {
      return true;
    }
  }
  return false;
}

DxvaConfigManager::DecoderConfiguration
DxvaConfigManager::GetRecommendedConfiguration(
    int width, int height, const std::string& codec_type) const {
  bool supports_hardware = SupportsResolution(width, height, codec_type);
  bool supports_hevc = SupportsResolution(width, height, "HEVC");

  return DecoderConfiguration{supports_hardware, supports_hevc, true, 0, {}};
}

void DxvaConfigManager::RecordFallback(const std::string& from_codec,
                                       const std::string& to_codec,
                                       FallbackReason reason) {
  std::lock_guard<std::mutex> lock(mutex_);

  FallbackEvent event{from_codec, to_codec, reason, GetCurrentTimestamp()};
  fallback_history_.push_back(event);

  if (fallback_callback_) {
    fallback_callback_(event);
  }
}

void DxvaConfigManager::SetFallbackCallback(FallbackCallback callback) {
  std::lock_guard<std::mutex> lock(mutex_);
  fallback_callback_ = std::move(callback);
}

std::vector<DxvaConfigManager::FallbackEvent>
DxvaConfigManager::GetFallbackHistory() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return fallback_history_;
}

void DxvaConfigManager::ClearFallbackHistory() {
  std::lock_guard<std::mutex> lock(mutex_);
  fallback_history_.clear();
}

}  // namespace mango_player
