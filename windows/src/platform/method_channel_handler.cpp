// MangoPlayer Windows Plugin
// Platform Channel Handler - Method Channel Implementation

#include "method_channel_handler.h"
#include "../core/ffmpeg_player_manager.h"
#include "texture_registry_handler.h"

#include <sstream>
#include <optional>

namespace mango_player {

MethodChannelHandler::MethodChannelHandler(
    flutter::BinaryMessenger* messenger,
    std::shared_ptr<FFmpegPlayerManager> player_manager,
    std::shared_ptr<TextureRegistryHandler> texture_handler)
    : messenger_(messenger),
      player_manager_(player_manager),
      texture_handler_(texture_handler) {}

MethodChannelHandler::~MethodChannelHandler() {
  StopListening();
}

void MethodChannelHandler::StartListening() {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger_, "com.mangoplayer/player",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        this->HandleMethodCall(call, std::move(result));
      });
}

void MethodChannelHandler::StopListening() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();
  }
}

void MethodChannelHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "initialize") {
    HandleInitialize(call.arguments(), std::move(result));
  } else if (method == "play") {
    HandlePlay(std::move(result));
  } else if (method == "pause") {
    HandlePause(std::move(result));
  } else if (method == "stop") {
    HandleStop(std::move(result));
  } else if (method == "seekTo") {
    HandleSeekTo(call.arguments(), std::move(result));
  } else if (method == "setVolume") {
    HandleSetVolume(call.arguments(), std::move(result));
  } else if (method == "setPlaybackSpeed") {
    HandleSetPlaybackSpeed(call.arguments(), std::move(result));
  } else if (method == "getPosition") {
    HandleGetPosition(std::move(result));
  } else if (method == "getDuration") {
    HandleGetDuration(std::move(result));
  } else if (method == "dispose") {
    HandleDispose(std::move(result));
  } else {
    result->NotImplemented();
  }
}

void MethodChannelHandler::HandleInitialize(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!arguments) {
    result->Error("invalid_arguments", "arguments is null");
    return;
  }

  const auto* args_map = std::get_if<flutter::EncodableMap>(arguments);
  if (!args_map) {
    result->Error("invalid_arguments", "arguments is not a map");
    return;
  }

  // Extract uri
  auto uri_it = args_map->find(flutter::EncodableValue("uri"));
  if (uri_it == args_map->end()) {
    result->Error("invalid_arguments", "uri is null");
    return;
  }
  const std::string* uri = std::get_if<std::string>(&uri_it->second);
  if (!uri) {
    result->Error("invalid_arguments", "uri is not a string");
    return;
  }

  // Extract type
  auto type_it = args_map->find(flutter::EncodableValue("type"));
  std::string type = "network";
  if (type_it != args_map->end()) {
    const std::string* type_ptr = std::get_if<std::string>(&type_it->second);
    if (type_ptr) {
      type = *type_ptr;
    }
  }

  // Extract optional textureId
  std::optional<int64_t> texture_id;
  auto texture_it = args_map->find(flutter::EncodableValue("textureId"));
  if (texture_it != args_map->end()) {
    const int64_t* texture_id_ptr = std::get_if<int64_t>(&texture_it->second);
    if (texture_id_ptr) {
      texture_id = *texture_id_ptr;
    } else {
      const int32_t* texture_id_32 = std::get_if<int32_t>(&texture_it->second);
      if (texture_id_32) {
        texture_id = static_cast<int64_t>(*texture_id_32);
      }
    }
  }

  // Extract optional headers
  std::map<std::string, std::string> headers;
  auto headers_it = args_map->find(flutter::EncodableValue("headers"));
  if (headers_it != args_map->end()) {
    const auto* headers_map = std::get_if<flutter::EncodableMap>(&headers_it->second);
    if (headers_map) {
      for (const auto& pair : *headers_map) {
        const std::string* key = std::get_if<std::string>(&pair.first);
        const std::string* value = std::get_if<std::string>(&pair.second);
        if (key && value) {
          headers[*key] = *value;
        }
      }
    }
  }

  // Initialize the player
  int64_t duration_ms = player_manager_->Initialize(*uri, type, headers, texture_id);
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  response[flutter::EncodableValue("duration")] = flutter::EncodableValue(duration_ms);
  result->Success(flutter::EncodableValue(response));
}

