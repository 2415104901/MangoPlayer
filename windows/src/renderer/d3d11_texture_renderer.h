// MangoPlayer Windows Plugin
// D3D11 Texture Renderer - Flutter External Texture

#ifndef D3D11_TEXTURE_RENDERER_H_
#define D3D11_TEXTURE_RENDERER_H_

#include <d3d11.h>
#include <wrl/client.h>

#include <flutter/texture_registrar.h>

#include <atomic>
#include <mutex>
#include <memory>

// Forward declaration
extern "C" {
struct AVFrame;
}

namespace mango_player {

class D3D11TextureRenderer : public flutter::TextureVariant {
 public:
  D3D11TextureRenderer(flutter::TextureRegistrar* texture_registrar);
  ~D3D11TextureRenderer();

  // Initialize D3D11 device and textures
  bool Initialize();
  bool Initialize(int width, int height);

  // Update texture with new frame data
  void UpdateTexture(const uint8_t* data, int width, int height, int stride);
  
  // Update with AVFrame (YUV to RGBA conversion)
  void UpdateWithAVFrame(AVFrame* frame, int64_t pts_ms);
  
  // Update with D3D11 texture directly (zero-copy)
  void UpdateWithD3D11Texture(ID3D11Texture2D* texture, int subresource_index = 0);

  // Get Flutter texture ID
  int64_t GetTextureId() const { return texture_id_; }

  // Get dimensions
  int GetWidth() const { return width_; }
  int GetHeight() const { return height_; }

  // Dispose resources
  void Dispose();

 private:
  // Create D3D11 device and context
  bool CreateD3D11Device();
  
  // Create texture for rendering
  bool CreateTexture(int width, int height);
  
  // FlutterDesktopPixelBuffer callback
  const FlutterDesktopPixelBuffer* CopyPixelBuffer(size_t width, size_t height);

  flutter::TextureRegistrar* texture_registrar_;
  int64_t texture_id_ = -1;

  Microsoft::WRL::ComPtr<ID3D11Device> device_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> context_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> render_texture_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> staging_texture_;

  std::unique_ptr<FlutterDesktopPixelBuffer> pixel_buffer_;
  std::vector<uint8_t> pixel_data_;

  int width_ = 0;
  int height_ = 0;

  std::mutex mutex_;
  std::atomic<bool> is_initialized_{false};
  std::atomic<bool> needs_update_{false};
};

}  // namespace mango_player

#endif  // D3D11_TEXTURE_RENDERER_H_
