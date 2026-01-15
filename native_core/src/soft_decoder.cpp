/**
 * MangoPlayer Native Core - Software Decoder Implementation
 * 
 * FFmpeg 软件解码器实现 - 100% 跨平台代码
 */

#include "mango_player/soft_decoder.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/frame.h>
}

namespace mango_player {

SoftDecoder::SoftDecoder(DecoderType type)
    : type_(type)
{
}

SoftDecoder::~SoftDecoder() {
    Release();
}

bool SoftDecoder::Initialize(AVCodecParameters* params) {
    if (!params) {
        return false;
    }

    // 查找解码器
    const AVCodec* codec = avcodec_find_decoder(params->codec_id);
    if (!codec) {
        return false;
    }

    // 创建解码器上下文
    codec_ctx_ = avcodec_alloc_context3(codec);
    if (!codec_ctx_) {
        return false;
    }

    // 复制参数
    if (avcodec_parameters_to_context(codec_ctx_, params) < 0) {
        Release();
        return false;
    }

    // 设置多线程解码
    codec_ctx_->thread_count = 0;  // 自动选择线程数
    codec_ctx_->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;

    // 打开解码器
    if (avcodec_open2(codec_ctx_, codec, nullptr) < 0) {
        Release();
        return false;
    }

    // 分配临时帧
    temp_frame_ = av_frame_alloc();
    if (!temp_frame_) {
        Release();
        return false;
    }

    return true;
}

AVFrame* SoftDecoder::Decode(AVPacket* pkt) {
    if (!codec_ctx_ || !temp_frame_) {
        return nullptr;
    }

    // 发送数据包到解码器
    int ret = avcodec_send_packet(codec_ctx_, pkt);
    if (ret < 0 && ret != AVERROR(EAGAIN)) {
        return nullptr;
    }

    // 接收解码后的帧
    ret = avcodec_receive_frame(codec_ctx_, temp_frame_);
    if (ret < 0) {
        return nullptr;
    }

    // 分配输出帧并复制数据
    AVFrame* output_frame = av_frame_alloc();
    if (!output_frame) {
        return nullptr;
    }

    av_frame_move_ref(output_frame, temp_frame_);
    return output_frame;
}

AVFrame* SoftDecoder::Flush() {
    if (!codec_ctx_ || !temp_frame_) {
        return nullptr;
    }

    // 发送空包触发刷新
    avcodec_send_packet(codec_ctx_, nullptr);

    // 接收剩余帧
    int ret = avcodec_receive_frame(codec_ctx_, temp_frame_);
    if (ret < 0) {
        return nullptr;
    }

    AVFrame* output_frame = av_frame_alloc();
    if (!output_frame) {
        return nullptr;
    }

    av_frame_move_ref(output_frame, temp_frame_);
    return output_frame;
}

void SoftDecoder::FreeFrame(AVFrame* frame) {
    if (frame) {
        av_frame_free(&frame);
    }
}

void SoftDecoder::Reset() {
    if (codec_ctx_) {
        avcodec_flush_buffers(codec_ctx_);
    }
}

void SoftDecoder::Release() {
    if (temp_frame_) {
        av_frame_free(&temp_frame_);
        temp_frame_ = nullptr;
    }

    if (codec_ctx_) {
        avcodec_free_context(&codec_ctx_);
        codec_ctx_ = nullptr;
    }
}

} // namespace mango_player
