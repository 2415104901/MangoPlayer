import FlutterMacOS
import Foundation
import CoreVideo
import Metal
import MetalKit

/// Metal Texture Renderer for Flutter External Texture
class MetalTextureRenderer: NSObject, FlutterTexture {
    var textureId: Int64 = -1
    
    private let registry: FlutterTextureRegistry
    private var metalDevice: MTLDevice?
    private var textureCache: CVMetalTextureCache?
    private var currentPixelBuffer: CVPixelBuffer?
    private var currentMetalTexture: CVMetalTexture?
    
    private var width: Int = 0
    private var height: Int = 0
    
    private let lock = NSLock()
    
    init(registry: FlutterTextureRegistry) {
        self.registry = registry
        super.init()
        setupMetal()
    }
    
    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        
        guard let device = metalDevice else {
            print("Metal device not available")
            return
        }
        
        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        
        if status == kCVReturnSuccess {
            textureCache = cache
        } else {
            print("Failed to create Metal texture cache: \(status)")
        }
    }
    
    // MARK: - FlutterTexture Protocol
    
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let pixelBuffer = currentPixelBuffer else {
            return nil
        }
        
        return Unmanaged.passRetained(pixelBuffer)
    }
    
    // MARK: - Update Methods
    
    func updateWithPixelBuffer(_ pixelBuffer: CVPixelBuffer, pts: Int64) {
        lock.lock()
        currentPixelBuffer = pixelBuffer
        width = CVPixelBufferGetWidth(pixelBuffer)
        height = CVPixelBufferGetHeight(pixelBuffer)
        lock.unlock()
        
        // Notify Flutter that a new frame is available
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.textureId >= 0 else { return }
            self.registry.textureFrameAvailable(self.textureId)
        }
    }
    
    func updateWithMetalTexture(_ texture: MTLTexture, pts: Int64) {
        // For direct Metal texture updates
        // Would need to convert to CVPixelBuffer for Flutter
    }
    
    // MARK: - Cleanup
    
    func dispose() {
        lock.lock()
        currentPixelBuffer = nil
        currentMetalTexture = nil
        lock.unlock()
        
        textureCache = nil
        metalDevice = nil
    }
    
    // MARK: - Helpers
    
    func getWidth() -> Int {
        return width
    }
    
    func getHeight() -> Int {
        return height
    }
}
