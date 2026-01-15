/**
 * MangoPlayer Native Core - FFmpeg Demuxer
 * 
 * FFmpeg 解复用器 - 100% 跨平台代码
 * 负责打开媒体文件/流，读取音视频数据包
 */

#pragma once

#include "types.h"
#include <string>
#include <memory>

// Forward declarations for FFmpeg types
struct AVFormatContext;
struct AVPacket;
struct AVCodecContext;
struct AVCodecParameters;

namespace mango_player {

/**
 * FFmpeg 解复用器
 * 
 * 此类为 100% 跨平台实现，不包含任何平台特定代码
 * 
 * 使用示例:
 * ```cpp
 * Demuxer demuxer;
 * if (demuxer.Open("video.mp4")) {
 *     auto info = demuxer.GetMediaInfo();
 *     while (auto pkt = demuxer.ReadPacket()) {
 *         if (demuxer.IsVideoPacket(pkt)) { ... }
 *         demuxer.FreePacket(pkt);
 *     }
 * }
 * ```
 */
class Demuxer {
public:
    Demuxer();
    ~Demuxer();

    // 禁用拷贝
    Demuxer(const Demuxer&) = delete;
    Demuxer& operator=(const Demuxer&) = delete;

    // 允许移动
    Demuxer(Demuxer&&) noexcept;
    Demuxer& operator=(Demuxer&&) noexcept;

    /**
     * 打开媒体源
     * @param uri 文件路径或网络 URL
     * @param headers HTTP 头部 (可选，用于网络流)
     * @return true 如果打开成功
     */
    bool Open(const std::string& uri, const std::string& headers = "");

    /**
     * 关闭媒体源并释放资源
     */
    void Close();

    /**
     * 读取下一个数据包
     * @return 数据包指针，到达文件末尾或出错返回 nullptr
     *         调用者需要通过 FreePacket() 释放
     */
    AVPacket* ReadPacket();

    /**
     * 释放数据包
     * @param pkt 要释放的数据包
     */
    void FreePacket(AVPacket* pkt);

    /**
     * 跳转到指定位置
     * @param position_ms 目标位置 (毫秒)
     * @return true 如果跳转成功
     */
    bool Seek(int64_t position_ms);

    /**
     * 检查数据包是否为视频流
     */
    bool IsVideoPacket(const AVPacket* pkt) const;

    /**
     * 检查数据包是否为音频流
     */
    bool IsAudioPacket(const AVPacket* pkt) const;

    /**
     * 获取媒体信息
     */
    MediaInfo GetMediaInfo() const;

    /**
     * 获取视频流索引
     */
    int GetVideoStreamIndex() const { return video_stream_index_; }

    /**
     * 获取音频流索引
     */
    int GetAudioStreamIndex() const { return audio_stream_index_; }

    /**
     * 获取视频编解码器参数 (用于初始化解码器)
     */
    AVCodecParameters* GetVideoCodecParams() const;

    /**
     * 获取音频编解码器参数
     */
    AVCodecParameters* GetAudioCodecParams() const;

    /**
     * 是否已打开
     */
    bool IsOpened() const { return format_ctx_ != nullptr; }

    /**
     * 是否到达文件末尾
     */
    bool IsEOF() const { return eof_reached_; }

private:
    AVFormatContext* format_ctx_ = nullptr;
    int video_stream_index_ = -1;
    int audio_stream_index_ = -1;
    bool eof_reached_ = false;

    // 用于 seek 时跳过旧包
    int64_t seek_target_pts_ = -1;

    // 媒体信息缓存
    mutable MediaInfo media_info_;
    mutable bool media_info_cached_ = false;

    void FindStreams();
    void CacheMediaInfo() const;
};

} // namespace mango_player
