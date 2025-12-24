package com.example.mango_player.providers

import android.content.Context
import android.os.Build
import tv.danmaku.ijk.media.player.IjkMediaPlayer

/**
 * Android 解码器提供者实现
 * 
 * 实现 DecoderProvider 接口，负责配置和监控 ijkplayer 的解码器设置。
 * 支持硬件解码（MediaCodec）和软件解码之间的切换。
 */
class AndroidDecoderProvider(private val context: Context) {
    
    companion object {
        private const val TAG = "AndroidDecoderProvider"
        
        // ijkplayer 选项
        const val MEDIACODEC = "mediacodec"
        const val MEDIACODEC_AUTO_ROTATE = "mediacodec-auto-rotate"
        const val MEDIACODEC_HANDLE_RESOLUTION_CHANGE = "mediacodec-handle-resolution-change"
        const val OPENSLES = "opensles"
        const val FRAMEDROP = "framedrop"
    }
    
    /**
     * 解码器类型
     */
    enum class DecoderType {
        HARDWARE,   // 硬件解码 (MediaCodec)
        SOFTWARE,   // 软件解码 (FFmpeg)
        AUTO        // 自动选择
    }
    
    /**
     * 解码器配置
     */
    data class DecoderConfig(
        val preferHardware: Boolean = true,
        val enableAutoRotate: Boolean = true,
        val handleResolutionChange: Boolean = true,
        val enableOpenSLES: Boolean = false,
        val frameDrop: Int = 1
    )
    
    /**
     * 解码器状态
     */
    data class DecoderStatus(
        val type: DecoderType,
        val codecName: String?,
        val isHardwareAccelerated: Boolean,
        val fallbackReason: String? = null
    )
    
    private var currentStatus: DecoderStatus = DecoderStatus(
        type = DecoderType.AUTO,
        codecName = null,
        isHardwareAccelerated = false
    )
    
    private var statusListener: ((DecoderStatus) -> Unit)? = null
    
    /**
     * 配置解码器
     * 
     * @param player ijkplayer 实例
     * @param config 解码器配置
     */
    fun configure(player: IjkMediaPlayer, config: DecoderConfig) {
        // 硬件解码配置
        val useHardware = if (config.preferHardware) 1L else 0L
        player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, MEDIACODEC, useHardware)
        player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, MEDIACODEC_AUTO_ROTATE, 
            if (config.enableAutoRotate) 1L else 0L)
        player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, MEDIACODEC_HANDLE_RESOLUTION_CHANGE, 
            if (config.handleResolutionChange) 1L else 0L)
        
        // 音频配置
        player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, OPENSLES, 
            if (config.enableOpenSLES) 1L else 0L)
        
        // 丢帧配置
        player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, FRAMEDROP, config.frameDrop.toLong())
        
        // 更新状态
        currentStatus = DecoderStatus(
            type = if (config.preferHardware) DecoderType.HARDWARE else DecoderType.SOFTWARE,
            codecName = null,
            isHardwareAccelerated = config.preferHardware
        )
    }
    
    /**
     * 检查设备是否支持硬件解码
     */
    fun isHardwareDecodingSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN
    }
    
    /**
     * 检查特定编解码器是否支持硬件解码
     */
    fun isCodecHardwareAccelerated(mimeType: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                val codecList = android.media.MediaCodecList(android.media.MediaCodecList.ALL_CODECS)
                for (codecInfo in codecList.codecInfos) {
                    if (codecInfo.isEncoder) continue
                    for (type in codecInfo.supportedTypes) {
                        if (type.equals(mimeType, ignoreCase = true)) {
                            // 硬件编解码器通常不包含 "OMX.google" 前缀
                            if (!codecInfo.name.startsWith("OMX.google")) {
                                return true
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                // 忽略异常
            }
        }
        return false
    }
    
    /**
     * 处理解码器降级事件
     */
    fun onDecoderFallback(reason: String) {
        currentStatus = currentStatus.copy(
            type = DecoderType.SOFTWARE,
            isHardwareAccelerated = false,
            fallbackReason = reason
        )
        statusListener?.invoke(currentStatus)
    }
    
    /**
     * 设置解码器状态监听器
     */
    fun setStatusListener(listener: ((DecoderStatus) -> Unit)?) {
        this.statusListener = listener
    }
    
    /**
     * 获取当前解码器状态
     */
    fun getStatus(): DecoderStatus = currentStatus
    
    /**
     * 获取推荐的解码配置
     */
    fun getRecommendedConfig(): DecoderConfig {
        return DecoderConfig(
            preferHardware = isHardwareDecodingSupported(),
            enableAutoRotate = true,
            handleResolutionChange = true,
            enableOpenSLES = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP,
            frameDrop = 1
        )
    }
}
