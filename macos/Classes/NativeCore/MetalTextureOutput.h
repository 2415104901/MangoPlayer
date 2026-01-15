/**
 * MetalTextureOutput - macOS Metal Texture Output
 * 
 * Implements ITextureOutput interface using Metal framework
 * Provides zero-copy texture rendering to Flutter
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>

#ifdef __cplusplus
#include "mango_player/interfaces/texture_output.h"

namespace mango_player {

class MetalTextureOutputImpl : public ITextureOutput {
public:
    MetalTextureOutputImpl();
    ~MetalTextureOutputImpl() override;

    bool Initialize(int width, int height, void* texture_registry_handle) override;
    PlatformTextureHandle CreateTexture(int width, int height) override;
    bool FrameToTexture(AVFrame* frame, VideoFrame& out_frame) override;
    bool SubmitTexture(const VideoFrame& frame) override;
    void DestroyTexture(PlatformTextureHandle texture) override;
    void Resize(int width, int height) override;
    int64_t GetTextureId() const override;
    void Release() override;

private:
    id<MTLDevice> device_;
    id<MTLCommandQueue> command_queue_;
    void* texture_registry_;
    int64_t texture_id_;
    int width_;
    int height_;
    bool is_initialized_;
};

} // namespace mango_player

#endif // __cplusplus

// C interface for Swift/ObjC
#ifdef __cplusplus
extern "C" {
#endif

void* mango_create_metal_texture_output(void);
void mango_destroy_metal_texture_output(void* output);

#ifdef __cplusplus
}
#endif
