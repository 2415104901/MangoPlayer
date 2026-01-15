/**
 * MangoPlayer Native Core - Event Bridge Implementation
 * 
 * 事件桥接实现 - 100% 跨平台代码
 */

#include "mango_player/event_bridge.h"

namespace mango_player {

EventBridge::EventBridge() = default;

EventBridge::~EventBridge() {
    RemoveAllListeners();
}

int EventBridge::AddListener(EventCallback callback) {
    std::lock_guard<std::mutex> lock(listeners_mutex_);
    int id = next_listener_id_++;
    listeners_.push_back({id, std::move(callback)});
    return id;
}

void EventBridge::RemoveListener(int listener_id) {
    std::lock_guard<std::mutex> lock(listeners_mutex_);
    listeners_.erase(
        std::remove_if(listeners_.begin(), listeners_.end(),
            [listener_id](const Listener& l) { return l.id == listener_id; }),
        listeners_.end()
    );
}

void EventBridge::RemoveAllListeners() {
    std::lock_guard<std::mutex> lock(listeners_mutex_);
    listeners_.clear();
}

void EventBridge::EmitStateChanged(PlayerState state) {
    PlayerEvent event{};
    event.type = EventType::StateChanged;
    event.state = state;
    EmitEvent(event);
}

void EventBridge::EmitPositionChanged(int64_t position_ms) {
    PlayerEvent event{};
    event.type = EventType::PositionChanged;
    event.position_ms = position_ms;
    EmitEvent(event);
}

void EventBridge::EmitBufferingUpdate(double percent) {
    PlayerEvent event{};
    event.type = EventType::BufferingUpdate;
    event.buffering_percent = percent;
    EmitEvent(event);
}

void EventBridge::EmitDurationChanged(int64_t duration_ms) {
    PlayerEvent event{};
    event.type = EventType::DurationChanged;
    event.position_ms = duration_ms;  // 复用 position_ms 字段
    EmitEvent(event);
}

void EventBridge::EmitVideoSizeChanged(int width, int height) {
    PlayerEvent event{};
    event.type = EventType::VideoSizeChanged;
    // 可以扩展 PlayerEvent 结构来存储 width/height
    EmitEvent(event);
}

void EventBridge::EmitFirstFrameRendered() {
    PlayerEvent event{};
    event.type = EventType::FirstFrameRendered;
    EmitEvent(event);
}

void EventBridge::EmitSeekCompleted(int64_t position_ms) {
    PlayerEvent event{};
    event.type = EventType::SeekCompleted;
    event.position_ms = position_ms;
    EmitEvent(event);
}

void EventBridge::EmitPlaybackCompleted() {
    PlayerEvent event{};
    event.type = EventType::PlaybackCompleted;
    EmitEvent(event);
}

void EventBridge::EmitError(ErrorCode code, const std::string& message) {
    PlayerEvent event{};
    event.type = EventType::Error;
    event.error_code = code;
    event.error_message = message;
    EmitEvent(event);
}

void EventBridge::EmitPerformanceUpdate(const PerformanceMetrics& metrics) {
    PlayerEvent event{};
    event.type = EventType::PerformanceUpdate;
    event.metrics = metrics;
    EmitEvent(event);
}

void EventBridge::EmitEvent(const PlayerEvent& event) {
    if (queue_mode_enabled_) {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        event_queue_.push(event);
    } else {
        DispatchEvent(event);
    }
}

void EventBridge::EnableQueueMode(bool enable) {
    queue_mode_enabled_ = enable;
}

int EventBridge::ProcessEvents() {
    std::vector<PlayerEvent> events_to_process;
    
    {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        while (!event_queue_.empty()) {
            events_to_process.push_back(event_queue_.front());
            event_queue_.pop();
        }
    }

    for (const auto& event : events_to_process) {
        DispatchEvent(event);
    }

    return static_cast<int>(events_to_process.size());
}

size_t EventBridge::GetPendingEventCount() const {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    return event_queue_.size();
}

void EventBridge::DispatchEvent(const PlayerEvent& event) {
    std::lock_guard<std::mutex> lock(listeners_mutex_);
    for (const auto& listener : listeners_) {
        if (listener.callback) {
            listener.callback(event);
        }
    }
}

} // namespace mango_player
