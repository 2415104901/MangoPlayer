package com.example.mango_player.decoder

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * 解码事件桥接器
 * 
 * 将 ijkplayer/MediaCodec 的解码事件桥接到 Dart 层。
 * 支持硬解/软解切换通知、解码器信息、性能指标等事件。
 * 
 * 任务: T108 [US6]
 */
class DecodeEventBridge : EventChannel.StreamHandler {
    
    companion object {
        private const val TAG = "DecodeEventBridge"
        
        // 事件类型
        const val EVENT_DECODER_CHANGED = "decoderChanged"
        const val EVENT_FALLBACK = "fallback"
        const val EVENT_PERFORMANCE = "performance"
        const val EVENT_ERROR = "error"
        const val EVENT_INFO = "info"
    }
    
    /**
     * 解码器信息事件
     */
    data class DecoderInfoEvent(
        val codecName: String,
        val codecType: String,  // "hardware" or "software"
        val mimeType: String?,
        val width: Int,
        val height: Int
    )
    
    /**
     * 降级事件
     */
    data class FallbackEvent(
        val fromCodec: String,
        val toCodec: String,
        val reason: String,
        val timestamp: Long
    )
    
    /**
     * 性能指标事件
     */
    data class PerformanceEvent(
        val decodeTimeMs: Long,
        val frameDropCount: Int,
        val bufferLevel: Int,
        val timestamp: Long
    )
    
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingEvents = ConcurrentLinkedQueue<Map<String, Any>>()
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        
        // 发送所有待发送的事件
        while (pendingEvents.isNotEmpty()) {
            pendingEvents.poll()?.let { event ->
                sendToFlutter(event)
            }
        }
    }
    
    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }
    
    /**
     * 发送解码器变更事件
     */
    fun sendDecoderChanged(info: DecoderInfoEvent) {
        val event = mapOf(
            "type" to EVENT_DECODER_CHANGED,
            "data" to mapOf(
                "codecName" to info.codecName,
                "codecType" to info.codecType,
                "mimeType" to (info.mimeType ?: ""),
                "width" to info.width,
                "height" to info.height,
                "timestamp" to System.currentTimeMillis()
            )
        )
        sendEvent(event)
    }
    
    /**
     * 发送降级事件
     */
    fun sendFallback(event: FallbackEvent) {
        val eventData = mapOf(
            "type" to EVENT_FALLBACK,
            "data" to mapOf(
                "fromCodec" to event.fromCodec,
                "toCodec" to event.toCodec,
                "reason" to event.reason,
                "timestamp" to event.timestamp
            )
        )
        sendEvent(eventData)
    }
    
    /**
     * 发送性能指标事件
     */
    fun sendPerformance(event: PerformanceEvent) {
        val eventData = mapOf(
            "type" to EVENT_PERFORMANCE,
            "data" to mapOf(
                "decodeTimeMs" to event.decodeTimeMs,
                "frameDropCount" to event.frameDropCount,
                "bufferLevel" to event.bufferLevel,
                "timestamp" to event.timestamp
            )
        )
        sendEvent(eventData)
    }
    
    /**
     * 发送错误事件
     */
    fun sendError(code: String, message: String, details: Map<String, Any>? = null) {
        val event = mapOf(
            "type" to EVENT_ERROR,
            "data" to mapOf(
                "code" to code,
                "message" to message,
                "details" to (details ?: emptyMap<String, Any>()),
                "timestamp" to System.currentTimeMillis()
            )
        )
        sendEvent(event)
    }
    
    /**
     * 发送信息事件
     */
    fun sendInfo(info: String, data: Map<String, Any>? = null) {
        val event = mapOf(
            "type" to EVENT_INFO,
            "data" to mapOf(
                "info" to info,
                "data" to (data ?: emptyMap<String, Any>()),
                "timestamp" to System.currentTimeMillis()
            )
        )
        sendEvent(event)
    }
    
    /**
     * 根据 ijkplayer 的解码器标志判断解码器类型
     */
    fun parseIjkDecoderType(flags: Int): String {
        // ijkplayer 解码器标志位
        // AVCODEC_HW_DECODER = 0x01
        return if ((flags and 0x01) != 0) "hardware" else "software"
    }
    
    /**
     * 从 ijkplayer 的 onInfo 回调解析解码器信息
     * 
     * @param what 信息类型
     * @param extra 额外信息
     */
    fun handleIjkInfo(what: Int, extra: Int) {
        when (what) {
            // MEDIA_INFO_VIDEO_DECODED_START = 10001
            10001 -> {
                sendInfo("video_decode_started", mapOf("extra" to extra))
            }
            // MEDIA_INFO_AUDIO_DECODED_START = 10002
            10002 -> {
                sendInfo("audio_decode_started", mapOf("extra" to extra))
            }
            // MEDIA_INFO_VIDEO_RENDERING_START = 3
            3 -> {
                sendInfo("video_rendering_started", mapOf("extra" to extra))
            }
            // 自定义: 解码器切换
            65536 -> {
                val codecType = parseIjkDecoderType(extra)
                sendInfo("decoder_type", mapOf("type" to codecType))
            }
        }
    }
    
    /**
     * 发送事件到 Flutter
     */
    private fun sendEvent(event: Map<String, Any>) {
        if (eventSink != null) {
            sendToFlutter(event)
        } else {
            // 缓存事件，等待监听器连接
            pendingEvents.offer(event)
        }
    }
    
    private fun sendToFlutter(event: Map<String, Any>) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            eventSink?.success(event)
        } else {
            mainHandler.post {
                eventSink?.success(event)
            }
        }
    }
    
    /**
     * 清理资源
     */
    fun dispose() {
        eventSink = null
        pendingEvents.clear()
    }
}
