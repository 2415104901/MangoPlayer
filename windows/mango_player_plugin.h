// MangoPlayer Windows Plugin Header

#ifndef FLUTTER_PLUGIN_MANGO_PLAYER_PLUGIN_H_
#define FLUTTER_PLUGIN_MANGO_PLAYER_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace mango_player {

class MethodChannelHandler;
class EventChannelHandler;
class TextureRegistryHandler;
class FFmpegPlayerManager;

class MangoPlayerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MangoPlayerPlugin();
  virtual ~MangoPlayerPlugin();

  // Disallow copy and assign.
  MangoPlayerPlugin(const MangoPlayerPlugin&) = delete;
  MangoPlayerPlugin& operator=(const MangoPlayerPlugin&) = delete;

 private:
  void Setup(flutter::PluginRegistrarWindows* registrar);
  void Cleanup();

  std::shared_ptr<FFmpegPlayerManager> player_manager_;
  std::shared_ptr<MethodChannelHandler> method_handler_;
  std::shared_ptr<EventChannelHandler> event_handler_;
  std::shared_ptr<TextureRegistryHandler> texture_handler_;
};

}  // namespace mango_player

#endif  // FLUTTER_PLUGIN_MANGO_PLAYER_PLUGIN_H_
