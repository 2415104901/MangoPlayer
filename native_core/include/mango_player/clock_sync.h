/**
 * MangoPlayer Native Core - Clock Sync (AV Synchronization)
 * 
 * 音视频同步模块 - 100% 跨平台代码
 * 实现音视频同步策略 (以音频为主时钟)
 */

#pragma once

#include "types.h"
#include <chrono>
#include <atomic>
#include <mutex>

namespace mango_player {

/**
 * 同步策略枚举
 */
enum class SyncStrategy {
    AudioMaster,   // 以音频为主时钟 (默认，最常用)
    VideoMaster,   // 以视频为主时钟
    ExternalClock  // 使用外部时钟
};

/**
 * 帧同步结果
 */
enum class SyncAction {
    Display,       // 正常显示
    Skip,          // 跳过此帧 (太慢了)
    Wait,          // 等待 (太快了)
    Repeat         // 重复上一帧
};

/**
 * 音视频同步器
 * 
 * 此类为 100% 跨平台实现，纯数学逻辑
 * 
 * 使用示例:
 * ```cpp
 * ClockSync sync(SyncStrategy::AudioMaster);
 * sync.Start();
 * 
 * // 音频线程
 * sync.UpdateAudioClock(audio_pts);
 * 
 * // 视频线程
 * SyncAction action = sync.GetVideoSyncAction(video_pts);
 * switch (action) {
 *     case SyncAction::Display: render(frame); break;
 *     case SyncAction::Skip: drop(frame); break;
 *     case SyncAction::Wait: sleep_and_render(frame); break;
 * }
 * ```
 */
class ClockSync {
public:
    explicit ClockSync(SyncStrategy strategy = SyncStrategy::AudioMaster);
    ~ClockSync() = default;

    /**
     * 设置同步策略
     */
    void SetStrategy(SyncStrategy strategy);

    /**
     * 开始同步 (记录起始时间)
     */
    void Start();

    /**
     * 暂停同步
     */
    void Pause();

    /**
     * 恢复同步
     */
    void Resume();

    /**
     * 重置同步状态 (用于 seek)
     */
    void Reset();

    /**
     * 设置播放速度
     * @param speed 播放速度 (1.0 = 正常)
     */
    void SetSpeed(double speed);

    /**
     * 更新音频时钟
     * @param pts_ms 当前音频播放时间戳 (毫秒)
     */
    void UpdateAudioClock(int64_t pts_ms);

    /**
     * 更新视频时钟
     * @param pts_ms 当前视频帧时间戳 (毫秒)
     */
    void UpdateVideoClock(int64_t pts_ms);

    /**
     * 获取视频帧同步动作
     * @param video_pts_ms 视频帧时间戳 (毫秒)
     * @param out_delay_ms 输出: 如果需要等待，等待的时间 (毫秒)
     * @return 同步动作
     */
    SyncAction GetVideoSyncAction(int64_t video_pts_ms, int64_t& out_delay_ms);

    /**
     * 获取当前主时钟时间
     * @return 当前播放位置 (毫秒)
     */
    int64_t GetCurrentPositionMs() const;

    /**
     * 获取音视频差值
     * @return 视频相对于音频的延迟 (毫秒，正值表示视频滞后)
     */
    int64_t GetAVDiffMs() const;

    /**
     * 设置同步阈值
     * @param threshold_ms 允许的音视频差值阈值 (毫秒)
     */
    void SetSyncThreshold(int64_t threshold_ms);

    /**
     * 获取丢帧统计
     */
    int GetDroppedFrameCount() const { return dropped_frames_.load(); }

private:
    SyncStrategy strategy_;
    
    // 时钟值 (毫秒)
    std::atomic<int64_t> audio_clock_ms_{0};
    std::atomic<int64_t> video_clock_ms_{0};
    std::atomic<int64_t> external_clock_ms_{0};

    // 播放控制
    std::atomic<double> playback_speed_{1.0};
    std::atomic<bool> is_paused_{false};
    
    // 系统时间参考
    std::chrono::steady_clock::time_point start_time_;
    std::chrono::steady_clock::time_point pause_time_;
    int64_t pause_offset_ms_ = 0;

    // 同步参数
    int64_t sync_threshold_ms_ = 40;  // 默认 40ms (约 1 帧 @25fps)
    int64_t max_skip_threshold_ms_ = 100;  // 超过此值直接丢帧

    // 统计
    std::atomic<int> dropped_frames_{0};

    mutable std::mutex mutex_;

    int64_t GetMasterClockMs() const;
    int64_t GetSystemTimeMs() const;
};

} // namespace mango_player
