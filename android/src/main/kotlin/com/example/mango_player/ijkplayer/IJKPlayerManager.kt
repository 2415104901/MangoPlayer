package com.example.mango_player.ijkplayer

import android.content.Context
import android.view.Surface
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.example.mango_player.platform.TextureRegistryHandler

class IJKPlayerManager(private val context: Context) {
    private val playerWrapper = IJKPlayerWrapper(context)
    private var eventSink: EventChannel.EventSink? = null
    private var textureRegistryHandler: TextureRegistryHandler? = null
    
    init {
        playerWrapper.initialize()
        setupListeners()
    }
    
    fun setTextureRegistryHandler(handler: TextureRegistryHandler) {
        this.textureRegistryHandler = handler
    }

    private fun setupListeners() {
        val mediaPlayer = playerWrapper.getMediaPlayer()
        mediaPlayer?.setOnPreparedListener { 
            eventSink?.success(mapOf("type" to "state", "state" to "ready"))
            eventSink?.success(mapOf("type" to "progress", "duration" to playerWrapper.getDuration()))
        }
        mediaPlayer?.setOnCompletionListener {
            eventSink?.success(mapOf("type" to "state", "state" to "completed"))
            eventSink?.success(mapOf("type" to "completed"))
        }
        mediaPlayer?.setOnErrorListener { _, what, extra ->
            eventSink?.success(mapOf("type" to "error", "code" to "unknown", "message" to "IJK Error: $what, $extra"))
            true
        }
        mediaPlayer?.setOnBufferingUpdateListener { _, percent ->
             eventSink?.success(mapOf("type" to "buffering", "bufferPercentage" to percent / 100.0))
        }
    }

    fun initialize(uri: String, type: String, headers: Map<String, String>?, result: MethodChannel.Result, textureId: Long?) {
        try {
            if (textureId != null && textureRegistryHandler != null) {
                val entry = textureRegistryHandler!!.getTextureEntry(textureId)
                if (entry != null) {
                    val surface = Surface(entry.surfaceTexture())
                    playerWrapper.setSurface(surface)
                }
            }
            
            playerWrapper.setDataSource(uri, headers)
            playerWrapper.prepareAsync()
            eventSink?.success(mapOf("type" to "state", "state" to "initializing"))
            result.success(mapOf("success" to true, "duration" to 0))
        } catch (e: Exception) {
            result.error("initialization_error", e.message, null)
        }
    }

    fun play() {
        playerWrapper.start()
        eventSink?.success(mapOf("type" to "state", "state" to "playing"))
    }

    fun pause() {
        playerWrapper.pause()
        eventSink?.success(mapOf("type" to "state", "state" to "paused"))
    }

    fun stop() {
        playerWrapper.stop()
        eventSink?.success(mapOf("type" to "state", "state" to "idle"))
    }

    fun seekTo(position: Long) {
        playerWrapper.seekTo(position)
    }

    fun setVolume(volume: Float) {
        playerWrapper.setVolume(volume)
    }

    fun setPlaybackSpeed(speed: Float) {
        playerWrapper.setSpeed(speed)
    }

    fun getPosition(): Long {
        return playerWrapper.getCurrentPosition()
    }

    fun getDuration(): Long {
        return playerWrapper.getDuration()
    }

    fun release() {
        playerWrapper.release()
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }
}
