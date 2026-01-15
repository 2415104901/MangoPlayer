package com.example.mango_player.platform

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

class TextureRegistryHandler(
    private val textureRegistry: TextureRegistry
) : MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private val textures = mutableMapOf<Long, TextureRegistry.SurfaceTextureEntry>()

    fun startListening(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "com.mangoplayer/texture")
        channel?.setMethodCallHandler(this)
    }

    fun stopListening() {
        channel?.setMethodCallHandler(null)
        channel = null
        textures.values.forEach { it.release() }
        textures.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "registerTexture" -> {
                val entry = textureRegistry.createSurfaceTexture()
                textures[entry.id()] = entry
                result.success(mapOf("success" to true, "textureId" to entry.id()))
            }
            "unregisterTexture" -> {
                val textureId = call.argument<Int>("textureId")?.toLong()
                if (textureId != null) {
                    val entry = textures.remove(textureId)
                    entry?.release()
                    result.success(mapOf("success" to true))
                } else {
                    result.error("invalid_arguments", "textureId is null", null)
                }
            }
            else -> result.notImplemented()
        }
    }
    
    fun getTextureEntry(textureId: Long): TextureRegistry.SurfaceTextureEntry? {
        return textures[textureId]
    }
}
