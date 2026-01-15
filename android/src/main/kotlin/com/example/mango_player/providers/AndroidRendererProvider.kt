package com.example.mango_player.providers

import android.graphics.SurfaceTexture
import android.view.Surface
import io.flutter.view.TextureRegistry

/**
 * Android 渲染器提供者实现
 * 
 * 实现 RendererProvider 接口，负责管理 Flutter External Texture 渲染。
 * 实现零拷贝渲染，将 ijkplayer 输出直接渲染到 Flutter SurfaceTexture。
 */
class AndroidRendererProvider {
    
    companion object {
        private const val TAG = "AndroidRendererProvider"
    }
    
    /**
     * 渲染器类型
     */
    enum class RendererType {
        SURFACE_TEXTURE,    // SurfaceTexture 渲染 (默认)
        SURFACE_VIEW,       // SurfaceView 渲染 (备用)
    }
    
    /**
     * 渲染器配置
     */
    data class RendererConfig(
        val type: RendererType = RendererType.SURFACE_TEXTURE,
        val enableVSync: Boolean = true
    )
    
    /**
     * 渲染状态
     */
    data class RendererStatus(
        val textureId: Long?,
        val isActive: Boolean,
        val width: Int,
        val height: Int
    )
    
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var surface: Surface? = null
    private var currentStatus: RendererStatus = RendererStatus(
        textureId = null,
        isActive = false,
        width = 0,
        height = 0
    )
    
    private var statusListener: ((RendererStatus) -> Unit)? = null
    
    /**
     * 创建渲染表面
     * 
     * @param textureRegistry Flutter TextureRegistry
     * @return Texture ID
     */
    fun createSurface(textureRegistry: TextureRegistry): Long {
        // 创建 SurfaceTexture
        textureEntry = textureRegistry.createSurfaceTexture()
        val surfaceTexture = textureEntry?.surfaceTexture()
            ?: throw IllegalStateException("Failed to create SurfaceTexture")
        
        // 创建 Surface
        surface = Surface(surfaceTexture)
        
        val textureId = textureEntry?.id() ?: -1L
        
        // 更新状态
        currentStatus = RendererStatus(
            textureId = textureId,
            isActive = true,
            width = 0,
            height = 0
        )
        statusListener?.invoke(currentStatus)
        
        return textureId
    }
    
    /**
     * 获取用于 ijkplayer 的 Surface
     * 
     * ijkplayer 通过 setSurface() 方法将解码后的视频帧直接渲染到此 Surface，
     * 实现零拷贝渲染。
     */
    fun getSurface(): Surface? = surface
    
    /**
     * 获取 SurfaceTexture
     */
    fun getSurfaceTexture(): SurfaceTexture? = textureEntry?.surfaceTexture()
    
    /**
     * 获取 Texture ID
     */
    fun getTextureId(): Long? = textureEntry?.id()
    
    /**
     * 更新视频尺寸
     */
    fun updateSize(width: Int, height: Int) {
        textureEntry?.surfaceTexture()?.setDefaultBufferSize(width, height)
        
        currentStatus = currentStatus.copy(
            width = width,
            height = height
        )
        statusListener?.invoke(currentStatus)
    }
    
    /**
     * 设置状态监听器
     */
    fun setStatusListener(listener: ((RendererStatus) -> Unit)?) {
        this.statusListener = listener
    }
    
    /**
     * 获取当前渲染状态
     */
    fun getStatus(): RendererStatus = currentStatus
    
    /**
     * 检查渲染器是否可用
     */
    fun isAvailable(): Boolean = surface?.isValid == true
    
    /**
     * 释放渲染器资源
     */
    fun release() {
        surface?.release()
        surface = null
        
        textureEntry?.release()
        textureEntry = null
        
        currentStatus = RendererStatus(
            textureId = null,
            isActive = false,
            width = 0,
            height = 0
        )
        statusListener?.invoke(currentStatus)
    }
}
