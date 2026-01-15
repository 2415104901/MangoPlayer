package com.example.mango_player

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import com.example.mango_player.platform.MethodChannelHandler
import com.example.mango_player.platform.EventChannelHandler
import com.example.mango_player.platform.TextureRegistryHandler
import com.example.mango_player.ijkplayer.IJKPlayerManager

class MangoPlayerPlugin: FlutterPlugin {
  private lateinit var methodChannelHandler: MethodChannelHandler
  private lateinit var eventChannelHandler: EventChannelHandler
  private lateinit var textureRegistryHandler: TextureRegistryHandler
  private lateinit var playerManager: IJKPlayerManager

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    playerManager = IJKPlayerManager(flutterPluginBinding.applicationContext)
    
    textureRegistryHandler = TextureRegistryHandler(flutterPluginBinding.textureRegistry)
    playerManager.setTextureRegistryHandler(textureRegistryHandler)
    
    methodChannelHandler = MethodChannelHandler(flutterPluginBinding.binaryMessenger, playerManager, textureRegistryHandler)
    eventChannelHandler = EventChannelHandler(flutterPluginBinding.binaryMessenger, playerManager)
    
    methodChannelHandler.startListening()
    eventChannelHandler.startListening()
    textureRegistryHandler.startListening(flutterPluginBinding.binaryMessenger)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannelHandler.stopListening()
    eventChannelHandler.stopListening()
    textureRegistryHandler.stopListening()
    playerManager.release()
  }
}
