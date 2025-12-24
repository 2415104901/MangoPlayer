// MangoPlayer Windows Plugin
// Platform Channel Handler - Texture Registry

#ifndef TEXTURE_REGISTRY_HANDLER_H_
#define TEXTURE_REGISTRY_HANDLER_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <memory>
#include <map>
#include <mutex>

namespace mango_player {

class D3D11TextureRenderer;

class TextureRegistryHandler {
 public:
  TextureRegistryHandler(flutter::TextureRegistrar* texture_registrar);
  ~TextureRegistryHandler();

  void StartListening(flutter::BinaryMessenger* messenger);
  void StopListening();

  // Texture management
  int64_t RegisterTexture();
  void UnregisterTexture(int64_t texture_id);
  
  // Get texture renderer for a given texture id
  std::shared_ptr<D3D11TextureRenderer> GetTextureRenderer(int64_t texture_id);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::TextureRegistrar* texture_registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  
  std::mutex texture_mutex_;
  std::map<int64_t, std::shared_ptr<D3D11TextureRenderer>> texture_renderers_;
};

}  // namespace mango_player

#endif  // TEXTURE_REGISTRY_HANDLER_H_
