// MangoPlayer Windows Plugin
// Core Event Bridge Implementation

#include "core_event_bridge.h"

namespace mango_player {
namespace native_core {

void CoreEventBridge::SetStateCallback(StateCallback callback) {
  std::lock_guard<std::mutex> lock(mutex_);
  state_callback_ = callback;
}

void CoreEventBridge::SetProgressCallback(ProgressCallback callback) {
  std::lock_guard<std::mutex> lock(mutex_);
  progress_callback_ = callback;
}

void CoreEventBridge::SetErrorCallback(ErrorEventCallback callback) {
  std::lock_guard<std::mutex> lock(mutex_);
  error_callback_ = callback;
}

void CoreEventBridge::EmitStateChange(PlayerStateNative state) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (state_callback_) {
    state_callback_(state);
  }
}

void CoreEventBridge::EmitProgress(int64_t position, int64_t duration,
                                   int64_t buffered, double buffer_pct) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (progress_callback_) {
    progress_callback_(position, duration, buffered, buffer_pct);
  }
}

void CoreEventBridge::EmitError(const std::string& code, const std::string& message) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (error_callback_) {
    error_callback_(code, message);
  }
}

std::string CoreEventBridge::StateToString(PlayerStateNative state) {
  switch (state) {
    case PlayerStateNative::Idle:
      return "idle";
    case PlayerStateNative::Initializing:
      return "initializing";
    case PlayerStateNative::Ready:
      return "ready";
    case PlayerStateNative::Playing:
      return "playing";
    case PlayerStateNative::Paused:
      return "paused";
    case PlayerStateNative::Buffering:
      return "buffering";
    case PlayerStateNative::Completed:
      return "completed";
    case PlayerStateNative::Error:
      return "error";
    default:
      return "unknown";
  }
}

}  // namespace native_core
}  // namespace mango_player
