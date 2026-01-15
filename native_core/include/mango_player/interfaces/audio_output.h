/**
 * MangoPlayer Native Core - Audio Output Interface
 * 
 * 音频输出抽象接口
 * 各平台实现: AVAudioEngine (macOS/iOS), WASAPI (Windows), AudioTrack (Android)
 */

#pragma once

#include "../types.h"
#include <cstdint>

namespace mango_player {

/**
 * 音频输出抽象接口
 * 
 * 平台实现:
 * - macOS/iOS: AVAudioEngineOutput (AVAudioEngine)
 * - Windows: WASAPIAudioOutput (WASAPI)
 * - Android: AudioTrackOutput (AudioTrack)
 */
class IAudioOutput {
public:
    virtual ~IAudioOutput() = default;

    /**
     * 初始化音频输出
     * @param sample_rate 采样率 (如 44100, 48000)
     * @param channels 声道数 (1=单声道, 2=立体声)
     * @param bits_per_sample 位深度 (如 16, 32)
     * @return true 如果初始化成功
     */
    virtual bool Initialize(int sample_rate, int channels, int bits_per_sample) = 0;

    /**
     * 写入音频数据
     * @param data PCM 音频数据
     * @param size 数据大小 (字节)
     * @param pts_ms 时间戳 (毫秒)
     * @return 实际写入的字节数，-1 表示错误
     */
    virtual int Write(const uint8_t* data, int size, int64_t pts_ms) = 0;

    /**
     * 开始播放
     */
    virtual void Start() = 0;

    /**
     * 暂停播放
     */
    virtual void Pause() = 0;

    /**
     * 恢复播放
     */
    virtual void Resume() = 0;

    /**
     * 停止播放并清空缓冲区
     */
    virtual void Stop() = 0;

    /**
     * 清空音频缓冲区 (用于 seek)
     */
    virtual void Flush() = 0;

    /**
     * 设置音量
     * @param volume 音量值 (0.0 - 1.0)
     */
    virtual void SetVolume(float volume) = 0;

    /**
     * 获取当前音量
     */
    virtual float GetVolume() const = 0;

    /**
     * 设置静音
     */
    virtual void SetMute(bool mute) = 0;

    /**
     * 获取静音状态
     */
    virtual bool IsMuted() const = 0;

    /**
     * 获取当前播放位置 (基于已播放的样本数)
     * 用于 AV 同步
     */
    virtual int64_t GetCurrentPositionMs() const = 0;

    /**
     * 获取缓冲区延迟
     * @return 缓冲区中待播放的数据时长 (毫秒)
     */
    virtual int64_t GetBufferedDurationMs() const = 0;

    /**
     * 释放所有资源
     */
    virtual void Release() = 0;
};

/**
 * 空音频输出实现 (占位符，用于测试或静音模式)
 */
class NullAudioOutput : public IAudioOutput {
public:
    bool Initialize(int, int, int) override { return true; }
    int Write(const uint8_t*, int size, int64_t) override { return size; }
    void Start() override {}
    void Pause() override {}
    void Resume() override {}
    void Stop() override {}
    void Flush() override {}
    void SetVolume(float) override {}
    float GetVolume() const override { return 1.0f; }
    void SetMute(bool) override {}
    bool IsMuted() const override { return false; }
    int64_t GetCurrentPositionMs() const override { return 0; }
    int64_t GetBufferedDurationMs() const override { return 0; }
    void Release() override {}
};

} // namespace mango_player