void MethodChannelHandler::HandlePlay(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  player_manager_->Play();
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  result->Success(flutter::EncodableValue(response));
}

void MethodChannelHandler::HandlePause(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  player_manager_->Pause();
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  result->Success(flutter::EncodableValue(response));
}

void MethodChannelHandler::HandleStop(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  player_manager_->Stop();
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  result->Success(flutter::EncodableValue(response));
}

void MethodChannelHandler::HandleSeekTo(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!arguments) {
    result->Error("invalid_arguments", "arguments is null");
    return;
  }

  const auto* args_map = std::get_if<flutter::EncodableMap>(arguments);
  if (!args_map) {
    result->Error("invalid_arguments", "arguments is not a map");
    return;
  }

  auto pos_it = args_map->find(flutter::EncodableValue("position"));
  if (pos_it == args_map->end()) {
    result->Error("invalid_arguments", "position is null");
    return;
  }

  int64_t position = 0;
  const int64_t* pos_64 = std::get_if<int64_t>(&pos_it->second);
  if (pos_64) {
    position = *pos_64;
  } else {
    const int32_t* pos_32 = std::get_if<int32_t>(&pos_it->second);
    if (pos_32) {
      position = static_cast<int64_t>(*pos_32);
    }
  }

  int64_t actual_position = player_manager_->SeekTo(position);
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  response[flutter::EncodableValue("actualPosition")] = flutter::EncodableValue(actual_position);
  result->Success(flutter::EncodableValue(response));
}

void MethodChannelHandler::HandleSetVolume(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!arguments) {
    result->Error("invalid_arguments", "arguments is null");
    return;
  }

  const auto* args_map = std::get_if<flutter::EncodableMap>(arguments);
  if (!args_map) {
    result->Error("invalid_arguments", "arguments is not a map");
    return;
  }

  auto vol_it = args_map->find(flutter::EncodableValue("volume"));
  if (vol_it == args_map->end()) {
    result->Error("invalid_arguments", "volume is null");
    return;
  }

  double volume = 1.0;
  const double* vol_ptr = std::get_if<double>(&vol_it->second);
  if (vol_ptr) {
    volume = *vol_ptr;
  }

  player_manager_->SetVolume(volume);
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  result->Success(flutter::EncodableValue(response));
}

void MethodChannelHandler::HandleSetPlaybackSpeed(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!arguments) {
    result->Error("invalid_arguments", "arguments is null");
    return;
  }

  const auto* args_map = std::get_if<flutter::EncodableMap>(arguments);
  if (!args_map) {
    result->Error("invalid_arguments", "arguments is not a map");
    return;
  }

  auto speed_it = args_map->find(flutter::EncodableValue("speed"));
  if (speed_it == args_map->end()) {
    result->Error("invalid_arguments", "speed is null");
    return;
  }

  double speed = 1.0;
  const double* speed_ptr = std::get_if<double>(&speed_it->second);
  if (speed_ptr) {
    speed = *speed_ptr;
  }

  player_manager_->SetPlaybackSpeed(speed);
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  result->Success(flutter::EncodableValue(response));
}

void MethodChannelHandler::HandleGetPosition(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t position = player_manager_->GetPosition();
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  response[flutter::EncodableValue("position")] = flutter::EncodableValue(position);
  result->Success(flutter::EncodableValue(response));
}

void MethodChannelHandler::HandleGetDuration(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t duration = player_manager_->GetDuration();
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  response[flutter::EncodableValue("duration")] = flutter::EncodableValue(duration);
  result->Success(flutter::EncodableValue(response));
}

void MethodChannelHandler::HandleDispose(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  player_manager_->Release();
  
  flutter::EncodableMap response;
  response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
  result->Success(flutter::EncodableValue(response));
}

}  // namespace mango_player
