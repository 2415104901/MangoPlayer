// MangoPlayer Windows Plugin
// Clock Sync - AV Synchronization Implementation

#include "clock_sync.h"

namespace mango_player {
namespace native_core {

ClockSync::ClockSync() 
    : base_time_(std::chrono::steady_clock::now()) {}

void ClockSync::SetMasterPts(int64_t pts_ms) {
  std::lock_guard<std::mutex> lock(mutex_);
  base_time_ = std::chrono::steady_clock::now();
  base_pts_.store(pts_ms);
}

int64_t ClockSync::GetCurrentPts() const {
  std::lock_guard<std::mutex> lock(mutex_);

  if (is_paused_.load()) {
    return base_pts_.load();
  }

  auto now = std::chrono::steady_clock::now();
  auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
      now - base_time_).count();

  double speed = speed_.load();
  int64_t adjusted_elapsed = static_cast<int64_t>(elapsed * speed);

  return base_pts_.load() + adjusted_elapsed;
}

void ClockSync::SetPlaybackSpeed(double speed) {
  std::lock_guard<std::mutex> lock(mutex_);

  // Update base pts and time before changing speed
  if (!is_paused_.load()) {
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        now - base_time_).count();
    double current_speed = speed_.load();
    int64_t adjusted_elapsed = static_cast<int64_t>(elapsed * current_speed);
    base_pts_.store(base_pts_.load() + adjusted_elapsed);
    base_time_ = now;
  }

  speed_.store(speed);
}

void ClockSync::Pause() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (!is_paused_.load()) {
    // Update base_pts to current time before pausing
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        now - base_time_).count();
    double speed = speed_.load();
    int64_t adjusted_elapsed = static_cast<int64_t>(elapsed * speed);
    base_pts_.store(base_pts_.load() + adjusted_elapsed);
    
    pause_time_ = now;
    is_paused_.store(true);
  }
}

void ClockSync::Resume() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (is_paused_.load()) {
    base_time_ = std::chrono::steady_clock::now();
    is_paused_.store(false);
  }
}

void ClockSync::Reset() {
  std::lock_guard<std::mutex> lock(mutex_);
  base_time_ = std::chrono::steady_clock::now();
  base_pts_.store(0);
  speed_.store(1.0);
  is_paused_.store(false);
}

void ClockSync::Seek(int64_t pts_ms) {
  std::lock_guard<std::mutex> lock(mutex_);
  base_time_ = std::chrono::steady_clock::now();
  base_pts_.store(pts_ms);
}

int64_t ClockSync::GetFrameDelay(int64_t frame_pts_ms) const {
  int64_t current_pts = GetCurrentPts();
  return frame_pts_ms - current_pts;
}

}  // namespace native_core
}  // namespace mango_player
