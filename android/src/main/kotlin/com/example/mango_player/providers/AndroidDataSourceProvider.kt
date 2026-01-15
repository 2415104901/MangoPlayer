package com.example.mango_player.providers

import android.content.Context
import android.net.Uri
import tv.danmaku.ijk.media.player.IMediaPlayer

/**
 * Android 数据源提供者实现
 * 
 * 实现 DataSourceProvider 接口，负责管理媒体数据源的加载和配置。
 * 支持网络资源、本地文件和 Flutter Asset。
 */
class AndroidDataSourceProvider(private val context: Context) {
    
    companion object {
        private const val TAG = "AndroidDataSourceProvider"
        
        // 支持的协议
        private val SUPPORTED_SCHEMES = setOf(
            "http", "https", "rtmp", "rtmps", "rtsp", "file", "asset"
        )
    }
    
    /**
     * 数据源类型
     */
    enum class SourceType {
        NETWORK,
        FILE,
        ASSET
    }
    
    /**
     * 数据源信息
     */
    data class DataSourceInfo(
        val uri: String,
        val type: SourceType,
        val headers: Map<String, String>? = null,
        val mimeType: String? = null
    )
    
    /**
     * 检查 URI 是否受支持
     */
    fun isSupported(uri: String): Boolean {
        return try {
            val parsedUri = Uri.parse(uri)
            val scheme = parsedUri.scheme?.lowercase() ?: "file"
            SUPPORTED_SCHEMES.contains(scheme)
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 解析数据源类型
     */
    fun parseSourceType(uri: String): SourceType {
        val parsedUri = Uri.parse(uri)
        return when (parsedUri.scheme?.lowercase()) {
            "http", "https", "rtmp", "rtmps", "rtsp" -> SourceType.NETWORK
            "asset" -> SourceType.ASSET
            else -> SourceType.FILE
        }
    }
    
    /**
     * 配置播放器数据源
     * 
     * @param player ijkplayer 实例
     * @param info 数据源信息
     */
    fun setDataSource(player: IMediaPlayer, info: DataSourceInfo) {
        when (info.type) {
            SourceType.NETWORK -> setNetworkSource(player, info)
            SourceType.FILE -> setFileSource(player, info)
            SourceType.ASSET -> setAssetSource(player, info)
        }
    }
    
    private fun setNetworkSource(player: IMediaPlayer, info: DataSourceInfo) {
        if (info.headers.isNullOrEmpty()) {
            player.dataSource = info.uri
        } else {
            // 构建 headers 字符串
            val headersStr = info.headers.entries.joinToString("\r\n") { 
                "${it.key}: ${it.value}" 
            }
            player.setOption(tv.danmaku.ijk.media.player.IjkMediaPlayer.OPT_CATEGORY_FORMAT, 
                "headers", headersStr)
            player.dataSource = info.uri
        }
    }
    
    private fun setFileSource(player: IMediaPlayer, info: DataSourceInfo) {
        val uri = info.uri
        val path = if (uri.startsWith("file://")) {
            uri.removePrefix("file://")
        } else {
            uri
        }
        player.dataSource = path
    }
    
    private fun setAssetSource(player: IMediaPlayer, info: DataSourceInfo) {
        // Flutter asset 路径格式: asset://flutter_assets/path/to/file.mp4
        val assetPath = info.uri.removePrefix("asset://")
        val fd = context.assets.openFd(assetPath)
        player.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
        fd.close()
    }
    
    /**
     * 获取数据源的 MIME 类型
     */
    fun getMimeType(uri: String): String? {
        val extension = uri.substringAfterLast('.', "").lowercase()
        return when (extension) {
            "mp4", "m4v" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "avi" -> "video/x-msvideo"
            "mov" -> "video/quicktime"
            "webm" -> "video/webm"
            "flv" -> "video/x-flv"
            "ts", "m2ts" -> "video/mp2t"
            "3gp" -> "video/3gpp"
            "m3u8" -> "application/x-mpegURL"
            "mp3" -> "audio/mpeg"
            "aac", "m4a" -> "audio/aac"
            "flac" -> "audio/flac"
            "wav" -> "audio/wav"
            "ogg" -> "audio/ogg"
            else -> null
        }
    }
}
