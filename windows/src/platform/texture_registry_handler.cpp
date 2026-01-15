// MangoPlayer Windows Plugin
// Platform Channel Handler - Texture Registry Implementation

#include "texture_registry_handler.h"
#include "../renderer/d3d11_texture_renderer.h"

namespace mango_player {

TextureRegistryHandler::TextureRegistryHandler(
    flutter::TextureRegistrar* texture_registrar)
    : texture_registrar_(texture_registrar) {}

TextureRegistryHandler::~TextureRegistryHandler() {
  StopListening();
}

void TextureRegistryHandler::StartListening(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.mangoplayer/texture",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        this->HandleMethodCall(call, std::move(result));
      });
}

void TextureRegistryHandler::StopListening() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();
  }

  // Clean up all textures
  std::lock_guard<std::mutex> lock(texture_mutex_);
  for (auto& pair : texture_renderers_) {
    if (pair.second) {
      pair.second->Dispose();
    }
    texture_registrar_->UnregisterTexture(pair.first);
  }
  texture_renderers_.clear();
}

void TextureRegistryHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "registerTexture") {
    int64_t texture_id = RegisterTexture();
    
    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    response[flutter::EncodableValue("textureId")] = flutter::EncodableValue(texture_id);
    result->Success(flutter::EncodableValue(response));
    
  } else if (method == "unregisterTexture") {
    const auto* arguments = call.arguments();
    if (!arguments) {
      result->Error("invalid_arguments", "arguments is null");
      return;
    }

    const auto* args_map = std::get_if<flutter::EncodableMap>(arguments);
    if (!args_map) {
      result->Error("invalid_arguments", "arguments is not a map");
      return;
    }

    auto texture_it = args_map->find(flutter::EncodableValue("textureId"));
    if (texture_it == args_map->end()) {
      result->Error("invalid_arguments", "textureId is null");
      return;
    }

    int64_t texture_id = 0;
    const int64_t* id_64 = std::get_if<int64_t>(&texture_it->second);
    if (id_64) {
      texture_id = *id_64;
    } else {
      const int32_t* id_32 = std::get_if<int32_t>(&texture_it->second);
      if (id_32) {
        texture_id = static_cast<int64_t>(*id_32);
      }
    }

    UnregisterTexture(texture_id);
    
    flutter::EncodableMap response;
    response[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    result->Success(flutter::EncodableValue(response));
    
  } else {
    result->NotImplemented();
  }
}

int64_t TextureRegistryHandler::RegisterTexture() {
  std::lock_guard<std::mutex> lock(texture_mutex_);

  // Create D3D11 texture renderer
  auto renderer = std::make_shared<D3D11TextureRenderer>(texture_registrar_);
  
  if (!renderer->Initialize()) {
    return -1;
  }

  // Register with Flutter texture registry
  int64_t texture_id = renderer->GetTextureId();
  texture_renderers_[texture_id] = renderer;

  return texture_id;
}

void TextureRegistryHandler::UnregisterTexture(int64_t texture_id) {
  std::lock_guard<std::mutex> lock(texture_mutex_);

  auto it = texture_renderers_.find(texture_id);
  if (it != texture_renderers_.end()) {
    it->second->Dispose();
    texture_registrar_->UnregisterTexture(texture_id);
    texture_renderers_.erase(it);
  }
}

std::shared_ptr<D3D11TextureRenderer> TextureRegistryHandler::GetTextureRenderer(
    int64_t texture_id) {
  std::lock_guard<std::mutex> lock(texture_mutex_);

  auto it = texture_renderers_.find(texture_id);
  if (it != texture_renderers_.end()) {
    return it->second;
  }
  return nullptr;
}

}  // namespace mango_player
