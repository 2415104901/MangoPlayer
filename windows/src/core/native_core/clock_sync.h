// MangoPlayer Windows Plugin
// Clock Sync - AV Synchronization (Shared with macOS)

#ifndef CLOCK_SYNC_H_
#define CLOCK_SYNC_H_

#include <atomic>
#include <chrono>
#include <mutex>

namespace mango_player {
namespace native_core {

class ClockSync {
 public:
  ClockSync();
  ~ClockSync() = default;

  // Set the master clock (video or audio)
  void SetMasterPts(int64_t pts_ms);

  // Get current playback time (extrapolated)
  int64_t GetCurrentPts() const;

  // Set playback speed
  void SetPlaybackSpeed(double speed);
  double GetPlaybackSpeed() const { return speed_.load(); }

  // Pause/resume clock
  void Pause();
  void Resume();
  bool IsPaused() const { return is_paused_.load(); }

  // Reset clock
  void Reset();

  // Seek - update base time
  void Seek(int64_t pts_ms);

  // Calculate delay needed for frame presentation
  // Returns delay in milliseconds, negative means frame is late
  int64_t GetFrameDelay(int64_t frame_pts_ms) const;

 private:
  std::chrono::steady_clock::time_point base_time_;
  std::atomic<int64_t> base_pts_{0};  // in milliseconds
  std::atomic<double> speed_{1.0};
  std::atomic<bool> is_paused_{false};
  std::chrono::steady_clock::time_point pause_time_;
  mutable std::mutex mutex_;
};

}  // namespace native_core
}  // namespace mango_player

#endif  // CLOCK_SYNC_H_
