import Foundation
import FlutterMacOS
import CoreVideo
import Metal
import IOSurface

/// macOS 渲染器提供者实现
///
/// 实现 RendererProvider 接口，负责管理 Flutter External Texture 渲染。
/// 使用 CVPixelBuffer 或 IOSurface 实现零拷贝渲染。
public class MacOSRendererProvider: NSObject {
    
    // MARK: - Types
    
    /// 渲染器类型
    public enum RendererType {
        case pixelBuffer    // CVPixelBuffer 渲染 (默认)
        case metal          // Metal 渲染 (高性能)
        case ioSurface      // IOSurface 渲染
    }
    
    /// 渲染器配置
    public struct RendererConfig {
        let type: RendererType
        let enableVSync: Bool
        let preferredPixelFormat: OSType
        
        public init(
            type: RendererType = .pixelBuffer,
            enableVSync: Bool = true,
            preferredPixelFormat: OSType = kCVPixelFormatType_32BGRA
        ) {
            self.type = type
            self.enableVSync = enableVSync
            self.preferredPixelFormat = preferredPixelFormat
        }
        
        public static let `default` = RendererConfig()
    }
    
    /// 渲染状态
    public struct RendererStatus {
        let textureId: Int64?
        let isActive: Bool
        let width: Int
        let height: Int
        
        public init(
            textureId: Int64? = nil,
            isActive: Bool = false,
            width: Int = 0,
            height: Int = 0
        ) {
            self.textureId = textureId
            self.isActive = isActive
            self.width = width
            self.height = height
        }
    }
    
    // MARK: - Properties
    
    private weak var textureRegistry: FlutterTextureRegistry?
    private var textureId: Int64?
    private var currentPixelBuffer: CVPixelBuffer?
    private var currentStatus: RendererStatus
    private var statusCallback: ((RendererStatus) -> Void)?
    
    private let pixelBufferLock = NSLock()
    
    // Metal 相关
    private var metalDevice: MTLDevice?
    private var metalTexture: MTLTexture?
    
    // MARK: - Initialization
    
    public override init() {
        self.currentStatus = RendererStatus()
        super.init()
        
        // 初始化 Metal 设备
        metalDevice = MTLCreateSystemDefaultDevice()
    }
    
    // MARK: - Public Methods
    
    /// 注册 Texture 到 Flutter
    public func registerTexture(with registry: FlutterTextureRegistry) -> Int64 {
        self.textureRegistry = registry
        
        let textureId = registry.register(self)
        self.textureId = textureId
        
        currentStatus = RendererStatus(
            textureId: textureId,
            isActive: true,
            width: 0,
            height: 0
        )
        statusCallback?(currentStatus)
        
        return textureId
    }
    
    /// 获取 Texture ID
    public func getTextureId() -> Int64? {
        return textureId
    }
    
    /// 更新 PixelBuffer
    ///
    /// 从 FFmpeg 获取的 CVPixelBuffer 通过此方法传递给 Flutter。
    /// 这是零拷贝渲染的核心。
    public func updatePixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }
        
        self.currentPixelBuffer = pixelBuffer
        
        // 更新尺寸
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        if currentStatus.width != width || currentStatus.height != height {
            currentStatus = RendererStatus(
                textureId: textureId,
                isActive: true,
                width: width,
                height: height
            )
            statusCallback?(currentStatus)
        }
        
        // 通知 Flutter 纹理已更新
        if let textureId = textureId {
            textureRegistry?.textureFrameAvailable(textureId)
        }
    }
    
    /// 检查 Metal 是否可用
    public func isMetalAvailable() -> Bool {
        return metalDevice != nil
    }
    
    /// 设置状态回调
    public func setStatusCallback(_ callback: ((RendererStatus) -> Void)?) {
        self.statusCallback = callback
    }
    
    /// 获取当前渲染状态
    public func getStatus() -> RendererStatus {
        return currentStatus
    }
    
    /// 检查渲染器是否可用
    public func isAvailable() -> Bool {
        return textureId != nil && textureRegistry != nil
    }
    
    /// 释放渲染器资源
    public func release() {
        if let textureId = textureId {
            textureRegistry?.unregisterTexture(textureId)
        }
        
        pixelBufferLock.lock()
        currentPixelBuffer = nil
        pixelBufferLock.unlock()
        
        metalTexture = nil
        
        self.textureId = nil
        self.textureRegistry = nil
        
        currentStatus = RendererStatus()
        statusCallback?(currentStatus)
    }
}

// MARK: - FlutterTexture

extension MacOSRendererProvider: FlutterTexture {
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }
        
        guard let pixelBuffer = currentPixelBuffer else {
            return nil
        }
        
        return Unmanaged.passRetained(pixelBuffer)
    }
}
