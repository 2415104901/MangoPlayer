/**
 * MangoPlayer Native Core - Texture Output Interface
 * 
 * 纹理输出抽象接口
 * 各平台实现: Metal (macOS/iOS), D3D11 (Windows), OpenGL ES (Android)
 * 
 * 职责:
 * - 创建平台特定纹理
 * - 将解码帧 (软解 AVFrame) 转换为平台纹理
 * - 管理纹理生命周期
 * - 与 Flutter TextureRegistry 对接
 */

#pragma once

#include "../types.h"

// Forward declarations
struct AVFrame;

namespace mango_player {

/**
 * 纹理输出抽象接口
 * 
 * 平台实现:
 * - macOS/iOS: MetalTextureOutput (Metal + CVPixelBuffer)
 * - Windows: D3D11TextureOutput (D3D11 + ID3D11Texture2D)
 * - Android: OpenGLTextureOutput (OpenGL ES + SurfaceTexture)
 */
class ITextureOutput {
public:
    virtual ~ITextureOutput() = default;

    /**
     * 初始化纹理输出系统
     * @param width 视频宽度
     * @param height 视频高度
     * @param texture_registry_handle Flutter TextureRegistry 句柄 (平台特定)
     * @return true 如果初始化成功
     */
    virtual bool Initialize(int width, int height, void* texture_registry_handle) = 0;

    /**
     * 创建纹理
     * @param width 纹理宽度
     * @param height 纹理高度
     * @return 平台特定纹理句柄，失败返回 nullptr
     */
    virtual PlatformTextureHandle CreateTexture(int width, int height) = 0;

    /**
     * 将软解帧转换为平台纹理
     * @param frame FFmpeg AVFrame (YUV420P 或其他软件格式)
     * @param out_frame 输出帧 (包含平台纹理指针)
     * @return true 如果转换成功
     */
    virtual bool FrameToTexture(AVFrame* frame, VideoFrame& out_frame) = 0;

    /**
     * 提交纹理到 Flutter 渲染
     * @param frame 包含纹理的帧
     * @return true 如果提交成功
     */
    virtual bool SubmitTexture(const VideoFrame& frame) = 0;

    /**
     * 销毁纹理
     * @param texture 要销毁的纹理句柄
     */
    virtual void DestroyTexture(PlatformTextureHandle texture) = 0;

    /**
     * 调整输出尺寸
     * @param width 新宽度
     * @param height 新高度
     */
    virtual void Resize(int width, int height) = 0;

    /**
     * 获取当前纹理 ID (Flutter TextureRegistry ID)
     */
    virtual int64_t GetTextureId() const = 0;

    /**
     * 释放所有资源
     */
    virtual void Release() = 0;
};

/**
 * 空纹理输出实现 (占位符)
 */
class NullTextureOutput : public ITextureOutput {
public:
    bool Initialize(int, int, void*) override { return false; }
    PlatformTextureHandle CreateTexture(int, int) override { return nullptr; }
    bool FrameToTexture(AVFrame*, VideoFrame&) override { return false; }
    bool SubmitTexture(const VideoFrame&) override { return false; }
    void DestroyTexture(PlatformTextureHandle) override {}
    void Resize(int, int) override {}
    int64_t GetTextureId() const override { return -1; }
    void Release() override {}
};

} // namespace mango_player
