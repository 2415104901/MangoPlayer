import Foundation
import CoreVideo
import Metal

/// CVPixelBuffer Manager for macOS
/// Manages CVPixelBuffer creation and pooling for efficient video rendering
class CVPixelBufferManager {
    private var pixelBufferPool: CVPixelBufferPool?
    private var width: Int = 0
    private var height: Int = 0
    
    private let lock = NSLock()
    
    init() {}
    
    func createPool(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // Release existing pool
        pixelBufferPool = nil
        
        self.width = width
        self.height = height
        
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pixelBufferPool
        )
        
        return status == kCVReturnSuccess
    }
    
    func getPixelBuffer() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let pool = pixelBufferPool else {
            return nil
        }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pool,
            &pixelBuffer
        )
        
        if status != kCVReturnSuccess {
            print("Failed to create pixel buffer: \(status)")
            return nil
        }
        
        return pixelBuffer
    }
    
    func copyFrameToPixelBuffer(_ sourceData: Data, pixelBuffer: CVPixelBuffer) -> Bool {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return false
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Copy data
        sourceData.withUnsafeBytes { rawBufferPointer in
            guard let sourceAddress = rawBufferPointer.baseAddress else { return }
            memcpy(baseAddress, sourceAddress, min(sourceData.count, bytesPerRow * height))
        }
        
        return true
    }
    
    func releasePool() {
        lock.lock()
        defer { lock.unlock() }
        
        pixelBufferPool = nil
    }
    
    func getWidth() -> Int {
        return width
    }
    
    func getHeight() -> Int {
        return height
    }
}
