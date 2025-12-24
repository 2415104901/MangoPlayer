package com.example.mango_player.renderer

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLES11Ext
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * OpenGL ES 纹理管理器
 * 
 * 管理 OpenGL ES 纹理资源，用于视频帧渲染。
 * 支持 External Texture (OES) 和标准 2D 纹理。
 * 
 * 任务: T115 [US6]
 */
class OpenGLTextureManager {
    
    companion object {
        private const val TAG = "OpenGLTextureManager"
        
        // 顶点着色器
        private const val VERTEX_SHADER = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = aPosition;
                vTexCoord = aTexCoord;
            }
        """
        
        // 片段着色器 (External OES Texture)
        private const val FRAGMENT_SHADER_OES = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 vTexCoord;
            uniform samplerExternalOES sTexture;
            void main() {
                gl_FragColor = texture2D(sTexture, vTexCoord);
            }
        """
        
        // 片段着色器 (Standard 2D Texture)
        private const val FRAGMENT_SHADER_2D = """
            precision mediump float;
            varying vec2 vTexCoord;
            uniform sampler2D sTexture;
            void main() {
                gl_FragColor = texture2D(sTexture, vTexCoord);
            }
        """
        
        // 顶点坐标
        private val VERTEX_COORDS = floatArrayOf(
            -1.0f, -1.0f,  // 左下
             1.0f, -1.0f,  // 右下
            -1.0f,  1.0f,  // 左上
             1.0f,  1.0f   // 右上
        )
        
