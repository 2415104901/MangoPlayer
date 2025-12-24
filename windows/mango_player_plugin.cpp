// MangoPlayer Windows Plugin
// Flutter Plugin Entry Point

#include "mango_player_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

#include "src/platform/method_channel_handler.h"
#include "src/platform/event_channel_handler.h"
#include "src/platform/texture_registry_handler.h"
#include "src/core/ffmpeg_player_manager.h"

namespace mango_player {

// static
void MangoPlayerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<MangoPlayerPlugin>();
  plugin->Setup(registrar);
  registrar->AddPlugin(std::move(plugin));
}

MangoPlayerPlugin::MangoPlayerPlugin() {}

MangoPlayerPlugin::~MangoPlayerPlugin() {
  Cleanup();
}

void MangoPlayerPlugin::Setup(flutter::PluginRegistrarWindows* registrar) {
  // Create player manager
  player_manager_ = std::make_shared<FFmpegPlayerManager>();

  // Create texture registry handler
  texture_handler_ = std::make_shared<TextureRegistryHandler>(registrar->texture_registrar());
  texture_handler_->StartListening(registrar->messenger());

  // Create method channel handler
  method_handler_ = std::make_shared<MethodChannelHandler>(
      registrar->messenger(), player_manager_, texture_handler_);
  method_handler_->StartListening();

  // Create event channel handler
  event_handler_ = std::make_shared<EventChannelHandler>(
      registrar->messenger(), player_manager_);
  event_handler_->StartListening();

  // Set up event callbacks from player manager to event channel
  player_manager_->SetEventCallback(
      [this](const std::string& type, int64_t position, int64_t duration,
             int64_t buffered, double buffer_pct) {
        if (event_handler_) {
          event_handler_->SendProgressEvent(position, duration, buffered, buffer_pct);
        }
      },
      [this](const std::string& state) {
        if (event_handler_) {
          event_handler_->SendStateEvent(state);
        }
      });
}

void MangoPlayerPlugin::Cleanup() {
  if (method_handler_) {
    method_handler_->StopListening();
    method_handler_.reset();
  }

  if (event_handler_) {
    event_handler_->StopListening();
    event_handler_.reset();
  }

  if (texture_handler_) {
    texture_handler_->StopListening();
    texture_handler_.reset();
  }

  if (player_manager_) {
    player_manager_->Release();
    player_manager_.reset();
  }
}

}  // namespace mango_player
