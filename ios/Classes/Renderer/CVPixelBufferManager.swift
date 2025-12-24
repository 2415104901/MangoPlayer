import Flutter
import Foundation
import CoreVideo

class CVPixelBufferManager: NSObject, FlutterTexture {
    private let registry: FlutterTextureRegistry
    var textureId: Int64 = -1
    private var pixelBuffer: CVPixelBuffer?
    
    init(registry: FlutterTextureRegistry) {
        self.registry = registry
    }
    
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if let buffer = pixelBuffer {
            return Unmanaged.passRetained(buffer)
        }
        return nil
    }
    
    func updatePixelBuffer(_ buffer: CVPixelBuffer) {
        self.pixelBuffer = buffer
        registry.textureFrameAvailable(textureId)
    }
    
    func dispose() {
        pixelBuffer = nil
    }
}
