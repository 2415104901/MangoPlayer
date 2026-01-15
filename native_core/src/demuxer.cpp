/**
 * MangoPlayer Native Core - Demuxer Implementation
 * 
 * FFmpeg 解复用器实现 - 100% 跨平台代码
 */

#include "mango_player/demuxer.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/dict.h>
}

#include <cstring>

namespace mango_player {

Demuxer::Demuxer() = default;

Demuxer::~Demuxer() {
    Close();
}

Demuxer::Demuxer(Demuxer&& other) noexcept
    : format_ctx_(other.format_ctx_)
    , video_stream_index_(other.video_stream_index_)
    , audio_stream_index_(other.audio_stream_index_)
    , eof_reached_(other.eof_reached_)
    , seek_target_pts_(other.seek_target_pts_)
    , media_info_(std::move(other.media_info_))
    , media_info_cached_(other.media_info_cached_)
{
    other.format_ctx_ = nullptr;
    other.video_stream_index_ = -1;
    other.audio_stream_index_ = -1;
}

Demuxer& Demuxer::operator=(Demuxer&& other) noexcept {
    if (this != &other) {
        Close();
        format_ctx_ = other.format_ctx_;
        video_stream_index_ = other.video_stream_index_;
        audio_stream_index_ = other.audio_stream_index_;
        eof_reached_ = other.eof_reached_;
        seek_target_pts_ = other.seek_target_pts_;
        media_info_ = std::move(other.media_info_);
        media_info_cached_ = other.media_info_cached_;
        
        other.format_ctx_ = nullptr;
        other.video_stream_index_ = -1;
        other.audio_stream_index_ = -1;
    }
    return *this;
}

bool Demuxer::Open(const std::string& uri, const std::string& headers) {
    Close();

    format_ctx_ = avformat_alloc_context();
    if (!format_ctx_) {
        return false;
    }

    // 设置 HTTP 头部 (如果提供)
    AVDictionary* options = nullptr;
    if (!headers.empty()) {
        av_dict_set(&options, "headers", headers.c_str(), 0);
    }

    // 设置超时 (10 秒)
    av_dict_set(&options, "timeout", "10000000", 0);

    // 打开输入
    int ret = avformat_open_input(&format_ctx_, uri.c_str(), nullptr, &options);
    av_dict_free(&options);
    
    if (ret < 0) {
        format_ctx_ = nullptr;
        return false;
    }

    // 查找流信息
    ret = avformat_find_stream_info(format_ctx_, nullptr);
    if (ret < 0) {
        Close();
        return false;
    }

    // 查找视频和音频流
    FindStreams();

    if (video_stream_index_ < 0 && audio_stream_index_ < 0) {
        Close();
        return false;
    }

    eof_reached_ = false;
    media_info_cached_ = false;

    return true;
}

void Demuxer::Close() {
    if (format_ctx_) {
        avformat_close_input(&format_ctx_);
        format_ctx_ = nullptr;
    }
    video_stream_index_ = -1;
    audio_stream_index_ = -1;
    eof_reached_ = false;
    seek_target_pts_ = -1;
    media_info_cached_ = false;
}

void Demuxer::FindStreams() {
    video_stream_index_ = av_find_best_stream(
        format_ctx_, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    
    audio_stream_index_ = av_find_best_stream(
        format_ctx_, AVMEDIA_TYPE_AUDIO, -1, video_stream_index_, nullptr, 0);
}

AVPacket* Demuxer::ReadPacket() {
    if (!format_ctx_ || eof_reached_) {
        return nullptr;
    }

    AVPacket* pkt = av_packet_alloc();
    if (!pkt) {
        return nullptr;
    }

    int ret = av_read_frame(format_ctx_, pkt);
    if (ret < 0) {
        av_packet_free(&pkt);
        if (ret == AVERROR_EOF) {
            eof_reached_ = true;
        }
        return nullptr;
    }

    return pkt;
}

void Demuxer::FreePacket(AVPacket* pkt) {
    if (pkt) {
        av_packet_free(&pkt);
    }
}

bool Demuxer::Seek(int64_t position_ms) {
    if (!format_ctx_) {
        return false;
    }

    // 转换为 AV_TIME_BASE 单位
    int64_t timestamp = position_ms * 1000;  // ms to us
    
    int ret = av_seek_frame(format_ctx_, -1, timestamp, AVSEEK_FLAG_BACKWARD);
    if (ret < 0) {
        return false;
    }

    eof_reached_ = false;
    seek_target_pts_ = position_ms;
    
    return true;
}

bool Demuxer::IsVideoPacket(const AVPacket* pkt) const {
    return pkt && pkt->stream_index == video_stream_index_;
}

bool Demuxer::IsAudioPacket(const AVPacket* pkt) const {
    return pkt && pkt->stream_index == audio_stream_index_;
}

AVCodecParameters* Demuxer::GetVideoCodecParams() const {
    if (!format_ctx_ || video_stream_index_ < 0) {
        return nullptr;
    }
    return format_ctx_->streams[video_stream_index_]->codecpar;
}

AVCodecParameters* Demuxer::GetAudioCodecParams() const {
    if (!format_ctx_ || audio_stream_index_ < 0) {
        return nullptr;
    }
    return format_ctx_->streams[audio_stream_index_]->codecpar;
}

MediaInfo Demuxer::GetMediaInfo() const {
    if (media_info_cached_) {
        return media_info_;
    }
    
    CacheMediaInfo();
    return media_info_;
}

void Demuxer::CacheMediaInfo() const {
    if (!format_ctx_) {
        return;
    }

    media_info_ = MediaInfo{};
    media_info_.duration_ms = format_ctx_->duration / 1000;  // us to ms
    media_info_.bitrate = format_ctx_->bit_rate;

    // 视频信息
    if (video_stream_index_ >= 0) {
        AVStream* video_stream = format_ctx_->streams[video_stream_index_];
        AVCodecParameters* codecpar = video_stream->codecpar;
        
        media_info_.width = codecpar->width;
        media_info_.height = codecpar->height;
        
        if (video_stream->avg_frame_rate.den > 0) {
            media_info_.frame_rate = av_q2d(video_stream->avg_frame_rate);
        }
        
        const AVCodecDescriptor* desc = avcodec_descriptor_get(codecpar->codec_id);
        if (desc) {
            media_info_.video_codec = desc->name;
        }
    }

    // 音频信息
    if (audio_stream_index_ >= 0) {
        AVCodecParameters* codecpar = format_ctx_->streams[audio_stream_index_]->codecpar;
        
        media_info_.audio_channels = codecpar->ch_layout.nb_channels;
        media_info_.audio_sample_rate = codecpar->sample_rate;
        
        const AVCodecDescriptor* desc = avcodec_descriptor_get(codecpar->codec_id);
        if (desc) {
            media_info_.audio_codec = desc->name;
        }
    }

    media_info_cached_ = true;
}

} // namespace mango_player
