import Foundation
import VideoToolbox
import AVFoundation

/// VideoToolbox 配置管理器
///
/// 负责配置 ijkplayer 的 VideoToolbox 硬件解码选项，
/// 监听解码器降级事件，并提供解码器能力查询接口。
///
/// 任务: T109 [US6]
public class VideoToolboxConfigManager {
    
    // MARK: - Types
    
    /// 支持的视频编解码器
    public struct SupportedCodecs {
        let h264: Bool
        let hevc: Bool
        let vp9: Bool
        let av1: Bool
        
        public init(h264: Bool = true, hevc: Bool = false, vp9: Bool = false, av1: Bool = false) {
            self.h264 = h264
            self.hevc = hevc
            self.vp9 = vp9
            self.av1 = av1
        }
    }
    
    /// 硬件解码器能力信息
    public struct HardwareDecoderCapability {
        let codecType: CMVideoCodecType
        let codecName: String
        let isSupported: Bool
        let maxWidth: Int
        let maxHeight: Int
        let supportedProfiles: [String]
    }
    
    /// 解码配置
    public struct DecoderConfiguration {
        let enableHardwareDecode: Bool
        let enableHEVC: Bool
        let enableAsyncDecode: Bool
        let outputPixelFormat: OSType
        let preferredProfiles: [String]
        
        public init(
            enableHardwareDecode: Bool = true,
            enableHEVC: Bool = true,
            enableAsyncDecode: Bool = true,
            outputPixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            preferredProfiles: [String] = []
        ) {
            self.enableHardwareDecode = enableHardwareDecode
            self.enableHEVC = enableHEVC
            self.enableAsyncDecode = enableAsyncDecode
            self.outputPixelFormat = outputPixelFormat
            self.preferredProfiles = preferredProfiles
        }
        
        public static let `default` = DecoderConfiguration()
    }
    
    /// 降级事件
    public struct FallbackEvent {
        let fromCodec: String
        let toCodec: String
        let reason: FallbackReason
        let timestamp: Date
        
        public init(fromCodec: String, toCodec: String, reason: FallbackReason, timestamp: Date = Date()) {
            self.fromCodec = fromCodec
            self.toCodec = toCodec
            self.reason = reason
            self.timestamp = timestamp
        }
    }
    
    public enum FallbackReason: String {
        case codecNotSupported = "codec_not_supported"
        case resolutionTooHigh = "resolution_too_high"
        case decodeError = "decode_error"
        case timeout = "timeout"
        case unknown = "unknown"
    }
    
    // MARK: - Properties
    
    private var configuration = DecoderConfiguration.default
    private var fallbackHistory: [FallbackEvent] = []
    private var fallbackCallback: ((FallbackEvent) -> Void)?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Hardware Capability Detection
    
    /// 获取设备支持的硬件解码器列表
    public func getAvailableHardwareDecoders() -> [HardwareDecoderCapability] {
        var decoders: [HardwareDecoderCapability] = []
        
        // H.264/AVC
        decoders.append(HardwareDecoderCapability(
            codecType: kCMVideoCodecType_H264,
            codecName: "H.264/AVC",
            isSupported: isHardwareDecodeSupported(kCMVideoCodecType_H264),
            maxWidth: 4096,
            maxHeight: 2160,
            supportedProfiles: ["Baseline", "Main", "High"]
        ))
        
        // H.265/HEVC
        if #available(iOS 11.0, *) {
            decoders.append(HardwareDecoderCapability(
                codecType: kCMVideoCodecType_HEVC,
                codecName: "H.265/HEVC",
                isSupported: isHardwareDecodeSupported(kCMVideoCodecType_HEVC),
                maxWidth: 8192,
                maxHeight: 4320,
                supportedProfiles: ["Main", "Main 10"]
            ))
        }
        
        return decoders
    }
    
    /// 检查指定编解码器是否支持硬件解码
    public func isHardwareDecodeSupported(_ codecType: CMVideoCodecType) -> Bool {
        if #available(iOS 11.0, *) {
            return VTIsHardwareDecodeSupported(codecType)
        }
        // iOS 11 以下假设 H.264 支持
        return codecType == kCMVideoCodecType_H264
    }
    
    /// 获取当前设备支持的编解码器
    public func getSupportedCodecs() -> SupportedCodecs {
        return SupportedCodecs(
            h264: isHardwareDecodeSupported(kCMVideoCodecType_H264),
            hevc: isHardwareDecodeSupported(kCMVideoCodecType_HEVC),
            vp9: false,  // iOS 不支持 VP9 硬解
            av1: false   // iOS 暂不支持 AV1 硬解
        )
    }
    
    // MARK: - Configuration
    
    /// 获取 ijkplayer 的解码配置选项
    public func getIjkPlayerOptions(for config: DecoderConfiguration) -> [String: Any] {
        var options: [String: Any] = [:]
        
        // VideoToolbox 硬解开关
        options["videotoolbox"] = config.enableHardwareDecode ? 1 : 0
        
        // VideoToolbox 像素格式输出
        // 1 = 输出 CVPixelBuffer (用于 Flutter External Texture)
        options["videotoolbox-pixelbuffer-output"] = 1
        
        // HEVC 支持
        if config.enableHEVC && isHardwareDecodeSupported(kCMVideoCodecType_HEVC) {
            options["videotoolbox-hevc"] = 1
        }
        
        // 异步解码
        options["videotoolbox-async"] = config.enableAsyncDecode ? 1 : 0
        
        // 像素格式
        options["videotoolbox-cv-format"] = Int(config.outputPixelFormat)
        
        return options
    }
    
    /// 应用解码器配置
    public func applyConfiguration(_ config: DecoderConfiguration) {
        self.configuration = config
    }
    
    /// 获取当前配置
    public func getCurrentConfiguration() -> DecoderConfiguration {
        return configuration
    }
    
    // MARK: - Resolution Support
    
    /// 检查是否支持指定分辨率的硬件解码
    public func supportsResolution(width: Int, height: Int, codecType: CMVideoCodecType = kCMVideoCodecType_H264) -> Bool {
        let decoders = getAvailableHardwareDecoders()
        return decoders.contains { decoder in
            decoder.codecType == codecType &&
            decoder.isSupported &&
            decoder.maxWidth >= width &&
            decoder.maxHeight >= height
        }
    }
    
    /// 获取推荐的解码配置
    public func getRecommendedConfiguration(width: Int, height: Int, codecType: CMVideoCodecType = kCMVideoCodecType_H264) -> DecoderConfiguration {
        let supportsHardware = supportsResolution(width: width, height: height, codecType: codecType)
        let supportsHEVC = supportsResolution(width: width, height: height, codecType: kCMVideoCodecType_HEVC)
        
        return DecoderConfiguration(
            enableHardwareDecode: supportsHardware,
            enableHEVC: supportsHEVC,
            enableAsyncDecode: true,
            outputPixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        )
    }
    
    // MARK: - Fallback Handling
    
    /// 记录降级事件
    public func recordFallback(fromCodec: String, toCodec: String, reason: FallbackReason) {
        let event = FallbackEvent(fromCodec: fromCodec, toCodec: toCodec, reason: reason)
        fallbackHistory.append(event)
        fallbackCallback?(event)
    }
    
    /// 设置降级事件回调
    public func setFallbackCallback(_ callback: ((FallbackEvent) -> Void)?) {
        self.fallbackCallback = callback
    }
    
    /// 获取降级历史
    public func getFallbackHistory() -> [FallbackEvent] {
        return fallbackHistory
    }
    
    /// 清除降级历史
    public func clearFallbackHistory() {
        fallbackHistory.removeAll()
    }
}
