/**
 * MangoPlayer Native Core - Event Bridge
 * 
 * 事件桥接模块 - 100% 跨平台代码
 * 管理播放器事件的发送和接收
 */

#pragma once

#include "types.h"
#include <functional>
#include <vector>
#include <mutex>
#include <queue>
#include <atomic>

namespace mango_player {

/**
 * 事件桥接器
 * 
 * 此类为 100% 跨平台实现
 * 用于在 native core 和平台层之间传递事件
 * 
 * 设计模式: 生产者-消费者 + 观察者模式
 * 
 * 使用示例:
 * ```cpp
 * EventBridge bridge;
 * 
 * // 注册监听器 (平台层)
 * bridge.AddListener([](const PlayerEvent& e) {
 *     // 转发到 Flutter EventChannel
 * });
 * 
 * // 发送事件 (播放核心)
 * bridge.EmitStateChanged(PlayerState::Playing);
 * bridge.EmitPositionChanged(current_position_ms);
 * 
 * // 处理队列中的事件 (可选，用于异步处理)
 * bridge.ProcessEvents();
 * ```
 */
class EventBridge {
public:
    EventBridge();
    ~EventBridge();

    /**
     * 添加事件监听器
     * @param callback 事件回调函数
     * @return 监听器 ID，用于后续移除
     */
    int AddListener(EventCallback callback);

    /**
     * 移除事件监听器
     * @param listener_id 监听器 ID
     */
    void RemoveListener(int listener_id);

    /**
     * 移除所有监听器
     */
    void RemoveAllListeners();

    // =========================================================================
    // 事件发送方法 (由播放核心调用)
    // =========================================================================

    /**
     * 发送状态变更事件
     */
    void EmitStateChanged(PlayerState state);

    /**
     * 发送播放位置变更事件
     */
    void EmitPositionChanged(int64_t position_ms);

    /**
     * 发送缓冲进度事件
     */
    void EmitBufferingUpdate(double percent);

    /**
     * 发送时长变更事件
     */
    void EmitDurationChanged(int64_t duration_ms);

    /**
     * 发送视频尺寸变更事件
     */
    void EmitVideoSizeChanged(int width, int height);

    /**
     * 发送首帧渲染事件
     */
    void EmitFirstFrameRendered();

    /**
     * 发送 Seek 完成事件
     */
    void EmitSeekCompleted(int64_t position_ms);

    /**
     * 发送播放完成事件
     */
    void EmitPlaybackCompleted();

    /**
     * 发送错误事件
     */
    void EmitError(ErrorCode code, const std::string& message);

    /**
     * 发送性能更新事件
     */
    void EmitPerformanceUpdate(const PerformanceMetrics& metrics);

    /**
     * 发送自定义事件
     */
    void EmitEvent(const PlayerEvent& event);

    // =========================================================================
    // 队列处理 (可选，用于线程安全的异步事件处理)
    // =========================================================================

    /**
     * 启用事件队列模式
     * 事件将被放入队列，需要手动调用 ProcessEvents() 处理
     */
    void EnableQueueMode(bool enable);

    /**
     * 处理队列中的所有事件
     * @return 处理的事件数量
     */
    int ProcessEvents();

    /**
     * 获取队列中待处理的事件数量
     */
    size_t GetPendingEventCount() const;

private:
    struct Listener {
        int id;
        EventCallback callback;
    };

    std::vector<Listener> listeners_;
    mutable std::mutex listeners_mutex_;

    std::queue<PlayerEvent> event_queue_;
    mutable std::mutex queue_mutex_;

    std::atomic<bool> queue_mode_enabled_{false};
    std::atomic<int> next_listener_id_{1};

    void DispatchEvent(const PlayerEvent& event);
};

} // namespace mango_player
