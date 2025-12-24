package com.example.mango_player.platform

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.example.mango_player.ijkplayer.IJKPlayerManager

class MethodChannelHandler(
    private val messenger: BinaryMessenger,
    private val playerManager: IJKPlayerManager,
    private val textureRegistryHandler: TextureRegistryHandler
) : MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null

    fun startListening() {
        channel = MethodChannel(messenger, "com.mangoplayer/player")
        channel?.setMethodCallHandler(this)
    }

    fun stopListening() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val uri = call.argument<String>("uri")
                val type = call.argument<String>("type")
                val headers = call.argument<Map<String, String>>("headers")
                val textureId = call.argument<Int>("textureId")?.toLong()
                if (uri != null && type != null) {
                    playerManager.initialize(uri, type, headers, result, textureId)
                } else {
                    result.error("invalid_arguments", "uri or type is null", null)
                }
            }
            "play" -> {
                playerManager.play()
                result.success(mapOf("success" to true))
            }
            "pause" -> {
                playerManager.pause()
                result.success(mapOf("success" to true))
            }
            "stop" -> {
                playerManager.stop()
                result.success(mapOf("success" to true))
            }
            "seekTo" -> {
                val position = call.argument<Int>("position")
                if (position != null) {
                    playerManager.seekTo(position.toLong())
                    result.success(mapOf("success" to true, "actualPosition" to position)) // Actual position might differ
                } else {
                    result.error("invalid_arguments", "position is null", null)
                }
            }
            "setVolume" -> {
                val volume = call.argument<Double>("volume")
                if (volume != null) {
                    playerManager.setVolume(volume.toFloat())
                    result.success(mapOf("success" to true))
                } else {
                    result.error("invalid_arguments", "volume is null", null)
                }
            }
            "setPlaybackSpeed" -> {
                val speed = call.argument<Double>("speed")
                if (speed != null) {
                    playerManager.setPlaybackSpeed(speed.toFloat())
                    result.success(mapOf("success" to true))
                } else {
                    result.error("invalid_arguments", "speed is null", null)
                }
            }
            "getPosition" -> {
                val position = playerManager.getPosition()
                result.success(mapOf("success" to true, "position" to position))
            }
            "getDuration" -> {
                val duration = playerManager.getDuration()
                result.success(mapOf("success" to true, "duration" to duration))
            }
            "dispose" -> {
                playerManager.release()
                result.success(mapOf("success" to true))
            }
            else -> result.notImplemented()
        }
    }
}
