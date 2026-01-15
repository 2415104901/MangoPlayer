import Foundation

/// 软解回退处理器 (macOS)
///
/// 当 VideoToolbox 硬件解码失败或不可用时，自动切换到 FFmpeg 软件解码。
/// 提供解码器选择策略和性能监控。
///
/// 任务: T114 [US6]
public class SoftDecodeFallback {
    
    // MARK: - Types
    
    /// 解码器类型
    public enum DecoderType {
        case hardware   // 硬件解码 (VideoToolbox)
        case software   // 软件解码 (FFmpeg)
        case hybrid     // 混合模式
    }
    
    /// 解码器状态
    public struct DecoderStatus {
        let type: DecoderType
        let codecName: String
        let isHardwareAccelerated: Bool
        let fallbackReason: String
        let switchTimestamp: Date
        
        public init(
            type: DecoderType,
            codecName: String = "",
            isHardwareAccelerated: Bool = false,
            fallbackReason: String = "",
            switchTimestamp: Date = Date()
        ) {
            self.type = type
            self.codecName = codecName
            self.isHardwareAccelerated = isHardwareAccelerated
            self.fallbackReason = fallbackReason
            self.switchTimestamp = switchTimestamp
        }
    }
    
    /// 回退策略
    public enum FallbackStrategy {
        case immediate      // 立即切换
        case graceful       // 优雅切换 (等待当前帧完成)
        case retryOnce      // 重试一次后再切换
        case manual         // 手动控制
    }
    
    /// 性能阈值
    public struct PerformanceThresholds {
        var maxDecodeTimeMs: Double = 50.0      // 最大解码时间
        var maxConsecutiveErrors: Int = 3       // 最大连续错误数
        var minFps: Double = 20.0               // 最低帧率
        var maxFrameDrops: Int = 10             // 最大丢帧数
        
        public init(
            maxDecodeTimeMs: Double = 50.0,
            maxConsecutiveErrors: Int = 3,
            minFps: Double = 20.0,
            maxFrameDrops: Int = 10
        ) {
            self.maxDecodeTimeMs = maxDecodeTimeMs
            self.maxConsecutiveErrors = maxConsecutiveErrors
            self.minFps = minFps
            self.maxFrameDrops = maxFrameDrops
        }
    }
    
    /// 状态变更回调
    public typealias StatusCallback = (DecoderStatus) -> Void
    
    // MARK: - Properties
    
    private var strategy: FallbackStrategy = .graceful
    private var thresholds = PerformanceThresholds()
    private var currentStatus = DecoderStatus(type: .hardware, isHardwareAccelerated: true)
    private var statusCallback: StatusCallback?
    
    // 性能统计
    private var consecutiveErrors = 0
    private var recentFrameDrops = 0
    private var avgDecodeTimeMs: Double = 0.0
    private var decodeCount = 0
    
    // 恢复尝试
    private var recoveryAttempts = 0
    private let maxRecoveryAttempts = 3
    
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Configuration
    
    /// 设置回退策略
    public func setFallbackStrategy(_ strategy: FallbackStrategy) {
        lock.lock()
        defer { lock.unlock() }
        self.strategy = strategy
    }
    
    /// 获取当前回退策略
    public func getFallbackStrategy() -> FallbackStrategy {
        lock.lock()
        defer { lock.unlock() }
        return strategy
    }
    
    /// 设置性能阈值
    public func setPerformanceThresholds(_ thresholds: PerformanceThresholds) {
        lock.lock()
        defer { lock.unlock() }
        self.thresholds = thresholds
    }
    
    /// 获取性能阈值
    public func getPerformanceThresholds() -> PerformanceThresholds {
        lock.lock()
        defer { lock.unlock() }
        return thresholds
    }
    
    // MARK: - Error Reporting
    
    /// 报告解码错误
    /// - Parameters:
    ///   - errorCode: 错误码
    ///   - errorMessage: 错误消息
    /// - Returns: 是否应该触发回退
    public func reportDecodeError(errorCode: Int, errorMessage: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        consecutiveErrors += 1
        
        // 检查是否超过阈值
        if consecutiveErrors >= thresholds.maxConsecutiveErrors {
            return true
        }
        
        // 根据策略决定是否回退
        switch strategy {
        case .immediate:
            return true
        case .retryOnce:
            return consecutiveErrors > 1
        case .graceful, .manual:
            return false
        }
    }
    
