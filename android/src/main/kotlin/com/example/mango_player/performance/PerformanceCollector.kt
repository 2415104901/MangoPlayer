package com.example.mango_player.performance

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import tv.danmaku.ijk.media.player.IMediaPlayer
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * Android 性能数据收集器
 *
 * 收集 ijkplayer 播放过程中的性能指标，包括：
 * - 帧率 (FPS)
 * - 丢帧数
 * - 解码耗时
 * - 缓冲区状态
 */
class PerformanceCollector {
    
    private var mediaPlayer: IMediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private val isCollecting = AtomicBoolean(false)
    
    // 帧率计算
    private var frameCount = AtomicLong(0)
    private var lastFrameTime = AtomicLong(0)
    private var lastFpsCalcTime = AtomicLong(0)
    private var currentFps = 0.0
    
    // 丢帧统计
    private var droppedFrames = AtomicLong(0)
    private var decodedFrames = AtomicLong(0)
    
    // 解码耗时
    private var videoDecodeTimeMs = 0.0
    private var audioDecodeTimeMs = 0.0
    private var renderTimeMs = 0.0
    
    // 采样配置
    private var sampleIntervalMs = 1000L
    private var collectBandwidth = true
    private var collectBitrate = true
    
    // 回调
    private var callback: PerformanceCallback? = null
    
    /**
     * 绑定播放器
     */
    fun attach(player: IMediaPlayer) {
        mediaPlayer = player
    }
    
    /**
     * 解绑播放器
     */
    fun detach() {
        stop()
        mediaPlayer = null
    }
    
    /**
     * 设置性能回调
     */
    fun setCallback(callback: PerformanceCallback?) {
        this.callback = callback
    }
    
    /**
     * 配置采样参数
     */
    fun configure(
        sampleIntervalMs: Long = 1000,
        collectBandwidth: Boolean = true,
        collectBitrate: Boolean = true
    ) {
        this.sampleIntervalMs = sampleIntervalMs
        this.collectBandwidth = collectBandwidth
        this.collectBitrate = collectBitrate
    }
    
    /**
     * 开始收集
     */
    fun start() {
        if (isCollecting.getAndSet(true)) return
        
        lastFpsCalcTime.set(SystemClock.elapsedRealtime())
        frameCount.set(0)
        
        scheduleCollection()
    }
    
    /**
     * 停止收集
     */
    fun stop() {
        isCollecting.set(false)
        handler.removeCallbacksAndMessages(null)
    }
    
    /**
     * 记录一帧
     */
    fun onFrameRendered() {
        frameCount.incrementAndGet()
        lastFrameTime.set(SystemClock.elapsedRealtime())
    }
    
    /**
     * 记录丢帧
     */
    fun onFrameDropped() {
        droppedFrames.incrementAndGet()
    }
    
    /**
     * 记录解码完成
     */
    fun onFrameDecoded(videoTimeMs: Double, audioTimeMs: Double) {
        decodedFrames.incrementAndGet()
        videoDecodeTimeMs = videoTimeMs
        audioDecodeTimeMs = audioTimeMs
    }
    
    /**
     * 记录渲染耗时
     */
    fun onRenderComplete(timeMs: Double) {
        renderTimeMs = timeMs
    }
    
    /**
     * 获取当前性能指标
     */
    fun getMetrics(): PerformanceMetrics {
        val player = mediaPlayer
        
        // 计算帧率
        val now = SystemClock.elapsedRealtime()
        val elapsed = now - lastFpsCalcTime.get()
        if (elapsed > 0) {
            currentFps = frameCount.get() * 1000.0 / elapsed
        }
        
        // 从 ijkplayer 获取额外信息
        var bufferLengthMs = 0
        var videoBitrate: Int? = null
        var audioBitrate: Int? = null
        var width: Int? = null
        var height: Int? = null
        var isHardwareDecoding = false
        var bandwidthBps: Int? = null
        
        player?.let { p ->
            try {
                // 尝试获取视频信息
                width = p.videoWidth
                height = p.videoHeight
                
                // ijkplayer 特定信息获取
                if (p is tv.danmaku.ijk.media.player.IjkMediaPlayer) {
                    // 获取缓冲区信息
                    val videoCachedDuration = p.videoCachedDuration
                    val audioCachedDuration = p.audioCachedDuration
                    bufferLengthMs = maxOf(videoCachedDuration, audioCachedDuration).toInt()
                    
                    // 获取解码器信息
                    val videoDecoder = p.videoDecoder
                    isHardwareDecoding = videoDecoder?.contains("mediacodec", ignoreCase = true) == true
                    
                    // 获取码率信息
                    if (collectBitrate) {
                        videoBitrate = p.tcpSpeed.toInt()
                    }
                    
                    // 获取带宽估计
                    if (collectBandwidth) {
                        bandwidthBps = p.tcpSpeed.toInt()
                    }
                }
            } catch (e: Exception) {
                // 忽略获取信息时的错误
            }
        }
        
        return PerformanceMetrics(
            frameRate = currentFps,
            droppedFrames = droppedFrames.get().toInt(),
            decodedFrames = decodedFrames.get().toInt(),
            videoDecodeTimeMs = videoDecodeTimeMs,
            audioDecodeTimeMs = audioDecodeTimeMs,
            renderTimeMs = renderTimeMs,
            bufferLengthMs = bufferLengthMs,
            bandwidthBps = bandwidthBps,
            isHardwareDecoding = isHardwareDecoding,
            videoBitrate = videoBitrate,
            audioBitrate = audioBitrate,
            width = width,
            height = height
        )
    }
    
    /**
     * 转换为 Map（用于 Platform Channel）
     */
    fun getMetricsMap(): Map<String, Any?> {
        return getMetrics().toMap()
    }
    
    private fun scheduleCollection() {
        if (!isCollecting.get()) return
        
        handler.postDelayed({
            if (isCollecting.get()) {
                val metrics = getMetrics()
                callback?.onPerformanceUpdate(metrics)
                
                // 重置帧计数
                frameCount.set(0)
                lastFpsCalcTime.set(SystemClock.elapsedRealtime())
                
                scheduleCollection()
            }
        }, sampleIntervalMs)
    }
    
    /**
     * 性能回调接口
     */
    interface PerformanceCallback {
        fun onPerformanceUpdate(metrics: PerformanceMetrics)
    }
}

/**
 * 性能指标数据类
 */
data class PerformanceMetrics(
    val frameRate: Double,
    val droppedFrames: Int,
    val decodedFrames: Int,
    val videoDecodeTimeMs: Double,
    val audioDecodeTimeMs: Double,
    val renderTimeMs: Double,
    val bufferLengthMs: Int,
    val bandwidthBps: Int?,
    val isHardwareDecoding: Boolean,
    val videoBitrate: Int?,
    val audioBitrate: Int?,
    val width: Int?,
    val height: Int?
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "frameRate" to frameRate,
            "droppedFrames" to droppedFrames,
            "decodedFrames" to decodedFrames,
            "videoDecodeTimeMs" to videoDecodeTimeMs,
            "audioDecodeTimeMs" to audioDecodeTimeMs,
            "renderTimeMs" to renderTimeMs,
            "bufferLengthMs" to bufferLengthMs,
            "bandwidthBps" to bandwidthBps,
            "isHardwareDecoding" to isHardwareDecoding,
            "videoBitrate" to videoBitrate,
            "audioBitrate" to audioBitrate,
            "width" to width,
            "height" to height
        )
    }
}
