#include "windows_decoder_provider.h"

#include <windows.h>
#include <d3d11.h>

#pragma comment(lib, "d3d11.lib")

namespace mango_player {

WindowsDecoderProvider::WindowsDecoderProvider() {
  config_ = GetRecommendedConfig();
}

WindowsDecoderProvider::~WindowsDecoderProvider() = default;

bool WindowsDecoderProvider::IsHardwareDecodingSupported() const {
  return CheckD3D11VASupport() || CheckDXVA2Support();
}

bool WindowsDecoderProvider::IsHardwareAccelAvailable(HardwareAccelType type) const {
  switch (type) {
    case HardwareAccelType::kDXVA2:
      return CheckDXVA2Support();
    case HardwareAccelType::kD3D11VA:
      return CheckD3D11VASupport();
    case HardwareAccelType::kCUDA:
      // TODO: 检查 NVIDIA GPU 和 CUDA 支持
      return false;
    case HardwareAccelType::kQSV:
      // TODO: 检查 Intel GPU 和 QSV 支持
      return false;
    default:
      return false;
  }
}

std::vector<WindowsDecoderProvider::HardwareAccelType> 
WindowsDecoderProvider::GetAvailableHardwareAccel() const {
  std::vector<HardwareAccelType> available;
  
  if (CheckD3D11VASupport()) {
    available.push_back(HardwareAccelType::kD3D11VA);
  }
  if (CheckDXVA2Support()) {
    available.push_back(HardwareAccelType::kDXVA2);
  }
  
  return available;
}

std::string WindowsDecoderProvider::GetFFmpegHWAccelArg(HardwareAccelType type) const {
  switch (type) {
    case HardwareAccelType::kDXVA2:
      return "dxva2";
    case HardwareAccelType::kD3D11VA:
      return "d3d11va";
    case HardwareAccelType::kCUDA:
      return "cuda";
    case HardwareAccelType::kQSV:
      return "qsv";
    default:
      return "";
  }
}

void WindowsDecoderProvider::Configure(const DecoderConfig& config) {
  config_ = config;
  
  // 更新状态
  status_.type = config.prefer_hardware ? DecoderType::kHardware : DecoderType::kSoftware;
  status_.is_hardware_accelerated = config.prefer_hardware && 
                                     IsHardwareAccelAvailable(config.preferred_hw_type);
  status_.hw_type = status_.is_hardware_accelerated ? config.preferred_hw_type 
                                                     : HardwareAccelType::kNone;
}

WindowsDecoderProvider::DecoderConfig WindowsDecoderProvider::GetConfig() const {
  return config_;
}

void WindowsDecoderProvider::UpdateStatus(const DecoderStatus& status) {
  status_ = status;
  if (status_callback_) {
    status_callback_(status_);
  }
}

void WindowsDecoderProvider::OnDecoderFallback(const std::string& reason) {
  status_.type = DecoderType::kSoftware;
  status_.is_hardware_accelerated = false;
  status_.hw_type = HardwareAccelType::kNone;
  status_.fallback_reason = reason;
  
  if (status_callback_) {
    status_callback_(status_);
  }
}

void WindowsDecoderProvider::SetStatusCallback(StatusCallback callback) {
  status_callback_ = std::move(callback);
}

WindowsDecoderProvider::DecoderStatus WindowsDecoderProvider::GetStatus() const {
  return status_;
}

WindowsDecoderProvider::DecoderConfig 
WindowsDecoderProvider::GetRecommendedConfig() const {
  DecoderConfig config;
  config.prefer_hardware = IsHardwareDecodingSupported();
  
  // 优先使用 D3D11VA
  if (CheckD3D11VASupport()) {
    config.preferred_hw_type = HardwareAccelType::kD3D11VA;
  } else if (CheckDXVA2Support()) {
    config.preferred_hw_type = HardwareAccelType::kDXVA2;
  } else {
    config.preferred_hw_type = HardwareAccelType::kNone;
  }
  
  config.thread_count = 0;  // auto
  config.enable_low_latency = false;
  
  return config;
}

bool WindowsDecoderProvider::CheckDXVA2Support() const {
  // DXVA2 从 Windows Vista 开始支持
  OSVERSIONINFOEX osvi;
  ZeroMemory(&osvi, sizeof(OSVERSIONINFOEX));
  osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEX);
  osvi.dwMajorVersion = 6;  // Vista+
  
  DWORDLONG condition_mask = 0;
  VER_SET_CONDITION(condition_mask, VER_MAJORVERSION, VER_GREATER_EQUAL);
  
  return VerifyVersionInfo(&osvi, VER_MAJORVERSION, condition_mask) != FALSE;
}

bool WindowsDecoderProvider::CheckD3D11VASupport() const {
  // 尝试创建 D3D11 设备以检查支持
  D3D_FEATURE_LEVEL feature_level;
  ID3D11Device* device = nullptr;
  ID3D11DeviceContext* context = nullptr;
  
  HRESULT hr = D3D11CreateDevice(
      nullptr,                    // 默认适配器
      D3D_DRIVER_TYPE_HARDWARE,   // 硬件驱动
      nullptr,                    // 无软件设备
      D3D11_CREATE_DEVICE_VIDEO_SUPPORT,  // 视频支持
      nullptr,                    // 默认功能级别
      0,                          // 功能级别数量
      D3D11_SDK_VERSION,          // SDK 版本
      &device,
      &feature_level,
      &context
  );
  
  bool supported = SUCCEEDED(hr);
  
  if (context) context->Release();
  if (device) device->Release();
  
  return supported;
}

}  // namespace mango_player
