/**
 * VideoToolboxDecoder - macOS VideoToolbox Hardware Decoder
 * 
 * Implements IHardwareDecoder interface using Apple VideoToolbox framework
 * Provides hardware-accelerated H.264/H.265 decoding
 */

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreVideo/CoreVideo.h>

// Include native_core C++ interface
#ifdef __cplusplus
#include "mango_player/interfaces/hw_decoder.h"

namespace mango_player {

class VideoToolboxDecoderImpl : public IHardwareDecoder {
public:
    VideoToolboxDecoderImpl();
    ~VideoToolboxDecoderImpl() override;

    bool IsSupported(AVCodecID codec_id) const override;
    bool Initialize(AVCodecContext* codec_ctx) override;
    bool Decode(AVPacket* pkt, VideoFrame& out_frame) override;
    bool Flush(VideoFrame& out_frame) override;
    void Reset() override;
    void Release() override;
    const char* GetName() const override;
    AVPixelFormat GetHWPixelFormat() const override;

private:
    VTDecompressionSessionRef decompression_session_;
    CMVideoFormatDescriptionRef format_desc_;
    AVCodecContext* codec_ctx_;
    CVPixelBufferRef current_pixel_buffer_;
    bool is_initialized_;
    int width_;
    int height_;

    bool CreateFormatDescription();
    bool CreateDecompressionSession();
    static void DecompressionOutputCallback(
        void* decompressionOutputRefCon,
        void* sourceFrameRefCon,
        OSStatus status,
        VTDecodeInfoFlags infoFlags,
        CVImageBufferRef imageBuffer,
        CMTime presentationTimeStamp,
        CMTime presentationDuration);
};

} // namespace mango_player

#endif // __cplusplus

// C interface for Swift/ObjC
#ifdef __cplusplus
extern "C" {
#endif

void* mango_create_videotoolbox_decoder(void);
void mango_destroy_videotoolbox_decoder(void* decoder);

#ifdef __cplusplus
}
#endif
