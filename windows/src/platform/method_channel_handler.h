// MangoPlayer Windows Plugin
// Platform Channel Handler - Method Channel

#ifndef METHOD_CHANNEL_HANDLER_H_
#define METHOD_CHANNEL_HANDLER_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <functional>

namespace mango_player {

class FFmpegPlayerManager;
class TextureRegistryHandler;

class MethodChannelHandler {
 public:
  MethodChannelHandler(flutter::BinaryMessenger* messenger,
                       std::shared_ptr<FFmpegPlayerManager> player_manager,
                       std::shared_ptr<TextureRegistryHandler> texture_handler);
  ~MethodChannelHandler();

  void StartListening();
  void StopListening();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Method handlers
  void HandleInitialize(const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandlePlay(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandlePause(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleStop(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleSeekTo(const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleSetVolume(const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleSetPlaybackSpeed(const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetPosition(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetDuration(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleDispose(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::BinaryMessenger* messenger_;
  std::shared_ptr<FFmpegPlayerManager> player_manager_;
  std::shared_ptr<TextureRegistryHandler> texture_handler_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace mango_player

#endif  // METHOD_CHANNEL_HANDLER_H_
