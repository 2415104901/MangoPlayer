/**
 * MangoPlayer Native Core - Hardware Decoder Interface
 * 
 * 硬件解码器抽象接口
 * 各平台实现: VideoToolbox (macOS/iOS), DXVA2 (Windows), MediaCodec (Android)
 * 
 * 设计原则:
 * - 此接口定义跨平台契约，无任何平台特定代码
 * - 各平台在自己的目录下实现此接口
 * - 通过依赖注入传入 PlayerCore
 */

#pragma once

#include "../types.h"

// Forward declarations for FFmpeg types
struct AVCodecContext;
struct AVPacket;
struct AVFrame;

// Include FFmpeg enums directly (can't forward declare enums in C++)
extern "C" {
#include <libavcodec/avcodec.h>
}

namespace mango_player {

/**
 * 硬件解码器抽象接口
 * 
 * 平台实现:
 * - macOS/iOS: VideoToolboxDecoder (VideoToolbox + CVPixelBuffer)
 * - Windows: DXVADecoder (DXVA2 + ID3D11Texture2D)
 * - Android: MediaCodecDecoder (MediaCodec + Surface)
 */
class IHardwareDecoder {
public:
    virtual ~IHardwareDecoder() = default;

    /**
     * 检查是否支持指定编解码器的硬件解码
     * @param codec_id FFmpeg 编解码器 ID (AV_CODEC_ID_H264, AV_CODEC_ID_HEVC, etc.)
     * @return true 如果支持硬件解码
     */
    virtual bool IsSupported(AVCodecID codec_id) const = 0;

    /**
     * 初始化硬件解码器
     * @param codec_ctx FFmpeg 编解码器上下文 (包含视频参数)
     * @return true 如果初始化成功
     */
    virtual bool Initialize(AVCodecContext* codec_ctx) = 0;

    /**
     * 解码单个数据包
     * @param pkt 输入的压缩数据包
     * @param out_frame 输出帧 (包含平台特定纹理指针)
     * @return true 如果解码成功
     */
    virtual bool Decode(AVPacket* pkt, VideoFrame& out_frame) = 0;

    /**
     * 刷新解码器 (处理 B 帧重排序等)
     * @param out_frame 输出帧
     * @return true 如果有帧输出
     */
    virtual bool Flush(VideoFrame& out_frame) = 0;

    /**
     * 重置解码器状态 (用于 seek 后)
     */
    virtual void Reset() = 0;

    /**
     * 释放解码器资源
     */
    virtual void Release() = 0;

    /**
     * 获取解码器名称 (用于日志)
     */
    virtual const char* GetName() const = 0;

    /**
     * 获取硬件像素格式 (用于 FFmpeg get_format 回调)
     */
    virtual AVPixelFormat GetHWPixelFormat() const = 0;
};

/**
 * 空硬件解码器实现 (占位符)
 * 当平台不支持硬件解码时使用
 */
class NullHardwareDecoder : public IHardwareDecoder {
public:
    bool IsSupported(AVCodecID) const override { return false; }
    bool Initialize(AVCodecContext*) override { return false; }
    bool Decode(AVPacket*, VideoFrame&) override { return false; }
    bool Flush(VideoFrame&) override { return false; }
    void Reset() override {}
    void Release() override {}
    const char* GetName() const override { return "NullDecoder"; }
    AVPixelFormat GetHWPixelFormat() const override;  // 返回 AV_PIX_FMT_NONE
};

} // namespace mango_player