    /// 报告解码性能指标
    /// - Parameters:
    ///   - decodeTimeMs: 解码耗时（毫秒）
    ///   - frameDropped: 是否丢帧
    public func reportPerformanceMetrics(decodeTimeMs: Double, frameDropped: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        // 更新平均解码时间
        decodeCount += 1
        avgDecodeTimeMs = ((avgDecodeTimeMs * Double(decodeCount - 1)) + decodeTimeMs) / Double(decodeCount)
        
        // 更新丢帧统计
        if frameDropped {
            recentFrameDrops += 1
        }
        
        // 成功解码，重置错误计数
        if !frameDropped && decodeTimeMs < thresholds.maxDecodeTimeMs {
            consecutiveErrors = 0
        }
    }
    
    // MARK: - Fallback Control
    
    /// 检查是否应该触发回退
    public func shouldFallback() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // 已经是软解
        if currentStatus.type == .software {
            return false
        }
        
        return isPerformanceBelowThreshold()
    }
    
    /// 执行回退
    /// - Parameter reason: 回退原因
    public func executeFallback(reason: String) {
        lock.lock()
        defer { lock.unlock() }
        
        updateStatus(type: .software, codecName: "ffmpeg", reason: reason)
        
        // 重置性能统计
        consecutiveErrors = 0
        recentFrameDrops = 0
        avgDecodeTimeMs = 0.0
        decodeCount = 0
    }
    
    /// 尝试恢复到硬件解码
    /// - Returns: 是否成功恢复
    public func tryRecoverToHardware() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // 已经是硬解
        if currentStatus.type == .hardware {
            return true
        }
        
        // 检查恢复尝试次数
        if recoveryAttempts >= maxRecoveryAttempts {
            return false
        }
        
        recoveryAttempts += 1
        
        // 尝试恢复到硬解
        updateStatus(type: .hardware, codecName: "videotoolbox", reason: "recovery_attempt")
        
        // 重置性能统计
        consecutiveErrors = 0
        recentFrameDrops = 0
        avgDecodeTimeMs = 0.0
        decodeCount = 0
        
        return true
    }
    
    /// 获取当前解码器状态
    public func getCurrentStatus() -> DecoderStatus {
        lock.lock()
        defer { lock.unlock() }
        return currentStatus
    }
    
    /// 设置状态变更回调
    public func setStatusCallback(_ callback: StatusCallback?) {
        lock.lock()
        defer { lock.unlock() }
        statusCallback = callback
    }
    
    /// 重置状态
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        currentStatus = DecoderStatus(type: .hardware, isHardwareAccelerated: true)
        consecutiveErrors = 0
        recentFrameDrops = 0
        avgDecodeTimeMs = 0.0
        decodeCount = 0
        recoveryAttempts = 0
    }
    
    // MARK: - FFmpeg Options
    
    /// 获取 FFmpeg 软解码器选项
    public func getSoftDecoderOptions(codecName: String) -> [String: Any] {
        var options: [String: Any] = [:]
        
        // 禁用硬件加速
        options["hwaccel"] = "none"
        
        // 多线程解码
        options["threads"] = "auto"
        
        // 低延迟模式
        options["flags"] = "low_delay"
        
        // 参考帧
        options["refcounted_frames"] = 1
        
        // 特定编解码器优化
        switch codecName.lowercased() {
        case "h264", "h.264":
            options["skip_loop_filter"] = "noref"
        case "hevc", "h.265":
            options["skip_loop_filter"] = "noref"
        default:
            break
        }
        
        return options
    }
    
    // MARK: - Private Methods
    
    private func isPerformanceBelowThreshold() -> Bool {
        // 检查连续错误
        if consecutiveErrors >= thresholds.maxConsecutiveErrors {
            return true
        }
        
        // 检查平均解码时间
        if decodeCount > 10 && avgDecodeTimeMs > thresholds.maxDecodeTimeMs {
            return true
        }
        
        // 检查丢帧数
        if recentFrameDrops >= thresholds.maxFrameDrops {
            return true
        }
        
        return false
    }
    
    private func updateStatus(type: DecoderType, codecName: String, reason: String) {
        currentStatus = DecoderStatus(
            type: type,
            codecName: codecName,
            isHardwareAccelerated: type == .hardware,
            fallbackReason: reason
        )
        
        statusCallback?(currentStatus)
    }
}
