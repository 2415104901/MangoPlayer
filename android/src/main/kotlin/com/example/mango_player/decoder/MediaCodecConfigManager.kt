package com.example.mango_player.decoder

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.os.Build
import tv.danmaku.ijk.media.player.IjkMediaPlayer

/**
 * MediaCodec 配置管理器
 * 
 * 负责配置 ijkplayer 的硬件解码选项，监听解码器降级事件，
 * 并提供解码器能力查询接口。
 * 
 * 任务: T107 [US6]
 */
class MediaCodecConfigManager(private val context: Context) {
    
    companion object {
        private const val TAG = "MediaCodecConfigManager"
        
        // 支持的视频编码格式
        private val SUPPORTED_VIDEO_CODECS = mapOf(
            "video/avc" to "H.264/AVC",
            "video/hevc" to "H.265/HEVC",
            "video/x-vnd.on2.vp8" to "VP8",
            "video/x-vnd.on2.vp9" to "VP9",
            "video/av01" to "AV1"
        )
        
        // ijkplayer 解码器选项
        const val OPT_MEDIACODEC = "mediacodec"
        const val OPT_MEDIACODEC_HEVC = "mediacodec-hevc"
        const val OPT_MEDIACODEC_MPEG2 = "mediacodec-mpeg2"
        const val OPT_MEDIACODEC_MPEG4 = "mediacodec-mpeg4"
        const val OPT_MEDIACODEC_AUTO_ROTATE = "mediacodec-auto-rotate"
        const val OPT_MEDIACODEC_HANDLE_RESOLUTION = "mediacodec-handle-resolution-change"
    }
    
    /**
     * 硬件解码器能力信息
     */
    data class HardwareDecoderCapability(
        val codecName: String,
        val mimeType: String,
        val displayName: String,
        val isHardwareAccelerated: Boolean,
        val maxWidth: Int,
        val maxHeight: Int,
        val supportedProfiles: List<String>
    )
    
    /**
     * 解码配置
     */
    data class DecoderConfiguration(
        val enableHardwareDecode: Boolean = true,
        val enableHEVC: Boolean = true,
        val enableAutoRotate: Boolean = true,
        val handleResolutionChange: Boolean = true,
        val preferredCodecs: List<String> = emptyList()
    )
    
    /**
     * 降级事件
     */
    data class FallbackEvent(
        val fromCodec: String,
        val toCodec: String,
        val reason: FallbackReason,
        val timestamp: Long = System.currentTimeMillis()
    )
    
    enum class FallbackReason {
        CODEC_NOT_SUPPORTED,
        RESOLUTION_TOO_HIGH,
        DECODE_ERROR,
        TIMEOUT,
        UNKNOWN
    }
    
    private var configuration = DecoderConfiguration()
    private val fallbackHistory = mutableListOf<FallbackEvent>()
    private var fallbackListener: ((FallbackEvent) -> Unit)? = null
    
    /**
     * 获取设备支持的硬件解码器列表
     */
    fun getAvailableHardwareDecoders(): List<HardwareDecoderCapability> {
        val decoders = mutableListOf<HardwareDecoderCapability>()
        
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return decoders
        }
        
