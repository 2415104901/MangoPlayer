import Foundation
import CoreMedia

/// iOS 性能数据收集器
///
/// 收集 ijkplayer 播放过程中的性能指标，包括：
/// - 帧率 (FPS)
/// - 丢帧数
/// - 解码耗时
/// - 缓冲区状态
public class PerformanceCollector {
    
    // MARK: - Properties
    
    private weak var mediaPlayer: IJKFFMoviePlayerController?
    private var timer: Timer?
    private var isCollecting = false
    
    // 帧率计算
    private var frameCount: Int64 = 0
    private var lastFpsCalcTime: CFAbsoluteTime = 0
    private var currentFps: Double = 0
    
    // 丢帧统计
    private var droppedFrames: Int64 = 0
    private var decodedFrames: Int64 = 0
    
    // 解码耗时
    private var videoDecodeTimeMs: Double = 0
    private var audioDecodeTimeMs: Double = 0
    private var renderTimeMs: Double = 0
    
    // 采样配置
    private var sampleIntervalMs: Int = 1000
    private var collectBandwidth = true
    private var collectBitrate = true
    
    // 回调
    public var callback: PerformanceCallback?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// 绑定播放器
    public func attach(player: IJKFFMoviePlayerController) {
        mediaPlayer = player
    }
    
    /// 解绑播放器
    public func detach() {
        stop()
        mediaPlayer = nil
    }
    
    /// 配置采样参数
    public func configure(
        sampleIntervalMs: Int = 1000,
        collectBandwidth: Bool = true,
        collectBitrate: Bool = true
    ) {
        self.sampleIntervalMs = sampleIntervalMs
        self.collectBandwidth = collectBandwidth
        self.collectBitrate = collectBitrate
    }
    
    /// 开始收集
    public func start() {
        guard !isCollecting else { return }
        isCollecting = true
        
        lastFpsCalcTime = CFAbsoluteTimeGetCurrent()
        frameCount = 0
        
        scheduleCollection()
    }
    
    /// 停止收集
    public func stop() {
        isCollecting = false
        timer?.invalidate()
        timer = nil
    }
    
    /// 记录一帧
    public func onFrameRendered() {
        frameCount += 1
    }
    
    /// 记录丢帧
    public func onFrameDropped() {
        droppedFrames += 1
    }
    
    /// 记录解码完成
    public func onFrameDecoded(videoTimeMs: Double, audioTimeMs: Double) {
        decodedFrames += 1
        videoDecodeTimeMs = videoTimeMs
        audioDecodeTimeMs = audioTimeMs
    }
    
    /// 记录渲染耗时
    public func onRenderComplete(timeMs: Double) {
        renderTimeMs = timeMs
    }
    
    /// 获取当前性能指标
    public func getMetrics() -> PerformanceMetrics {
        // 计算帧率
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastFpsCalcTime
        if elapsed > 0 {
            currentFps = Double(frameCount) / elapsed
        }
        
        // 从 ijkplayer 获取额外信息
        var bufferLengthMs = 0
        var videoBitrate: Int?
        var audioBitrate: Int?
        var width: Int?
        var height: Int?
        var isHardwareDecoding = false
        var bandwidthBps: Int?
        
        if let player = mediaPlayer {
            // 获取视频信息
            let videoSize = player.naturalSize
            width = Int(videoSize.width)
            height = Int(videoSize.height)
            
            // 获取缓冲信息
            if let monitor = player.monitor {
                let videoCachedDuration = monitor.videoCachedDuration
                let audioCachedDuration = monitor.audioCachedDuration
                bufferLengthMs = Int(max(videoCachedDuration, audioCachedDuration) * 1000)
                
                // 获取解码器信息
                isHardwareDecoding = player.isVideoToolboxOpen
                
                // 获取码率信息
                if collectBitrate {
                    videoBitrate = Int(monitor.tcpSpeed)
                }
                
                // 获取带宽估计
                if collectBandwidth {
                    bandwidthBps = Int(monitor.tcpSpeed)
                }
            }
        }
        
        return PerformanceMetrics(
            frameRate: currentFps,
            droppedFrames: Int(droppedFrames),
            decodedFrames: Int(decodedFrames),
            videoDecodeTimeMs: videoDecodeTimeMs,
            audioDecodeTimeMs: audioDecodeTimeMs,
            renderTimeMs: renderTimeMs,
            bufferLengthMs: bufferLengthMs,
            bandwidthBps: bandwidthBps,
            isHardwareDecoding: isHardwareDecoding,
            videoBitrate: videoBitrate,
            audioBitrate: audioBitrate,
            width: width,
            height: height
        )
    }
    
    /// 转换为 Dictionary（用于 Platform Channel）
    public func getMetricsMap() -> [String: Any?] {
        return getMetrics().toMap()
    }
    
    // MARK: - Private Methods
    
    private func scheduleCollection() {
        guard isCollecting else { return }
        
        let interval = TimeInterval(sampleIntervalMs) / 1000.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isCollecting else { return }
            
            let metrics = self.getMetrics()
            self.callback?.onPerformanceUpdate(metrics: metrics)
            
            // 重置帧计数
            self.frameCount = 0
            self.lastFpsCalcTime = CFAbsoluteTimeGetCurrent()
        }
    }
}

// MARK: - PerformanceCallback Protocol

public protocol PerformanceCallback: AnyObject {
    func onPerformanceUpdate(metrics: PerformanceMetrics)
}

// MARK: - PerformanceMetrics

public struct PerformanceMetrics {
    public let frameRate: Double
    public let droppedFrames: Int
    public let decodedFrames: Int
    public let videoDecodeTimeMs: Double
    public let audioDecodeTimeMs: Double
    public let renderTimeMs: Double
    public let bufferLengthMs: Int
    public let bandwidthBps: Int?
    public let isHardwareDecoding: Bool
    public let videoBitrate: Int?
    public let audioBitrate: Int?
    public let width: Int?
    public let height: Int?
    
    public func toMap() -> [String: Any?] {
        return [
            "frameRate": frameRate,
            "droppedFrames": droppedFrames,
            "decodedFrames": decodedFrames,
            "videoDecodeTimeMs": videoDecodeTimeMs,
            "audioDecodeTimeMs": audioDecodeTimeMs,
            "renderTimeMs": renderTimeMs,
            "bufferLengthMs": bufferLengthMs,
            "bandwidthBps": bandwidthBps,
            "isHardwareDecoding": isHardwareDecoding,
            "videoBitrate": videoBitrate,
            "audioBitrate": audioBitrate,
            "width": width,
            "height": height
        ]
    }
}

// MARK: - IJKFFMoviePlayerController Extensions (Placeholder)

/// 这是一个占位类型声明，实际项目中应使用真实的 IJKFFMoviePlayerController
/// 这里仅作为编译时的类型占位
#if !IJKPLAYER_AVAILABLE
public class IJKFFMoviePlayerController: NSObject {
    public var naturalSize: CGSize { return .zero }
    public var isVideoToolboxOpen: Bool { return false }
    public var monitor: IJKFFMonitor? { return nil }
}

public class IJKFFMonitor: NSObject {
    public var videoCachedDuration: Double { return 0 }
    public var audioCachedDuration: Double { return 0 }
    public var tcpSpeed: Double { return 0 }
}
#endif
