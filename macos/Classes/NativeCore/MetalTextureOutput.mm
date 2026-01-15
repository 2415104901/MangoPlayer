/**
 * MetalTextureOutput Implementation
 */

#include "MetalTextureOutput.h"
#import <FlutterMacOS/FlutterMacOS.h>

extern "C" {
#include <libavutil/frame.h>
#include <libavutil/pixfmt.h>
}

namespace mango_player {

MetalTextureOutputImpl::MetalTextureOutputImpl()
    : device_(nil)
    , command_queue_(nil)
    , texture_registry_(nullptr)
    , texture_id_(-1)
    , width_(0)
    , height_(0)
    , is_initialized_(false) {
}

MetalTextureOutputImpl::~MetalTextureOutputImpl() {
    Release();
}

bool MetalTextureOutputImpl::Initialize(int width, int height, void* texture_registry_handle) {
    width_ = width;
    height_ = height;
    texture_registry_ = texture_registry_handle;

    device_ = MTLCreateSystemDefaultDevice();
    if (!device_) {
        NSLog(@"Failed to create Metal device");
        return false;
    }

    command_queue_ = [device_ newCommandQueue];
    if (!command_queue_) {
        NSLog(@"Failed to create Metal command queue");
        return false;
    }

    is_initialized_ = true;
    return true;
}

PlatformTextureHandle MetalTextureOutputImpl::CreateTexture(int width, int height) {
    if (!is_initialized_) {
        return nullptr;
    }

    // Create pixel buffer for texture
    NSDictionary* pixelBufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey: @(width),
        (id)kCVPixelBufferHeightKey: @(height),
        (id)kCVPixelBufferMetalCompatibilityKey: @YES,
    };

    CVPixelBufferRef pixelBuffer = nullptr;
    CVReturn status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)pixelBufferAttributes,
        &pixelBuffer);

    if (status != kCVReturnSuccess) {
        NSLog(@"Failed to create pixel buffer: %d", status);
        return nullptr;
    }

    return pixelBuffer;
}

bool MetalTextureOutputImpl::FrameToTexture(AVFrame* frame, VideoFrame& out_frame) {
    if (!is_initialized_ || !frame) {
        return false;
    }

    // If frame already contains CVPixelBuffer (from VideoToolbox), use it directly
    if (frame->data[3]) {
        CVPixelBufferRef pixel_buffer = (CVPixelBufferRef)frame->data[3];
        out_frame.width = frame->width;
        out_frame.height = frame->height;
        out_frame.pts_ms = frame->pts * av_q2d(frame->time_base) * 1000.0;
        out_frame.data = pixel_buffer;
        return true;
    }

    // Software decoded frame - need to convert to CVPixelBuffer
    CVPixelBufferRef pixel_buffer = (CVPixelBufferRef)CreateTexture(frame->width, frame->height);
    if (!pixel_buffer) {
        return false;
    }

    CVPixelBufferLockBaseAddress(pixel_buffer, 0);
    
    void* baseAddress = CVPixelBufferGetBaseAddress(pixel_buffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixel_buffer);

    // Simple copy for now - in production, use vImage or Metal compute shader
    // This assumes BGRA format
    for (int y = 0; y < frame->height; y++) {
        memcpy((uint8_t*)baseAddress + y * bytesPerRow,
               frame->data[0] + y * frame->linesize[0],
               frame->width * 4);
    }

    CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);

    out_frame.width = frame->width;
    out_frame.height = frame->height;
    out_frame.pts_ms = frame->pts * av_q2d(frame->time_base) * 1000.0;
    out_frame.data = pixel_buffer;

    return true;
}

bool MetalTextureOutputImpl::SubmitTexture(const VideoFrame& frame) {
    if (!is_initialized_ || !texture_registry_) {
        return false;
    }

    // Flutter will handle the texture through the registry
    // Store the texture for Flutter to pick up
    return true;
}

void MetalTextureOutputImpl::DestroyTexture(PlatformTextureHandle texture) {
    if (texture) {
        CVPixelBufferRef pixel_buffer = (CVPixelBufferRef)texture;
        CFRelease(pixel_buffer);
    }
}

void MetalTextureOutputImpl::Resize(int width, int height) {
    width_ = width;
    height_ = height;
}

int64_t MetalTextureOutputImpl::GetTextureId() const {
    return texture_id_;
}

void MetalTextureOutputImpl::Release() {
    command_queue_ = nil;
    device_ = nil;
    is_initialized_ = false;
}

} // namespace mango_player

// C interface implementation
extern "C" {

void* mango_create_metal_texture_output(void) {
    return new mango_player::MetalTextureOutputImpl();
}

void mango_destroy_metal_texture_output(void* output) {
    if (output) {
        delete static_cast<mango_player::MetalTextureOutputImpl*>(output);
    }
}

} // extern "C"
