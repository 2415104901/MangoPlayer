/**
 * MangoPlayer Native Core - FFmpeg Software Decoder
 * 
 * FFmpeg 软件解码器 - 100% 跨平台代码
 * 用于硬件解码不可用时的回退方案
 */

#pragma once

#include "types.h"
#include <memory>

// Forward declarations for FFmpeg types
struct AVCodecContext;
struct AVCodecParameters;
struct AVPacket;
struct AVFrame;

namespace mango_player {

/**
 * 解码器类型枚举
 */
enum class DecoderType {
    Video,
    Audio
};

/**
 * FFmpeg 软件解码器
 * 
 * 此类为 100% 跨平台实现
 * 输出 AVFrame (YUV420P 视频 / PCM 音频)
 * 
 * 使用示例:
 * ```cpp
 * SoftDecoder decoder(DecoderType::Video);
 * if (decoder.Initialize(video_params)) {
 *     AVFrame* frame = decoder.Decode(pkt);
 *     if (frame) {
 *         // 处理解码帧
 *         decoder.FreeFrame(frame);
 *     }
 * }
 * ```
 */
class SoftDecoder {
public:
    explicit SoftDecoder(DecoderType type);
    ~SoftDecoder();

    // 禁用拷贝
    SoftDecoder(const SoftDecoder&) = delete;
    SoftDecoder& operator=(const SoftDecoder&) = delete;

    /**
     * 初始化解码器
     * @param params 编解码器参数 (来自 Demuxer::GetVideoCodecParams())
     * @return true 如果初始化成功
     */
    bool Initialize(AVCodecParameters* params);

    /**
     * 解码数据包
     * @param pkt 输入数据包
     * @return 解码后的帧，无输出时返回 nullptr
     *         调用者需要通过 FreeFrame() 释放
     */
    AVFrame* Decode(AVPacket* pkt);

    /**
     * 刷新解码器，获取缓冲的帧
     * @return 缓冲的帧，无更多帧时返回 nullptr
     */
    AVFrame* Flush();

    /**
     * 释放帧
     * @param frame 要释放的帧
     */
    void FreeFrame(AVFrame* frame);

    /**
     * 重置解码器状态 (用于 seek 后)
     */
    void Reset();

    /**
     * 释放解码器资源
     */
    void Release();

    /**
     * 获取解码器上下文 (用于某些高级操作)
     */
    AVCodecContext* GetCodecContext() const { return codec_ctx_; }

    /**
     * 是否已初始化
     */
    bool IsInitialized() const { return codec_ctx_ != nullptr; }

    /**
     * 获取解码器类型
     */
    DecoderType GetType() const { return type_; }

private:
    DecoderType type_;
    AVCodecContext* codec_ctx_ = nullptr;
    AVFrame* temp_frame_ = nullptr;  // 用于接收解码输出
};

} // namespace mango_player
