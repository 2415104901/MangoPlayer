/**
 * MangoPlayer Native Core - C Bridge API
 * 
 * C 语言桥接层，供 Swift/ObjC 调用
 * 
 * 为什么需要这个文件:
 * - Swift 不能直接调用 C++ 类
 * - ObjC++ 可以调用 C++，但增加复杂性
 * - 通过纯 C 接口，Swift 可以直接调用
 * 
 * 使用方式:
 * ```swift
 * // Swift 侧
 * let player = mango_player_create()
 * mango_player_initialize(player, "video.mp4", nil)
 * mango_player_play(player)
 * ```
 */

#ifndef MANGO_PLAYER_C_H
#define MANGO_PLAYER_C_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// 不透明句柄类型
// =============================================================================

typedef struct MangoPlayer* MangoPlayerRef;
typedef struct MangoHWDecoder* MangoHWDecoderRef;
typedef struct MangoTextureOutput* MangoTextureOutputRef;
typedef struct MangoAudioOutput* MangoAudioOutputRef;

// =============================================================================
// 枚举类型
// =============================================================================

typedef enum {
    MANGO_STATE_IDLE = 0,
    MANGO_STATE_INITIALIZING,
    MANGO_STATE_READY,
    MANGO_STATE_PLAYING,
    MANGO_STATE_PAUSED,
    MANGO_STATE_BUFFERING,
    MANGO_STATE_COMPLETED,
    MANGO_STATE_ERROR
} MangoPlayerState;

typedef enum {
    MANGO_ERROR_NONE = 0,
    MANGO_ERROR_INVALID_SOURCE = 1001,
    MANGO_ERROR_NETWORK = 1002,
    MANGO_ERROR_DECODE = 2001,
    MANGO_ERROR_HW_UNAVAILABLE = 2002,
    MANGO_ERROR_RENDER = 3001,
    MANGO_ERROR_AUDIO = 4001,
    MANGO_ERROR_UNKNOWN = 9999
} MangoErrorCode;

typedef enum {
    MANGO_EVENT_STATE_CHANGED = 0,
    MANGO_EVENT_POSITION_CHANGED,
    MANGO_EVENT_BUFFERING_UPDATE,
    MANGO_EVENT_DURATION_CHANGED,
    MANGO_EVENT_VIDEO_SIZE_CHANGED,
    MANGO_EVENT_FIRST_FRAME,
    MANGO_EVENT_SEEK_COMPLETED,
    MANGO_EVENT_COMPLETED,
    MANGO_EVENT_ERROR,
    MANGO_EVENT_PERFORMANCE
} MangoEventType;

// =============================================================================
// 结构体类型
// =============================================================================

typedef struct {
    int64_t duration_ms;
    int width;
    int height;
    double frame_rate;
    int audio_channels;
    int audio_sample_rate;
    const char* video_codec;
    const char* audio_codec;
    int64_t bitrate;
} MangoMediaInfo;

typedef struct {
    double fps;
    int64_t decode_latency_ms;
    int64_t render_latency_ms;
    int dropped_frames;
} MangoPerformanceMetrics;

typedef struct {
    MangoEventType type;
    MangoPlayerState state;
    int64_t position_ms;
    double buffering_percent;
    MangoErrorCode error_code;
    const char* error_message;
    int video_width;
    int video_height;
    MangoPerformanceMetrics metrics;
} MangoPlayerEvent;

// =============================================================================
// 回调类型
// =============================================================================

typedef void (*MangoEventCallback)(const MangoPlayerEvent* event, void* user_data);

// =============================================================================
// 播放器生命周期
// =============================================================================

/**
 * 创建播放器实例
 * @param hw_decoder 硬件解码器 (可为 NULL)
 * @param texture_output 纹理输出 (必需)
 * @param audio_output 音频输出 (可为 NULL)
 * @return 播放器句柄
 */
MangoPlayerRef mango_player_create(
    MangoHWDecoderRef hw_decoder,
    MangoTextureOutputRef texture_output,
    MangoAudioOutputRef audio_output
);

/**
 * 销毁播放器实例
 */
void mango_player_destroy(MangoPlayerRef player);

/**
 * 初始化播放器
 * @param player 播放器句柄
 * @param uri 媒体 URI
 * @param headers HTTP 头部 (可为 NULL)
 * @param texture_registry Flutter TextureRegistry 句柄
 * @return 是否成功
 */
bool mango_player_initialize(
    MangoPlayerRef player,
    const char* uri,
    const char* headers,
    void* texture_registry
);

/**
 * 释放播放器资源
 */
void mango_player_release(MangoPlayerRef player);

// =============================================================================
// 播放控制
// =============================================================================

void mango_player_play(MangoPlayerRef player);
void mango_player_pause(MangoPlayerRef player);
void mango_player_stop(MangoPlayerRef player);
void mango_player_seek(MangoPlayerRef player, int64_t position_ms);
void mango_player_set_speed(MangoPlayerRef player, double speed);
void mango_player_set_volume(MangoPlayerRef player, double volume);
void mango_player_set_mute(MangoPlayerRef player, bool mute);
void mango_player_set_loop(MangoPlayerRef player, bool loop);

// =============================================================================
// 状态查询
// =============================================================================

MangoPlayerState mango_player_get_state(MangoPlayerRef player);
int64_t mango_player_get_position(MangoPlayerRef player);
int64_t mango_player_get_duration(MangoPlayerRef player);
double mango_player_get_volume(MangoPlayerRef player);
bool mango_player_is_muted(MangoPlayerRef player);
int64_t mango_player_get_texture_id(MangoPlayerRef player);

/**
 * 获取媒体信息
 * @param player 播放器句柄
 * @param out_info 输出的媒体信息
 * @return 是否成功
 */
bool mango_player_get_media_info(MangoPlayerRef player, MangoMediaInfo* out_info);

// =============================================================================
// 事件监听
// =============================================================================

/**
 * 设置事件回调
 * @param player 播放器句柄
 * @param callback 回调函数
 * @param user_data 用户数据 (将传递给回调)
 */
void mango_player_set_event_callback(
    MangoPlayerRef player,
    MangoEventCallback callback,
    void* user_data
);

// =============================================================================
// 平台实现工厂函数 (各平台在自己的代码中实现)
// =============================================================================

// macOS/iOS: 在 Swift/ObjC 层实现并传入
// Windows: 在 C++ 层实现
// 这些函数的声明供参考，实际在各平台代码中实现

// MangoHWDecoderRef mango_create_videotoolbox_decoder(void);
// MangoTextureOutputRef mango_create_metal_texture_output(void);
// MangoAudioOutputRef mango_create_avaudioengine_output(void);

#ifdef __cplusplus
}
#endif

#endif // MANGO_PLAYER_C_H