        // 纹理坐标
        private val TEXTURE_COORDS = floatArrayOf(
            0.0f, 1.0f,  // 左下
            1.0f, 1.0f,  // 右下
            0.0f, 0.0f,  // 左上
            1.0f, 0.0f   // 右上
        )
    }
    
    /**
     * 纹理类型
     */
    enum class TextureType {
        EXTERNAL_OES,  // External OES 纹理 (用于 SurfaceTexture)
        TEXTURE_2D     // 标准 2D 纹理
    }
    
    /**
     * 纹理信息
     */
    data class TextureInfo(
        val textureId: Int,
        val type: TextureType,
        val width: Int,
        val height: Int
    )
    
    // EGL 资源
    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var eglConfig: EGLConfig? = null
    
    // OpenGL 资源
    private var programOES = 0
    private var program2D = 0
    private var vertexBuffer: FloatBuffer? = null
    private var textureBuffer: FloatBuffer? = null
    
    // 纹理管理
    private val textures = mutableMapOf<Int, TextureInfo>()
    private var nextTextureId = 1
    
    private var isInitialized = false
    
    /**
     * 初始化 EGL 和 OpenGL 环境
     */
    fun initialize(): Boolean {
        if (isInitialized) return true
        
        try {
            // 获取 EGL Display
            eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
                return false
            }
            
            // 初始化 EGL
            val version = IntArray(2)
            if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
                return false
            }
            
            // 选择配置
            val configAttribs = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_NONE
            )
            
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            if (!EGL14.eglChooseConfig(eglDisplay, configAttribs, 0, configs, 0, 1, numConfigs, 0)) {
                return false
            }
            eglConfig = configs[0]
            
            // 创建 EGL Context
            val contextAttribs = intArrayOf(
                EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
                EGL14.EGL_NONE
            )
            eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
            if (eglContext == EGL14.EGL_NO_CONTEXT) {
                return false
            }
            
            // 创建 PBuffer Surface
            val surfaceAttribs = intArrayOf(
                EGL14.EGL_WIDTH, 1,
                EGL14.EGL_HEIGHT, 1,
                EGL14.EGL_NONE
            )
            eglSurface = EGL14.eglCreatePbufferSurface(eglDisplay, eglConfig, surfaceAttribs, 0)
            
            // 绑定上下文
            if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
                return false
            }
            
            // 初始化着色器程序
            programOES = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_OES)
            program2D = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_2D)
            
            // 初始化顶点缓冲
            vertexBuffer = createFloatBuffer(VERTEX_COORDS)
            textureBuffer = createFloatBuffer(TEXTURE_COORDS)
            
            isInitialized = true
            return true
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to initialize OpenGL", e)
            return false
        }
    }
    
    /**
     * 创建 External OES 纹理
     */
    fun createExternalTexture(): TextureInfo? {
        if (!isInitialized) return null
        
        val textureIds = IntArray(1)
        GLES20.glGenTextures(1, textureIds, 0)
        
        val textureId = textureIds[0]
        if (textureId == 0) return null
        
        // 绑定为 External OES 纹理
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, 0)
        
        val info = TextureInfo(textureId, TextureType.EXTERNAL_OES, 0, 0)
        textures[textureId] = info
        
        return info
    }
    
    /**
     * 创建标准 2D 纹理
     */
    fun createTexture2D(width: Int, height: Int): TextureInfo? {
        if (!isInitialized) return null
        
        val textureIds = IntArray(1)
        GLES20.glGenTextures(1, textureIds, 0)
        
        val textureId = textureIds[0]
        if (textureId == 0) return null
        
        // 绑定为 2D 纹理
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        
        // 分配纹理存储
        GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, width, height, 0,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        
        val info = TextureInfo(textureId, TextureType.TEXTURE_2D, width, height)
        textures[textureId] = info
        
        return info
    }
    
    /**
     * 删除纹理
     */
    fun deleteTexture(textureId: Int) {
        textures.remove(textureId)
        GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
    }
    
    /**
     * 获取纹理信息
     */
    fun getTextureInfo(textureId: Int): TextureInfo? {
        return textures[textureId]
    }
    
    /**
     * 获取所有纹理
     */
    fun getAllTextures(): List<TextureInfo> {
        return textures.values.toList()
    }
    
    /**
     * 创建 SurfaceTexture 用于接收视频帧
     */
    fun createSurfaceTexture(textureId: Int): SurfaceTexture? {
        val info = textures[textureId] ?: return null
        if (info.type != TextureType.EXTERNAL_OES) return null
        
        return SurfaceTexture(textureId)
    }
    
    /**
     * 从 SurfaceTexture 创建 Surface
     */
    fun createSurface(surfaceTexture: SurfaceTexture): Surface {
        return Surface(surfaceTexture)
    }
    
    /**
     * 释放所有资源
     */
    fun release() {
        // 删除所有纹理
        for (textureId in textures.keys) {
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
        }
        textures.clear()
        
        // 删除着色器程序
        if (programOES != 0) {
            GLES20.glDeleteProgram(programOES)
            programOES = 0
        }
        if (program2D != 0) {
            GLES20.glDeleteProgram(program2D)
            program2D = 0
        }
        
        // 释放 EGL 资源
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            
            if (eglSurface != EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroySurface(eglDisplay, eglSurface)
                eglSurface = EGL14.EGL_NO_SURFACE
            }
            
            if (eglContext != EGL14.EGL_NO_CONTEXT) {
                EGL14.eglDestroyContext(eglDisplay, eglContext)
                eglContext = EGL14.EGL_NO_CONTEXT
            }
            
            EGL14.eglTerminate(eglDisplay)
            eglDisplay = EGL14.EGL_NO_DISPLAY
        }
        
        isInitialized = false
    }
    
    // 私有辅助方法
    
    private fun createProgram(vertexShaderCode: String, fragmentShaderCode: String): Int {
        val vertexShader = compileShader(GLES20.GL_VERTEX_SHADER, vertexShaderCode)
        val fragmentShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderCode)
        
        if (vertexShader == 0 || fragmentShader == 0) return 0
        
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertexShader)
        GLES20.glAttachShader(program, fragmentShader)
        GLES20.glLinkProgram(program)
        
        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] == 0) {
            GLES20.glDeleteProgram(program)
            return 0
        }
        
        return program
    }
    
    private fun compileShader(type: Int, code: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, code)
        GLES20.glCompileShader(shader)
        
        val compileStatus = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compileStatus, 0)
        if (compileStatus[0] == 0) {
            GLES20.glDeleteShader(shader)
            return 0
        }
        
        return shader
    }
    
    private fun createFloatBuffer(array: FloatArray): FloatBuffer {
        val buffer = ByteBuffer.allocateDirect(array.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        buffer.put(array)
        buffer.position(0)
        return buffer
    }
}
