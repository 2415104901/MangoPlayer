package com.example.mango_player.platform

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import com.example.mango_player.ijkplayer.IJKPlayerManager

class EventChannelHandler(
    private val messenger: BinaryMessenger,
    private val playerManager: IJKPlayerManager
) : EventChannel.StreamHandler {

    private var channel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    fun startListening() {
        channel = EventChannel(messenger, "com.mangoplayer/events")
        channel?.setStreamHandler(this)
        playerManager.setEventSink(eventSink)
    }

    fun stopListening() {
        channel?.setStreamHandler(null)
        channel = null
        eventSink = null
        playerManager.setEventSink(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        playerManager.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        playerManager.setEventSink(null)
    }
}
