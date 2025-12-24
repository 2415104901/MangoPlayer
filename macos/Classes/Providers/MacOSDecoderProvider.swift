import Foundation
import VideoToolbox

/// macOS 解码器提供者实现
///
/// 实现 DecoderProvider 接口，负责配置和监控 FFmpeg 的解码器设置。
/// 支持硬件解码（VideoToolbox）和软件解码之间的切换。
public class MacOSDecoderProvider {
    
    // MARK: - Types
    
    /// 解码器类型
    public enum DecoderType {
        case hardware   // 硬件解码 (VideoToolbox)
        case software   // 软件解码 (FFmpeg)
        case auto       // 自动选择
    }
    
    /// 解码器配置
    public struct DecoderConfig {
        let preferHardware: Bool
        let enableAsyncDecode: Bool
        let pixelFormat: OSType
        let threadCount: Int  // 0 = auto
        
        public init(
            preferHardware: Bool = true,
            enableAsyncDecode: Bool = true,
            pixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            threadCount: Int = 0
        ) {
            self.preferHardware = preferHardware
            self.enableAsyncDecode = enableAsyncDecode
            self.pixelFormat = pixelFormat
            self.threadCount = threadCount
        }
        
        public static let `default` = DecoderConfig()
    }
    
    /// 解码器状态
    public struct DecoderStatus {
        let type: DecoderType
        let codecName: String?
        let isHardwareAccelerated: Bool
        let fallbackReason: String?
        
        public init(
            type: DecoderType,
            codecName: String? = nil,
            isHardwareAccelerated: Bool = false,
            fallbackReason: String? = nil
        ) {
            self.type = type
            self.codecName = codecName
            self.isHardwareAccelerated = isHardwareAccelerated
            self.fallbackReason = fallbackReason
        }
    }
    
    // MARK: - Properties
    
    private var currentStatus: DecoderStatus
    private var statusCallback: ((DecoderStatus) -> Void)?
    private var config: DecoderConfig
    
    // MARK: - Initialization
    
    public init() {
        self.config = .default
        self.currentStatus = DecoderStatus(type: .auto)
    }
    
    // MARK: - Public Methods
    
    /// 检查系统是否支持硬件解码
    public func isHardwareDecodingSupported() -> Bool {
        // macOS 10.8+ 支持 VideoToolbox
        if #available(macOS 10.8, *) {
            return true
        }
        return false
    }
    
    /// 检查特定编解码器是否支持硬件解码
    public func isCodecHardwareAccelerated(_ codecType: CMVideoCodecType) -> Bool {
        if #available(macOS 10.13, *) {
            return VTIsHardwareDecodeSupported(codecType)
        }
        // macOS 10.13 以下，假设 H.264 支持硬解
        return codecType == kCMVideoCodecType_H264
    }
    
    /// 检查 H.264 硬件解码支持
    public func isH264HardwareSupported() -> Bool {
        return isCodecHardwareAccelerated(kCMVideoCodecType_H264)
    }
    
    /// 检查 H.265/HEVC 硬件解码支持
    public func isHEVCHardwareSupported() -> Bool {
        return isCodecHardwareAccelerated(kCMVideoCodecType_HEVC)
    }
    
    /// 检查 VP9 硬件解码支持 (macOS 11+)
    @available(macOS 11.0, *)
    public func isVP9HardwareSupported() -> Bool {
        return VTIsHardwareDecodeSupported(kCMVideoCodecType_VP9)
    }
    
    /// 获取 FFmpeg 参数
    public func getFFmpegOptions(for config: DecoderConfig) -> [String: Any] {
        var options: [String: Any] = [:]
        
        // 硬件解码配置
        if config.preferHardware && isHardwareDecodingSupported() {
            options["hwaccel"] = "videotoolbox"
            options["hwaccel_output_format"] = "videotoolbox_vld"
        }
        
        // 线程数
        if config.threadCount > 0 {
            options["threads"] = config.threadCount
        }
        
        return options
    }
    
    /// 配置解码器
    public func configure(_ config: DecoderConfig) {
        self.config = config
        
        currentStatus = DecoderStatus(
            type: config.preferHardware ? .hardware : .software,
            isHardwareAccelerated: config.preferHardware && isHardwareDecodingSupported()
        )
    }
    
    /// 获取当前配置
    public func getConfig() -> DecoderConfig {
        return config
    }
    
    /// 更新解码器状态
    public func updateStatus(_ status: DecoderStatus) {
        self.currentStatus = status
        statusCallback?(status)
    }
    
    /// 处理解码器降级事件
    public func onDecoderFallback(reason: String) {
        let newStatus = DecoderStatus(
            type: .software,
            codecName: currentStatus.codecName,
            isHardwareAccelerated: false,
            fallbackReason: reason
        )
        updateStatus(newStatus)
    }
    
    /// 设置状态回调
    public func setStatusCallback(_ callback: ((DecoderStatus) -> Void)?) {
        self.statusCallback = callback
    }
    
    /// 获取当前解码器状态
    public func getStatus() -> DecoderStatus {
        return currentStatus
    }
    
    /// 获取推荐的解码配置
    public func getRecommendedConfig() -> DecoderConfig {
        return DecoderConfig(
            preferHardware: isHardwareDecodingSupported(),
            enableAsyncDecode: true,
            pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            threadCount: 0
        )
    }
}
