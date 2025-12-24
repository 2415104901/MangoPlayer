import Foundation
import VideoToolbox
import CoreVideo
import CoreMedia

/// VideoToolbox Decoder for hardware-accelerated video decoding
class VideoToolboxDecoder {
    typealias FrameCallback = (CVPixelBuffer, Int64) -> Void
    
    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private var frameCallback: FrameCallback?
    private var codecId: Int32
    
    private let queue = DispatchQueue(label: "com.mangoplayer.videotoolbox")
    
    init(codecId: Int32) {
        self.codecId = codecId
    }
    
    deinit {
        invalidateSession()
    }
    
    func setFrameCallback(_ callback: @escaping FrameCallback) {
        self.frameCallback = callback
    }
    
    func decodePacket(_ packet: PacketInfo) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Create format description if needed
            if self.formatDescription == nil {
                self.createFormatDescription(from: packet)
            }
            
            // Create decompression session if needed
            if self.decompressionSession == nil {
                self.createDecompressionSession()
            }
            
            // Decode the packet
            self.decodeData(packet.data, pts: packet.pts)
        }
    }
    
    func flush() {
        queue.async { [weak self] in
            guard let self = self, let session = self.decompressionSession else { return }
            VTDecompressionSessionWaitForAsynchronousFrames(session)
        }
    }
    
    private func createFormatDescription(from packet: PacketInfo) {
        // In production, this would parse SPS/PPS for H.264 or VPS/SPS/PPS for HEVC
        // and create appropriate format description
        
        // Placeholder for H.264
        let extensions: [String: Any] = [
            kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: [:]
        ]
        
        // Would create actual format description from codec data
        // CMVideoFormatDescriptionCreate(...)
    }
    
    private func createDecompressionSession() {
        guard let formatDesc = formatDescription else { return }
        
        let destinationPixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        var outputCallback = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: decompressionCallback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDesc,
            decoderSpecification: nil,
            imageBufferAttributes: destinationPixelBufferAttributes as CFDictionary,
            outputCallback: &outputCallback,
            decompressionSessionOut: &decompressionSession
        )
        
        if status != noErr {
            print("Failed to create decompression session: \(status)")
        }
    }
    
    private func decodeData(_ data: Data, pts: Int64) {
        guard let session = decompressionSession else { return }
        
        // Create sample buffer from data
        var blockBuffer: CMBlockBuffer?
        data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else { return }
            
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: data.count,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: data.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            
            if let buffer = blockBuffer {
                CMBlockBufferReplaceDataBytes(
                    with: baseAddress,
                    blockBuffer: buffer,
                    offsetIntoDestination: 0,
                    dataLength: data.count
                )
            }
        }
        
        guard let block = blockBuffer, let formatDesc = formatDescription else { return }
        
        var sampleBuffer: CMSampleBuffer?
        var sampleTiming = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: CMTime(value: pts, timescale: 1000),
            decodeTimeStamp: CMTime.invalid
        )
        var sampleSize = data.count
        
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &sampleTiming,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        
        guard let sample = sampleBuffer else { return }
        
        // Decode
        let flags = VTDecodeFrameFlags._EnableAsynchronousDecompression
        var infoFlags = VTDecodeInfoFlags()
        
        VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sample,
            flags: flags,
            frameRefcon: nil,
            infoFlagsOut: &infoFlags
        )
    }
    
    private func invalidateSession() {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        formatDescription = nil
    }
    
    private func handleDecodedFrame(status: OSStatus, imageBuffer: CVImageBuffer?, pts: CMTime) {
        guard status == noErr, let pixelBuffer = imageBuffer else {
            print("Decode error: \(status)")
            return
        }
        
        let ptsMs = CMTimeGetSeconds(pts) * 1000
        frameCallback?(pixelBuffer as CVPixelBuffer, Int64(ptsMs))
    }
}

// C callback for VideoToolbox
private func decompressionCallback(
    decompressionOutputRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTDecodeInfoFlags,
    imageBuffer: CVImageBuffer?,
    presentationTimeStamp: CMTime,
    presentationDuration: CMTime
) {
    guard let refCon = decompressionOutputRefCon else { return }
    let decoder = Unmanaged<VideoToolboxDecoder>.fromOpaque(refCon).takeUnretainedValue()
    decoder.handleDecodedFrame(status: status, imageBuffer: imageBuffer, pts: presentationTimeStamp)
}
