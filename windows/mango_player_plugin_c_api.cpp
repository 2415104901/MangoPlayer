#include "include/mango_player/mango_player_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "mango_player_plugin.h"

void MangoPlayerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  mango_player::MangoPlayerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
