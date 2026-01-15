#include "performance_collector.h"

#include <algorithm>

namespace mango_player {

PerformanceCollector::PerformanceCollector() {
    last_fps_calc_time_ = std::chrono::steady_clock::now();
}

PerformanceCollector::~PerformanceCollector() {
    Stop();
}

void PerformanceCollector::Configure(int sample_interval_ms,
                                      bool collect_bandwidth,
                                      bool collect_bitrate) {
    sample_interval_ms_ = sample_interval_ms;
    collect_bandwidth_ = collect_bandwidth;
    collect_bitrate_ = collect_bitrate;
}

void PerformanceCollector::SetCallback(std::shared_ptr<PerformanceCallback> callback) {
    callback_ = callback;
}

void PerformanceCollector::Start() {
    if (is_collecting_.exchange(true)) {
        return;  // Already collecting
    }
    
    last_fps_calc_time_ = std::chrono::steady_clock::now();
    frame_count_ = 0;
    
    collection_thread_ = std::thread(&PerformanceCollector::CollectionLoop, this);
}

void PerformanceCollector::Stop() {
    is_collecting_ = false;
    
    if (collection_thread_.joinable()) {
        collection_thread_.join();
    }
}

void PerformanceCollector::OnFrameRendered() {
    frame_count_++;
}

void PerformanceCollector::OnFrameDropped() {
    dropped_frames_++;
}

void PerformanceCollector::OnFrameDecoded(double video_time_ms, double audio_time_ms) {
    decoded_frames_++;
    video_decode_time_ms_ = video_time_ms;
    audio_decode_time_ms_ = audio_time_ms;
}

void PerformanceCollector::OnRenderComplete(double time_ms) {
    render_time_ms_ = time_ms;
}

void PerformanceCollector::SetVideoSize(int width, int height) {
    width_ = width;
    height_ = height;
}

void PerformanceCollector::SetHardwareDecoding(bool enabled) {
    is_hardware_decoding_ = enabled;
}

void PerformanceCollector::SetBufferLength(int buffer_ms) {
    buffer_length_ms_ = buffer_ms;
}

void PerformanceCollector::SetBitrate(int video_bps, int audio_bps) {
    video_bitrate_ = video_bps;
    audio_bitrate_ = audio_bps;
}

void PerformanceCollector::SetBandwidth(int bandwidth_bps) {
    bandwidth_bps_ = bandwidth_bps;
}

PerformanceMetrics PerformanceCollector::GetMetrics() {
    std::lock_guard<std::mutex> lock(metrics_mutex_);
    
    // 计算帧率
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        now - last_fps_calc_time_).count();
    
    if (elapsed > 0) {
        current_fps_ = static_cast<double>(frame_count_) * 1000.0 / elapsed;
    }
    
    PerformanceMetrics metrics;
    metrics.frame_rate = current_fps_;
    metrics.dropped_frames = static_cast<int>(dropped_frames_.load());
    metrics.decoded_frames = static_cast<int>(decoded_frames_.load());
    metrics.video_decode_time_ms = video_decode_time_ms_;
    metrics.audio_decode_time_ms = audio_decode_time_ms_;
    metrics.render_time_ms = render_time_ms_;
    metrics.buffer_length_ms = buffer_length_ms_;
    metrics.is_hardware_decoding = is_hardware_decoding_;
    metrics.width = width_;
    metrics.height = height_;
    
    if (collect_bitrate_) {
        metrics.video_bitrate = video_bitrate_;
        metrics.audio_bitrate = audio_bitrate_;
    }
    
    if (collect_bandwidth_) {
        metrics.bandwidth_bps = bandwidth_bps_;
    }
    
    return metrics;
}

std::map<std::string, std::variant<double, int, bool>> PerformanceCollector::GetMetricsMap() {
    return GetMetrics().ToMap();
}

void PerformanceCollector::CollectionLoop() {
    while (is_collecting_) {
        std::this_thread::sleep_for(std::chrono::milliseconds(sample_interval_ms_));
        
        if (!is_collecting_) break;
        
        auto metrics = GetMetrics();
        
        // 重置帧计数
        frame_count_ = 0;
        last_fps_calc_time_ = std::chrono::steady_clock::now();
        
        // 调用回调
        if (auto callback = callback_.lock()) {
            callback->OnPerformanceUpdate(metrics);
        }
    }
}

}  // namespace mango_player
