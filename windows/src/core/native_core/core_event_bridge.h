// MangoPlayer Windows Plugin
// Core Event Bridge - Events from Native to Dart (Shared with macOS)

#ifndef CORE_EVENT_BRIDGE_H_
#define CORE_EVENT_BRIDGE_H_

#include <functional>
#include <string>
#include <mutex>

namespace mango_player {
namespace native_core {

// Event types
enum class PlayerEventType {
  StateChanged,
  PositionChanged,
  BufferingUpdate,
  Error,
  MediaInfo,
  PlaybackCompleted
};

// Player states (matching Dart PlayerState enum)
enum class PlayerStateNative {
  Idle,
  Initializing,
  Ready,
  Playing,
  Paused,
  Buffering,
  Completed,
  Error
};

// Callback types
using StateCallback = std::function<void(PlayerStateNative state)>;
using ProgressCallback = std::function<void(int64_t position, int64_t duration, 
                                            int64_t buffered, double buffer_pct)>;
using ErrorEventCallback = std::function<void(const std::string& code, const std::string& message)>;

class CoreEventBridge {
 public:
  CoreEventBridge() = default;
  ~CoreEventBridge() = default;

  // Set callbacks
  void SetStateCallback(StateCallback callback);
  void SetProgressCallback(ProgressCallback callback);
  void SetErrorCallback(ErrorEventCallback callback);

  // Emit events
  void EmitStateChange(PlayerStateNative state);
  void EmitProgress(int64_t position, int64_t duration, 
                    int64_t buffered = 0, double buffer_pct = 0.0);
  void EmitError(const std::string& code, const std::string& message);

  // Get string representation of state
  static std::string StateToString(PlayerStateNative state);

 private:
  StateCallback state_callback_;
  ProgressCallback progress_callback_;
  ErrorEventCallback error_callback_;
  std::mutex mutex_;
};

}  // namespace native_core
}  // namespace mango_player

#endif  // CORE_EVENT_BRIDGE_H_
