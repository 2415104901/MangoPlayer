import Foundation
import CoreMedia
import AVFoundation

/// macOS 性能数据收集器
///
/// 收集 FFmpeg/AVFoundation 播放过程中的性能指标，包括：
/// - 帧率 (FPS)
/// - 丢帧数
/// - 解码耗时
/// - 缓冲区状态
public class PerformanceCollector {
    
    // MARK: - Properties
    
    private var timer: Timer?
    private var isCollecting = false
    
    // 帧率计算
    private var frameCount: Int64 = 0
    private var lastFpsCalcTime: CFAbsoluteTime = 0
    private var currentFps: Double = 0
    private let frameCountLock = NSLock()
    
    // 丢帧统计
    private var droppedFrames: Int64 = 0
    private var decodedFrames: Int64 = 0
    
    // 解码耗时
    private var videoDecodeTimeMs: Double = 0
    private var audioDecodeTimeMs: Double = 0
    private var renderTimeMs: Double = 0
    
    // 视频信息
    private var width: Int = 0
    private var height: Int = 0
    private var isHardwareDecoding: Bool = false
    
    // 缓冲和码率
    private var bufferLengthMs: Int = 0
    private var videoBitrate: Int = 0
    private var audioBitrate: Int = 0
    private var bandwidthBps: Int = 0
    
    // 采样配置
    private var sampleIntervalMs: Int = 1000
    private var collectBandwidth = true
    private var collectBitrate = true
    
    // 回调
    public var callback: PerformanceCallback?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
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
        frameCountLock.lock()
        frameCount += 1
        frameCountLock.unlock()
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
    
    /// 设置视频尺寸
    public func setVideoSize(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    /// 设置硬件解码状态
    public func setHardwareDecoding(_ enabled: Bool) {
        isHardwareDecoding = enabled
    }
    
    /// 设置缓冲区长度
    public func setBufferLength(_ bufferMs: Int) {
        bufferLengthMs = bufferMs
    }
    
    /// 设置码率
    public func setBitrate(videoBps: Int, audioBps: Int) {
        videoBitrate = videoBps
        audioBitrate = audioBps
    }
    
    /// 设置带宽
    public func setBandwidth(_ bandwidthBps: Int) {
        self.bandwidthBps = bandwidthBps
    }
    
    /// 获取当前性能指标
    public func getMetrics() -> PerformanceMetrics {
        // 计算帧率
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastFpsCalcTime
        
        frameCountLock.lock()
        let currentFrameCount = frameCount
        frameCountLock.unlock()
        
        if elapsed > 0 {
            currentFps = Double(currentFrameCount) / elapsed
        }
        
        return PerformanceMetrics(
            frameRate: currentFps,
            droppedFrames: Int(droppedFrames),
            decodedFrames: Int(decodedFrames),
            videoDecodeTimeMs: videoDecodeTimeMs,
            audioDecodeTimeMs: audioDecodeTimeMs,
            renderTimeMs: renderTimeMs,
            bufferLengthMs: bufferLengthMs,
            bandwidthBps: collectBandwidth ? bandwidthBps : nil,
            isHardwareDecoding: isHardwareDecoding,
            videoBitrate: collectBitrate ? videoBitrate : nil,
            audioBitrate: collectBitrate ? audioBitrate : nil,
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
            self.frameCountLock.lock()
            self.frameCount = 0
            self.frameCountLock.unlock()
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
    
    public init(
        frameRate: Double,
        droppedFrames: Int,
        decodedFrames: Int,
        videoDecodeTimeMs: Double,
        audioDecodeTimeMs: Double,
        renderTimeMs: Double,
        bufferLengthMs: Int,
        bandwidthBps: Int?,
        isHardwareDecoding: Bool,
        videoBitrate: Int?,
        audioBitrate: Int?,
        width: Int?,
        height: Int?
    ) {
        self.frameRate = frameRate
        self.droppedFrames = droppedFrames
        self.decodedFrames = decodedFrames
        self.videoDecodeTimeMs = videoDecodeTimeMs
        self.audioDecodeTimeMs = audioDecodeTimeMs
        self.renderTimeMs = renderTimeMs
        self.bufferLengthMs = bufferLengthMs
        self.bandwidthBps = bandwidthBps
        self.isHardwareDecoding = isHardwareDecoding
        self.videoBitrate = videoBitrate
        self.audioBitrate = audioBitrate
        self.width = width
        self.height = height
    }
    
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
    
    /// 性能等级
    public var level: PerformanceLevel {
        let dropRate = decodedFrames > 0 ? Double(droppedFrames) / Double(decodedFrames + droppedFrames) : 0
        if dropRate >= 0.05 {
            return .critical
        } else if dropRate >= 0.01 {
            return .warning
        } else {
            return .healthy
        }
    }
}

// MARK: - PerformanceLevel

public enum PerformanceLevel {
    case healthy   // 丢帧率 < 1%
    case warning   // 丢帧率 1% - 5%
    case critical  // 丢帧率 >= 5%
}
