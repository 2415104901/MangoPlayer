import Foundation
import VideoToolbox

/// iOS 解码器提供者实现
///
/// 实现 DecoderProvider 接口，负责配置和监控 ijkplayer 的解码器设置。
/// 支持硬件解码（VideoToolbox）和软件解码之间的切换。
public class IOSDecoderProvider {
    
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
        
        public init(
            preferHardware: Bool = true,
            enableAsyncDecode: Bool = true,
            pixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ) {
            self.preferHardware = preferHardware
            self.enableAsyncDecode = enableAsyncDecode
            self.pixelFormat = pixelFormat
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
    
    // MARK: - Initialization
    
    public init() {
        self.currentStatus = DecoderStatus(type: .auto)
    }
    
    // MARK: - Public Methods
    
    /// 检查设备是否支持硬件解码
    public func isHardwareDecodingSupported() -> Bool {
        // iOS 8+ 支持 VideoToolbox
        if #available(iOS 8.0, *) {
            return true
        }
        return false
    }
    
    /// 检查特定编解码器是否支持硬件解码
    public func isCodecHardwareAccelerated(_ codecType: CMVideoCodecType) -> Bool {
        // 使用 VTIsHardwareDecodeSupported 检查
        if #available(iOS 11.0, *) {
            return VTIsHardwareDecodeSupported(codecType)
        }
        
        // iOS 11 以下，假设 H.264 支持硬解
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
    
    /// 获取 ijkplayer 配置选项
    ///
    /// - Parameter config: 解码器配置
    /// - Returns: 配置选项字典
    public func getIJKPlayerOptions(for config: DecoderConfig) -> [String: Any] {
        var options: [String: Any] = [:]
        
        // 硬件解码配置
        options["videotoolbox"] = config.preferHardware ? 1 : 0
        options["videotoolbox-max-frame-width"] = 4096
        
        // 异步解码
        options["async-init-decoder"] = config.enableAsyncDecode ? 1 : 0
        
        // 像素格式
        options["videotoolbox-pixelbuffer-format"] = config.pixelFormat
        
        return options
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
            pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        )
    }
}
