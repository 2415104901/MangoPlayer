/**
 * MangoPlayer Native Core - Player Core
 * 
 * 播放器核心控制类 - 组合所有模块
 * 100% 跨平台逻辑，通过接口调用平台实现
 */

#pragma once

#include "types.h"
#include "demuxer.h"
#include "soft_decoder.h"
#include "clock_sync.h"
#include "event_bridge.h"
#include "interfaces/hw_decoder.h"
#include "interfaces/texture_output.h"
#include "interfaces/audio_output.h"

#include <memory>
#include <string>
#include <thread>
#include <atomic>
#include <condition_variable>

namespace mango_player {

/**
 * 播放器配置
 */
struct PlayerConfig {
    bool enable_hardware_decode = true;   // 启用硬件解码
    bool enable_audio = true;             // 启用音频
    int buffer_size_ms = 2000;            // 缓冲区大小 (毫秒)
    SyncStrategy sync_strategy = SyncStrategy::AudioMaster;
    double initial_volume = 1.0;          // 初始音量
    bool loop = false;                    // 循环播放
};

/**
 * 播放器核心
 * 
 * 此类为播放器的核心控制器，组合所有模块:
 * - Demuxer: 解复用 (100% 跨平台)
 * - SoftDecoder: 软解码 (100% 跨平台)
 * - ClockSync: 音视频同步 (100% 跨平台)
 * - EventBridge: 事件桥接 (100% 跨平台)
 * - IHardwareDecoder: 硬件解码 (平台实现)
 * - ITextureOutput: 纹理输出 (平台实现)
 * - IAudioOutput: 音频输出 (平台实现)
 * 
 * 使用示例:
 * ```cpp
 * // 创建播放器，注入平台实现
 * auto player = std::make_unique<PlayerCore>(
 *     std::make_unique<VideoToolboxDecoder>(),
 *     std::make_unique<MetalTextureOutput>(),
 *     std::make_unique<AVAudioEngineOutput>()
 * );
 * 
 * // 设置事件监听
 * player->GetEventBridge().AddListener([](const PlayerEvent& e) {
 *     // 处理事件
 * });
 * 
 * // 初始化并播放
 * if (player->Initialize("video.mp4")) {
 *     player->Play();
 * }
 * ```
 */
class PlayerCore {
public:
    /**
     * 构造函数，通过依赖注入接收平台实现
     * @param hw_decoder 硬件解码器实现 (可为 nullptr，将使用软解)
     * @param texture_output 纹理输出实现 (必需)
     * @param audio_output 音频输出实现 (可为 nullptr，静音模式)
     * @param config 播放器配置
     */
    PlayerCore(
        std::unique_ptr<IHardwareDecoder> hw_decoder,
        std::unique_ptr<ITextureOutput> texture_output,
        std::unique_ptr<IAudioOutput> audio_output,
        const PlayerConfig& config = PlayerConfig()
    );

    ~PlayerCore();

    // 禁用拷贝
    PlayerCore(const PlayerCore&) = delete;
    PlayerCore& operator=(const PlayerCore&) = delete;

    // =========================================================================
    // 初始化与生命周期
    // =========================================================================

    /**
     * 初始化播放器
     * @param uri 媒体源 URI (文件路径或网络 URL)
     * @param headers HTTP 头部 (可选)
     * @param texture_registry_handle Flutter TextureRegistry 句柄
     * @return true 如果初始化成功
     */
    bool Initialize(const std::string& uri, 
                    const std::string& headers = "",
                    void* texture_registry_handle = nullptr);

    /**
     * 释放播放器资源
     */
    void Release();

    // =========================================================================
    // 播放控制
    // =========================================================================

    void Play();
    void Pause();
    void Stop();
    
    /**
     * 跳转到指定位置
     * @param position_ms 目标位置 (毫秒)
     */
    void Seek(int64_t position_ms);

    /**
     * 设置播放速度
     * @param speed 播放速度 (0.5 - 2.0)
     */
    void SetSpeed(double speed);

    /**
     * 设置音量
     * @param volume 音量 (0.0 - 1.0)
     */
    void SetVolume(double volume);

    /**
     * 设置静音
     */
    void SetMute(bool mute);

    /**
     * 设置循环播放
     */
    void SetLoop(bool loop);

    // =========================================================================
    // 状态查询
    // =========================================================================

    PlayerState GetState() const { return state_.load(); }
    int64_t GetPosition() const;
    int64_t GetDuration() const;
    double GetVolume() const;
    bool IsMuted() const;
    bool IsPlaying() const { return state_ == PlayerState::Playing; }
    MediaInfo GetMediaInfo() const;
    int64_t GetTextureId() const;

    // =========================================================================
    // 事件系统
    // =========================================================================

    /**
     * 获取事件桥接器 (用于注册监听器)
     */
    EventBridge& GetEventBridge() { return event_bridge_; }
    const EventBridge& GetEventBridge() const { return event_bridge_; }

private:
    // 配置
    PlayerConfig config_;

    // 跨平台模块
    std::unique_ptr<Demuxer> demuxer_;
    std::unique_ptr<SoftDecoder> video_soft_decoder_;
    std::unique_ptr<SoftDecoder> audio_decoder_;
    std::unique_ptr<ClockSync> clock_sync_;
    EventBridge event_bridge_;

    // 平台实现 (通过依赖注入)
    std::unique_ptr<IHardwareDecoder> hw_decoder_;
    std::unique_ptr<ITextureOutput> texture_output_;
    std::unique_ptr<IAudioOutput> audio_output_;

    // 状态
    std::atomic<PlayerState> state_{PlayerState::Idle};
    std::atomic<bool> use_hw_decoder_{false};
    std::atomic<double> volume_{1.0};
    std::atomic<bool> muted_{false};
    std::atomic<bool> loop_{false};

    // 线程
    std::unique_ptr<std::thread> demux_thread_;
    std::unique_ptr<std::thread> video_decode_thread_;
    std::unique_ptr<std::thread> audio_decode_thread_;
    std::atomic<bool> should_stop_{false};
    std::condition_variable cv_;
    std::mutex mutex_;

    // 线程函数
    void DemuxThreadFunc();
    void VideoDecodeThreadFunc();
    void AudioDecodeThreadFunc();

    // 内部方法
    void SetState(PlayerState new_state);
    bool InitializeDecoders();
    void StartThreads();
    void StopThreads();
};

} // namespace mango_player
