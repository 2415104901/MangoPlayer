// MangoPlayer Windows Plugin
// Platform Channel Handler - Event Channel Implementation

#include "event_channel_handler.h"
#include "../core/ffmpeg_player_manager.h"

namespace mango_player {

EventChannelHandler::EventChannelHandler(
    flutter::BinaryMessenger* messenger,
    std::shared_ptr<FFmpegPlayerManager> player_manager)
    : messenger_(messenger),
      player_manager_(player_manager) {}

EventChannelHandler::~EventChannelHandler() {
  StopListening();
}

void EventChannelHandler::StartListening() {
  channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger_, "com.mangoplayer/events",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const flutter::EncodableValue* arguments,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
            return this->OnListenInternal(arguments, std::move(events));
          },
          [this](const flutter::EncodableValue* arguments) {
            return this->OnCancelInternal(arguments);
          }));
}

void EventChannelHandler::StopListening() {
  if (channel_) {
    channel_->SetStreamHandler(nullptr);
    channel_.reset();
  }
  event_sink_.reset();
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
EventChannelHandler::OnListenInternal(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  event_sink_ = std::move(events);
  
  // Set up callback from player manager
  player_manager_->SetEventCallback(
      [this](const std::string& type, int64_t position, int64_t duration,
             int64_t buffered, double buffer_pct) {
        if (type == "progress") {
          SendProgressEvent(position, duration, buffered, buffer_pct);
        }
      },
      [this](const std::string& state) {
        SendStateEvent(state);
      });
  
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
EventChannelHandler::OnCancelInternal(const flutter::EncodableValue* arguments) {
  event_sink_.reset();
  player_manager_->SetEventCallback(nullptr, nullptr);
  return nullptr;
}

void EventChannelHandler::SendProgressEvent(
    int64_t position, int64_t duration,
    int64_t buffered_position, double buffer_percentage) {
  if (!event_sink_) return;

  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue("progress");
  event[flutter::EncodableValue("position")] = flutter::EncodableValue(position);
  event[flutter::EncodableValue("duration")] = flutter::EncodableValue(duration);
  event[flutter::EncodableValue("bufferedPosition")] = flutter::EncodableValue(buffered_position);
  event[flutter::EncodableValue("bufferPercentage")] = flutter::EncodableValue(buffer_percentage);

  event_sink_->Success(flutter::EncodableValue(event));
}

void EventChannelHandler::SendStateEvent(const std::string& state) {
  if (!event_sink_) return;

  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue("state");
  event[flutter::EncodableValue("state")] = flutter::EncodableValue(state);

  event_sink_->Success(flutter::EncodableValue(event));
}

void EventChannelHandler::SendErrorEvent(
    const std::string& code, const std::string& message) {
  if (!event_sink_) return;

  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
  event[flutter::EncodableValue("code")] = flutter::EncodableValue(code);
  event[flutter::EncodableValue("message")] = flutter::EncodableValue(message);

  event_sink_->Success(flutter::EncodableValue(event));
}

}  // namespace mango_player
