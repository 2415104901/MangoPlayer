// MangoPlayer Windows Plugin
// Platform Channel Handler - Event Channel

#ifndef EVENT_CHANNEL_HANDLER_H_
#define EVENT_CHANNEL_HANDLER_H_

#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <functional>

namespace mango_player {

class FFmpegPlayerManager;

class EventChannelHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  EventChannelHandler(flutter::BinaryMessenger* messenger,
                      std::shared_ptr<FFmpegPlayerManager> player_manager);
  ~EventChannelHandler();

  void StartListening();
  void StopListening();

  // Send event to Flutter
  void SendProgressEvent(int64_t position, int64_t duration, 
                         int64_t buffered_position, double buffer_percentage);
  void SendStateEvent(const std::string& state);
  void SendErrorEvent(const std::string& code, const std::string& message);

 protected:
  // StreamHandler overrides
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
  OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override;

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
  OnCancelInternal(const flutter::EncodableValue* arguments) override;

 private:
  flutter::BinaryMessenger* messenger_;
  std::shared_ptr<FFmpegPlayerManager> player_manager_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
};

}  // namespace mango_player

#endif  // EVENT_CHANNEL_HANDLER_H_
