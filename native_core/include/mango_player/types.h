/**
 * MangoPlayer Native Core - Common Types
 * 
 * 跨平台类型定义，所有平台共享
 * 仅此文件包含少量平台特定类型定义 (#ifdef)
 */

#pragma once

#include <cstdint>
#include <string>
#include <functional>
#include <memory>

namespace mango_player {

// =============================================================================
// 基础类型
// =============================================================================

/// 播放器状态枚举
enum class PlayerState {
    Idle,
    Initializing,
    Ready,
    Playing,
    Paused,
    Buffering,
    Completed,
    Error
};

/// 错误码枚举
enum class ErrorCode {
    None = 0,
    InvalidSource = 1001,
    NetworkError = 1002,
    DecodeError = 2001,
    HardwareDecoderUnavailable = 2002,
    RenderError = 3001,
    TextureCreationFailed = 3002,
    AudioOutputError = 4001,
    Unknown = 9999
};

/// 媒体信息结构
struct MediaInfo {
    std::string uri;
    int64_t duration_ms = 0;
    int width = 0;
    int height = 0;
    double frame_rate = 0.0;
    int audio_channels = 0;
    int audio_sample_rate = 0;
    std::string video_codec;
    std::string audio_codec;
    int64_t bitrate = 0;
};

/// 视频帧信息
struct VideoFrame {
    void* data = nullptr;          // 平台特定数据指针 (CVPixelBuffer/ID3D11Texture2D/etc.)
    int width = 0;
    int height = 0;
    int64_t pts_ms = 0;
    int64_t duration_ms = 0;
    bool is_key_frame = false;
};

/// 音频帧信息
struct AudioFrame {
    const uint8_t* data = nullptr;
    int size = 0;
    int channels = 0;
    int sample_rate = 0;
    int64_t pts_ms = 0;
};

/// 性能指标
struct PerformanceMetrics {
    double fps = 0.0;
    int64_t decode_latency_ms = 0;
    int64_t render_latency_ms = 0;
    int dropped_frames = 0;
    int64_t buffer_size_bytes = 0;
    double cpu_usage = 0.0;
    int64_t memory_usage_bytes = 0;
};

// =============================================================================
// 事件类型
// =============================================================================

/// 播放器事件类型
enum class EventType {
    StateChanged,
    PositionChanged,
    BufferingUpdate,
    DurationChanged,
    VideoSizeChanged,
    FirstFrameRendered,
    SeekCompleted,
    PlaybackCompleted,
    Error,
    PerformanceUpdate
};

/// 播放器事件
struct PlayerEvent {
    EventType type;
    PlayerState state = PlayerState::Idle;
    int64_t position_ms = 0;
    double buffering_percent = 0.0;
    ErrorCode error_code = ErrorCode::None;
    std::string error_message;
    PerformanceMetrics metrics;
};

/// 事件回调类型
using EventCallback = std::function<void(const PlayerEvent&)>;

// =============================================================================
// 平台特定类型别名 (唯一需要 #ifdef 的地方)
// =============================================================================

#if defined(__APPLE__)
    // macOS/iOS: CVPixelBufferRef
    #include <CoreVideo/CoreVideo.h>
    using PlatformTextureHandle = CVPixelBufferRef;
    using PlatformAudioDeviceHandle = void*;  // AudioUnit or AVAudioEngine
#elif defined(_WIN32)
    // Windows: ID3D11Texture2D*
    struct ID3D11Texture2D;
    using PlatformTextureHandle = ID3D11Texture2D*;
    using PlatformAudioDeviceHandle = void*;  // WASAPI device
#elif defined(__ANDROID__)
    // Android: ANativeWindow* or Surface JNI reference
    using PlatformTextureHandle = void*;
    using PlatformAudioDeviceHandle = void*;  // AudioTrack JNI reference
#else
    // 通用回退
    using PlatformTextureHandle = void*;
    using PlatformAudioDeviceHandle = void*;
#endif

} // namespace mango_player
