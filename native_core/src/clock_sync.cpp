/**
 * MangoPlayer Native Core - Clock Sync Implementation
 * 
 * 音视频同步实现 - 100% 跨平台代码
 */

#include "mango_player/clock_sync.h"

namespace mango_player {

ClockSync::ClockSync(SyncStrategy strategy)
    : strategy_(strategy)
{
}

void ClockSync::SetStrategy(SyncStrategy strategy) {
    strategy_ = strategy;
}

void ClockSync::Start() {
    std::lock_guard<std::mutex> lock(mutex_);
    start_time_ = std::chrono::steady_clock::now();
    pause_offset_ms_ = 0;
    is_paused_ = false;
    audio_clock_ms_ = 0;
    video_clock_ms_ = 0;
    dropped_frames_ = 0;
}

void ClockSync::Pause() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!is_paused_) {
        pause_time_ = std::chrono::steady_clock::now();
        is_paused_ = true;
    }
}

void ClockSync::Resume() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (is_paused_) {
        auto now = std::chrono::steady_clock::now();
        auto pause_duration = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - pause_time_).count();
        pause_offset_ms_ += pause_duration;
        is_paused_ = false;
    }
}

void ClockSync::Reset() {
    std::lock_guard<std::mutex> lock(mutex_);
    start_time_ = std::chrono::steady_clock::now();
    pause_offset_ms_ = 0;
    audio_clock_ms_ = 0;
    video_clock_ms_ = 0;
    // 不重置 dropped_frames_，保留统计
}

void ClockSync::SetSpeed(double speed) {
    if (speed >= 0.25 && speed <= 4.0) {
        playback_speed_ = speed;
    }
}

void ClockSync::UpdateAudioClock(int64_t pts_ms) {
    audio_clock_ms_ = pts_ms;
}

void ClockSync::UpdateVideoClock(int64_t pts_ms) {
    video_clock_ms_ = pts_ms;
}

SyncAction ClockSync::GetVideoSyncAction(int64_t video_pts_ms, int64_t& out_delay_ms) {
    out_delay_ms = 0;

    int64_t master_clock = GetMasterClockMs();
    int64_t diff = video_pts_ms - master_clock;

    // 应用播放速度
    diff = static_cast<int64_t>(diff / playback_speed_.load());

    if (diff > sync_threshold_ms_) {
        // 视频太快，需要等待
        out_delay_ms = diff - sync_threshold_ms_;
        return SyncAction::Wait;
    } else if (diff < -max_skip_threshold_ms_) {
        // 视频太慢，丢帧
        dropped_frames_++;
        return SyncAction::Skip;
    } else if (diff < -sync_threshold_ms_) {
        // 轻微滞后，但仍显示
        return SyncAction::Display;
    } else {
        // 同步良好
        return SyncAction::Display;
    }
}

int64_t ClockSync::GetCurrentPositionMs() const {
    return GetMasterClockMs();
}

int64_t ClockSync::GetAVDiffMs() const {
    return video_clock_ms_.load() - audio_clock_ms_.load();
}

void ClockSync::SetSyncThreshold(int64_t threshold_ms) {
    sync_threshold_ms_ = threshold_ms;
}

int64_t ClockSync::GetMasterClockMs() const {
    switch (strategy_) {
        case SyncStrategy::AudioMaster:
            return audio_clock_ms_.load();
        case SyncStrategy::VideoMaster:
            return video_clock_ms_.load();
        case SyncStrategy::ExternalClock:
        default:
            return GetSystemTimeMs();
    }
}

int64_t ClockSync::GetSystemTimeMs() const {
    if (is_paused_) {
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
            pause_time_ - start_time_).count();
        return static_cast<int64_t>((duration - pause_offset_ms_) * playback_speed_.load());
    }

    auto now = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        now - start_time_).count();
    return static_cast<int64_t>((duration - pause_offset_ms_) * playback_speed_.load());
}

} // namespace mango_player