        try {
            val codecList = MediaCodecList(MediaCodecList.ALL_CODECS)
            
            for (codecInfo in codecList.codecInfos) {
                if (codecInfo.isEncoder) continue
                
                val isHardware = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    codecInfo.isHardwareAccelerated
                } else {
                    !codecInfo.name.contains("OMX.google", ignoreCase = true)
                }
                
                for (type in codecInfo.supportedTypes) {
                    val displayName = SUPPORTED_VIDEO_CODECS[type] ?: continue
                    
                    try {
                        val capabilities = codecInfo.getCapabilitiesForType(type)
                        val videoCapabilities = capabilities.videoCapabilities
                        
                        decoders.add(HardwareDecoderCapability(
                            codecName = codecInfo.name,
                            mimeType = type,
                            displayName = displayName,
                            isHardwareAccelerated = isHardware,
                            maxWidth = videoCapabilities?.supportedWidths?.upper ?: 1920,
                            maxHeight = videoCapabilities?.supportedHeights?.upper ?: 1080,
                            supportedProfiles = getProfileNames(capabilities.profileLevels, type)
                        ))
                    } catch (e: Exception) {
                        // 某些解码器可能无法获取能力信息
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to enumerate hardware decoders", e)
        }
        
        return decoders
    }
    
    /**
     * 应用解码器配置到 ijkplayer
     */
    fun applyConfiguration(player: IjkMediaPlayer, config: DecoderConfiguration) {
        this.configuration = config
        
        // 主硬件解码开关
        player.setOption(
            IjkMediaPlayer.OPT_CATEGORY_PLAYER,
            OPT_MEDIACODEC,
            if (config.enableHardwareDecode) 1L else 0L
        )
        
        // HEVC/H.265 支持
        player.setOption(
            IjkMediaPlayer.OPT_CATEGORY_PLAYER,
            OPT_MEDIACODEC_HEVC,
            if (config.enableHEVC && config.enableHardwareDecode) 1L else 0L
        )
        
        // 自动旋转
        player.setOption(
            IjkMediaPlayer.OPT_CATEGORY_PLAYER,
            OPT_MEDIACODEC_AUTO_ROTATE,
            if (config.enableAutoRotate) 1L else 0L
        )
        
        // 分辨率变化处理
        player.setOption(
            IjkMediaPlayer.OPT_CATEGORY_PLAYER,
            OPT_MEDIACODEC_HANDLE_RESOLUTION,
            if (config.handleResolutionChange) 1L else 0L
        )
    }
    
    /**
     * 检查是否支持指定分辨率的硬件解码
     */
    fun supportsResolution(width: Int, height: Int, mimeType: String = "video/avc"): Boolean {
        val decoders = getAvailableHardwareDecoders()
        return decoders.any { decoder ->
            decoder.mimeType == mimeType &&
            decoder.isHardwareAccelerated &&
            decoder.maxWidth >= width &&
            decoder.maxHeight >= height
        }
    }
    
    /**
     * 记录降级事件
     */
    fun recordFallback(fromCodec: String, toCodec: String, reason: FallbackReason) {
        val event = FallbackEvent(fromCodec, toCodec, reason)
        fallbackHistory.add(event)
        fallbackListener?.invoke(event)
    }
    
    /**
     * 设置降级事件监听器
     */
    fun setFallbackListener(listener: ((FallbackEvent) -> Unit)?) {
        this.fallbackListener = listener
    }
    
    /**
     * 获取降级历史
     */
    fun getFallbackHistory(): List<FallbackEvent> = fallbackHistory.toList()
    
    /**
     * 清除降级历史
     */
    fun clearFallbackHistory() {
        fallbackHistory.clear()
    }
    
    /**
     * 获取当前配置
     */
    fun getCurrentConfiguration(): DecoderConfiguration = configuration
    
    /**
     * 获取推荐的解码配置
     */
    fun getRecommendedConfiguration(width: Int, height: Int): DecoderConfiguration {
        val supportsHardware = supportsResolution(width, height)
        val supportsHEVC = supportsResolution(width, height, "video/hevc")
        
        return DecoderConfiguration(
            enableHardwareDecode = supportsHardware,
            enableHEVC = supportsHEVC,
            enableAutoRotate = true,
            handleResolutionChange = true
        )
    }
    
    private fun getProfileNames(
        profileLevels: Array<MediaCodecInfo.CodecProfileLevel>?,
        mimeType: String
    ): List<String> {
        if (profileLevels == null) return emptyList()
        
        return profileLevels.mapNotNull { pl ->
            when (mimeType) {
                "video/avc" -> avcProfileToString(pl.profile)
                "video/hevc" -> hevcProfileToString(pl.profile)
                else -> null
            }
        }.distinct()
    }
    
    private fun avcProfileToString(profile: Int): String? {
        return when (profile) {
            MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline -> "Baseline"
            MediaCodecInfo.CodecProfileLevel.AVCProfileMain -> "Main"
            MediaCodecInfo.CodecProfileLevel.AVCProfileExtended -> "Extended"
            MediaCodecInfo.CodecProfileLevel.AVCProfileHigh -> "High"
            MediaCodecInfo.CodecProfileLevel.AVCProfileHigh10 -> "High 10"
            MediaCodecInfo.CodecProfileLevel.AVCProfileHigh422 -> "High 4:2:2"
            MediaCodecInfo.CodecProfileLevel.AVCProfileHigh444 -> "High 4:4:4"
            else -> null
        }
    }
    
    private fun hevcProfileToString(profile: Int): String? {
        return when (profile) {
            MediaCodecInfo.CodecProfileLevel.HEVCProfileMain -> "Main"
            MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10 -> "Main 10"
            MediaCodecInfo.CodecProfileLevel.HEVCProfileMainStill -> "Main Still"
            else -> null
        }
    }
}
