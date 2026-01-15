#ifndef PERFORMANCE_COLLECTOR_H_
#define PERFORMANCE_COLLECTOR_H_

#include <atomic>
#include <chrono>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <variant>

namespace mango_player {

/// 性能指标数据结构
struct PerformanceMetrics {
    double frame_rate = 0.0;
    int dropped_frames = 0;
    int decoded_frames = 0;
    double video_decode_time_ms = 0.0;
    double audio_decode_time_ms = 0.0;
    double render_time_ms = 0.0;
    int buffer_length_ms = 0;
    int bandwidth_bps = 0;
    bool is_hardware_decoding = false;
    int video_bitrate = 0;
    int audio_bitrate = 0;
    int width = 0;
    int height = 0;
    
    /// 转换为 Flutter 可用的 Map
    std::map<std::string, std::variant<double, int, bool>> ToMap() const {
        return {
            {"frameRate", frame_rate},
            {"droppedFrames", dropped_frames},
            {"decodedFrames", decoded_frames},
            {"videoDecodeTimeMs", video_decode_time_ms},
            {"audioDecodeTimeMs", audio_decode_time_ms},
            {"renderTimeMs", render_time_ms},
            {"bufferLengthMs", buffer_length_ms},
            {"bandwidthBps", bandwidth_bps},
            {"isHardwareDecoding", is_hardware_decoding},
            {"videoBitrate", video_bitrate},
            {"audioBitrate", audio_bitrate},
            {"width", width},
            {"height", height}
        };
    }
};

/// 性能回调接口
class PerformanceCallback {
public:
    virtual ~PerformanceCallback() = default;
    virtual void OnPerformanceUpdate(const PerformanceMetrics& metrics) = 0;
};

/// Windows 性能数据收集器
///
/// 收集 FFmpeg 播放过程中的性能指标，包括：
/// - 帧率 (FPS)
/// - 丢帧数
/// - 解码耗时
/// - 缓冲区状态
class PerformanceCollector {
public:
    PerformanceCollector();
    ~PerformanceCollector();
    
    /// 配置采样参数
    void Configure(int sample_interval_ms = 1000,
                   bool collect_bandwidth = true,
                   bool collect_bitrate = true);
    
    /// 设置性能回调
    void SetCallback(std::shared_ptr<PerformanceCallback> callback);
    
    /// 开始收集
    void Start();
    
    /// 停止收集
    void Stop();
    
    /// 记录一帧渲染
    void OnFrameRendered();
    
    /// 记录丢帧
    void OnFrameDropped();
    
    /// 记录解码完成
    void OnFrameDecoded(double video_time_ms, double audio_time_ms);
    
    /// 记录渲染耗时
    void OnRenderComplete(double time_ms);
    
    /// 设置视频尺寸
    void SetVideoSize(int width, int height);
    
    /// 设置硬件解码状态
    void SetHardwareDecoding(bool enabled);
    
    /// 设置缓冲区长度
    void SetBufferLength(int buffer_ms);
    
    /// 设置码率
    void SetBitrate(int video_bps, int audio_bps);
    
    /// 设置带宽
    void SetBandwidth(int bandwidth_bps);
    
    /// 获取当前性能指标
    PerformanceMetrics GetMetrics();
    
    /// 获取性能指标 Map（用于 Platform Channel）
    std::map<std::string, std::variant<double, int, bool>> GetMetricsMap();

private:
    void CollectionLoop();
    
    std::atomic<bool> is_collecting_{false};
    std::thread collection_thread_;
    std::mutex metrics_mutex_;
    
    // 采样配置
    int sample_interval_ms_ = 1000;
    bool collect_bandwidth_ = true;
    bool collect_bitrate_ = true;
    
    // 帧率计算
    std::atomic<int64_t> frame_count_{0};
    std::chrono::steady_clock::time_point last_fps_calc_time_;
    double current_fps_ = 0.0;
    
    // 丢帧统计
    std::atomic<int64_t> dropped_frames_{0};
    std::atomic<int64_t> decoded_frames_{0};
    
    // 解码耗时
    std::atomic<double> video_decode_time_ms_{0.0};
    std::atomic<double> audio_decode_time_ms_{0.0};
    std::atomic<double> render_time_ms_{0.0};
    
    // 视频信息
    std::atomic<int> width_{0};
    std::atomic<int> height_{0};
    std::atomic<bool> is_hardware_decoding_{false};
    
    // 缓冲和码率
    std::atomic<int> buffer_length_ms_{0};
    std::atomic<int> video_bitrate_{0};
    std::atomic<int> audio_bitrate_{0};
    std::atomic<int> bandwidth_bps_{0};
    
    // 回调
    std::weak_ptr<PerformanceCallback> callback_;
};

}  // namespace mango_player

#endif  // PERFORMANCE_COLLECTOR_H_
