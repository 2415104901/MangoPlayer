/**
 * VideoToolboxDecoder Implementation
 */

#include "VideoToolboxDecoder.h"
#include <iostream>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/pixdesc.h>
}

namespace mango_player {

VideoToolboxDecoderImpl::VideoToolboxDecoderImpl()
    : decompression_session_(nullptr)
    , format_desc_(nullptr)
    , codec_ctx_(nullptr)
    , current_pixel_buffer_(nullptr)
    , is_initialized_(false)
    , width_(0)
    , height_(0) {
}

VideoToolboxDecoderImpl::~VideoToolboxDecoderImpl() {
    Release();
}

bool VideoToolboxDecoderImpl::IsSupported(AVCodecID codec_id) const {
    // VideoToolbox supports H.264 and H.265/HEVC
    return codec_id == AV_CODEC_ID_H264 || codec_id == AV_CODEC_ID_HEVC;
}

bool VideoToolboxDecoderImpl::Initialize(AVCodecContext* codec_ctx) {
    if (!codec_ctx) {
        return false;
    }

    codec_ctx_ = codec_ctx;
    width_ = codec_ctx->width;
    height_ = codec_ctx->height;

    if (!CreateFormatDescription()) {
        return false;
    }

    if (!CreateDecompressionSession()) {
        return false;
    }

    is_initialized_ = true;
    return true;
}

bool VideoToolboxDecoderImpl::CreateFormatDescription() {
    CMVideoCodecType codec_type = kCMVideoCodecType_H264;
    
    if (codec_ctx_->codec_id == AV_CODEC_ID_HEVC) {
        codec_type = kCMVideoCodecType_HEVC;
    }

    const uint8_t* extradata = codec_ctx_->extradata;
    size_t extradata_size = codec_ctx_->extradata_size;

    OSStatus status = CMVideoFormatDescriptionCreate(
        kCFAllocatorDefault,
        codec_type,
        width_,
        height_,
        nullptr,
        &format_desc_);

    if (status != noErr) {
        NSLog(@"Failed to create format description: %d", (int)status);
        return false;
    }

    return true;
}

bool VideoToolboxDecoderImpl::CreateDecompressionSession() {
    NSDictionary* destinationPixelBufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        (id)kCVPixelBufferWidthKey: @(width_),
        (id)kCVPixelBufferHeightKey: @(height_),
        (id)kCVPixelBufferMetalCompatibilityKey: @YES,
    };

    VTDecompressionOutputCallbackRecord callback_record;
    callback_record.decompressionOutputCallback = DecompressionOutputCallback;
    callback_record.decompressionOutputRefCon = this;

    OSStatus status = VTDecompressionSessionCreate(
        kCFAllocatorDefault,
        format_desc_,
        nullptr,
        (__bridge CFDictionaryRef)destinationPixelBufferAttributes,
        &callback_record,
        &decompression_session_);

    if (status != noErr) {
        NSLog(@"Failed to create decompression session: %d", (int)status);
        return false;
    }

    return true;
}

void VideoToolboxDecoderImpl::DecompressionOutputCallback(
    void* decompressionOutputRefCon,
    void* sourceFrameRefCon,
    OSStatus status,
    VTDecodeInfoFlags infoFlags,
    CVImageBufferRef imageBuffer,
    CMTime presentationTimeStamp,
    CMTime presentationDuration) {
    
    if (status != noErr) {
        NSLog(@"VideoToolbox decode error: %d", (int)status);
        return;
    }

    VideoToolboxDecoderImpl* decoder = static_cast<VideoToolboxDecoderImpl*>(decompressionOutputRefCon);
    
    if (imageBuffer) {
        if (decoder->current_pixel_buffer_) {
            CFRelease(decoder->current_pixel_buffer_);
        }
        decoder->current_pixel_buffer_ = (CVPixelBufferRef)CFRetain(imageBuffer);
    }
}

bool VideoToolboxDecoderImpl::Decode(AVPacket* pkt, VideoFrame& out_frame) {
    if (!is_initialized_ || !decompression_session_) {
        return false;
    }

    CMBlockBufferRef block_buffer = nullptr;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(
        kCFAllocatorDefault,
        nullptr,
        pkt->size,
        kCFAllocatorDefault,
        nullptr,
        0,
        pkt->size,
        0,
        &block_buffer);

    if (status != noErr) {
        return false;
    }

    status = CMBlockBufferReplaceDataBytes(pkt->data, block_buffer, 0, pkt->size);
    if (status != noErr) {
        CFRelease(block_buffer);
        return false;
    }

    CMSampleBufferRef sample_buffer = nullptr;
    status = CMSampleBufferCreate(
        kCFAllocatorDefault,
        block_buffer,
        true,
        nullptr,
        nullptr,
        format_desc_,
        1,
        0,
        nullptr,
        0,
        nullptr,
        &sample_buffer);

    CFRelease(block_buffer);

    if (status != noErr) {
        return false;
    }

    VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
    VTDecodeInfoFlags info_flags;
    
    status = VTDecompressionSessionDecodeFrame(
        decompression_session_,
        sample_buffer,
        flags,
        nullptr,
        &info_flags);

    CFRelease(sample_buffer);

    if (status != noErr) {
        return false;
    }

    // Wait for callback to set current_pixel_buffer_
    VTDecompressionSessionWaitForAsynchronousFrames(decompression_session_);

    if (current_pixel_buffer_) {
        out_frame.width = width_;
        out_frame.height = height_;
        out_frame.pts_ms = pkt->pts * av_q2d(codec_ctx_->time_base) * 1000.0;
        out_frame.data = current_pixel_buffer_;
        current_pixel_buffer_ = nullptr;  // Transfer ownership
        return true;
    }

    return false;
}

bool VideoToolboxDecoderImpl::Flush(VideoFrame& out_frame) {
    if (!decompression_session_) {
        return false;
    }

    VTDecompressionSessionFinishDelayedFrames(decompression_session_);
    VTDecompressionSessionWaitForAsynchronousFrames(decompression_session_);

    if (current_pixel_buffer_) {
        out_frame.data = current_pixel_buffer_;
        current_pixel_buffer_ = nullptr;
        return true;
    }

    return false;
}

void VideoToolboxDecoderImpl::Reset() {
    if (decompression_session_) {
        VTDecompressionSessionWaitForAsynchronousFrames(decompression_session_);
    }
    
    if (current_pixel_buffer_) {
        CFRelease(current_pixel_buffer_);
        current_pixel_buffer_ = nullptr;
    }
}

void VideoToolboxDecoderImpl::Release() {
    if (current_pixel_buffer_) {
        CFRelease(current_pixel_buffer_);
        current_pixel_buffer_ = nullptr;
    }

    if (decompression_session_) {
        VTDecompressionSessionInvalidate(decompression_session_);
        CFRelease(decompression_session_);
        decompression_session_ = nullptr;
    }

    if (format_desc_) {
        CFRelease(format_desc_);
        format_desc_ = nullptr;
    }

    is_initialized_ = false;
}

const char* VideoToolboxDecoderImpl::GetName() const {
    return "VideoToolbox";
}

AVPixelFormat VideoToolboxDecoderImpl::GetHWPixelFormat() const {
    return AV_PIX_FMT_VIDEOTOOLBOX;
}

} // namespace mango_player

// C interface implementation
extern "C" {

void* mango_create_videotoolbox_decoder(void) {
    return new mango_player::VideoToolboxDecoderImpl();
}

void mango_destroy_videotoolbox_decoder(void* decoder) {
    if (decoder) {
        delete static_cast<mango_player::VideoToolboxDecoderImpl*>(decoder);
    }
}

} // extern "C"
