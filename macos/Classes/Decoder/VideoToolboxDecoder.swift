import Foundation
import VideoToolbox
import CoreVideo
import AVFoundation

/// VideoToolbox hardware decoder for H.264/HEVC video streams
/// Converts compressed video packets to CVPixelBuffers for rendering
class VideoToolboxDecoder {
    
    // MARK: - Properties
    
    private var decompressionSession: VTDecompressionSession?
    private let codecType: CMVideoCodecType
    private let videoWidth: Int
    private let videoHeight: Int
    private var formatDescription: CMVideoFormatDescription?
    
    // Frame callback
    private var frameCallback: ((CVPixelBuffer, Int64) -> Void)?
    
    // Decode queue for thread safety
    private let decodeQueue = DispatchQueue(label: "com.mangoplayer.videotoolbox.decode")
    
    // Statistics
    private var decodedFrameCount: Int = 0
    private var droppedFrameCount: Int = 0
    
    // MARK: - Initialization
    
    init(codecId: Int32, width: Int, height: Int, extradata: Data? = nil) throws {
        self.videoWidth = width
        self.videoHeight = height
        
        // Map FFmpeg codec ID to CMVideoCodecType
        switch codecId {
        case 27: // AV_CODEC_ID_H264
            self.codecType = kCMVideoCodecType_H264
            NSLog("[VideoToolboxDecoder] 🎥 Codec: H.264")
        case 173: // AV_CODEC_ID_HEVC
            self.codecType = kCMVideoCodecType_HEVC
            NSLog("[VideoToolboxDecoder] 🎥 Codec: HEVC")
        default:
            NSLog("[VideoToolboxDecoder] ❌ Unsupported codec ID: %d", codecId)
            throw DecoderError.unsupportedCodec
        }
        
        NSLog("[VideoToolboxDecoder] 📐 Video size: %dx%d", width, height)
        
        // Create format description
        try createFormatDescription(extradata: extradata)
        
        // Create decompression session
        try createDecompressionSession()
    }
    
    deinit {
        invalidate()
    }
    
    // MARK: - Format Description
    
    private func createFormatDescription(extradata: Data?) throws {
        guard let extradata = extradata, extradata.count > 7 else {
            NSLog("[VideoToolboxDecoder] ⚠️ No valid extradata, will create format description dynamically")
            return
        }
        
        NSLog("[VideoToolboxDecoder] 📦 Processing extradata: %d bytes", extradata.count)
        
        if codecType == kCMVideoCodecType_H264 {
            // Parse AVCC format extradata for H.264
            // Format: [configurationVersion(1) | AVCProfileIndication(1) | profile_compatibility(1) | AVCLevelIndication(1) | 
            //          lengthSizeMinusOne(1) | numOfSequenceParameterSets(1) | SPS... | numOfPictureParameterSets(1) | PPS...]
            
            var parameterSetPointers: [UnsafePointer<UInt8>] = []
            var parameterSetSizes: [Int] = []
            
            extradata.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Void in
                guard let baseAddress = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                
                var offset = 5 // Skip first 5 bytes
                guard offset < bytes.count else { return }
                
                // Number of SPS
                let numSPS = Int(baseAddress[offset] & 0x1F)
                offset += 1
                
                NSLog("[VideoToolboxDecoder] 📝 Found %d SPS", numSPS)
                
                // Parse SPS
                for _ in 0..<numSPS {
                    guard offset + 2 <= bytes.count else { return }
                    let spsSize = (Int(baseAddress[offset]) << 8) | Int(baseAddress[offset + 1])
                    offset += 2
                    
                    guard offset + spsSize <= bytes.count else { return }
                    parameterSetPointers.append(baseAddress + offset)
                    parameterSetSizes.append(spsSize)
                    offset += spsSize
                    
                    NSLog("[VideoToolboxDecoder] 📏 SPS size: %d", spsSize)
                }
                
                // Number of PPS
                guard offset < bytes.count else { return }
                let numPPS = Int(baseAddress[offset])
                offset += 1
                
                NSLog("[VideoToolboxDecoder] 📝 Found %d PPS", numPPS)
                
                // Parse PPS
                for _ in 0..<numPPS {
                    guard offset + 2 <= bytes.count else { return }
                    let ppsSize = (Int(baseAddress[offset]) << 8) | Int(baseAddress[offset + 1])
                    offset += 2
                    
                    guard offset + ppsSize <= bytes.count else { return }
                    parameterSetPointers.append(baseAddress + offset)
                    parameterSetSizes.append(ppsSize)
                    offset += ppsSize
                    
                    NSLog("[VideoToolboxDecoder] 📏 PPS size: %d", ppsSize)
                }
            }
            
            if !parameterSetPointers.isEmpty {
                var formatDesc: CMVideoFormatDescription?
                let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: parameterSetPointers.count,
                    parameterSetPointers: parameterSetPointers,
                    parameterSetSizes: parameterSetSizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &formatDesc
                )
                
                if status == noErr, let desc = formatDesc {
                    self.formatDescription = desc
                    NSLog("[VideoToolboxDecoder] ✅ Format description created from %d parameter sets", parameterSetPointers.count)
                } else {
                    NSLog("[VideoToolboxDecoder] ❌ Failed to create format description: %d", status)
                }
            }
        } else {
            NSLog("[VideoToolboxDecoder] ⚠️ HEVC format description creation not implemented yet")
        }
    }
    
    // MARK: - Decompression Session
    
    private func createDecompressionSession() throws {
        guard let formatDesc = formatDescription else {
            // Will create session when we have format description
            NSLog("[VideoToolboxDecoder] ⏳ Waiting for format description...")
            return
        }
        
        var session: VTDecompressionSession?
        
        // Destination pixel buffer attributes
        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferWidthKey: videoWidth,
            kCVPixelBufferHeightKey: videoHeight,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        
        // Decompression output callback
        var outputCallback = VTDecompressionOutputCallbackRecord()
        outputCallback.decompressionOutputCallback = { (
            decompressionOutputRefCon: UnsafeMutableRawPointer?,
            sourceFrameRefCon: UnsafeMutableRawPointer?,
            status: OSStatus,
            infoFlags: VTDecodeInfoFlags,
            imageBuffer: CVImageBuffer?,
            presentationTimeStamp: CMTime,
            presentationDuration: CMTime
        ) -> Void in
            guard status == noErr else {
                NSLog("[VideoToolboxDecoder] ❌ Decode callback error: %d", status)
                return
            }
            
            guard let pixelBuffer = imageBuffer else {
                NSLog("[VideoToolboxDecoder] ⚠️ No pixel buffer in callback")
                return
            }
            
            // Convert PTS to milliseconds
            let ptsMs = Int64(CMTimeGetSeconds(presentationTimeStamp) * 1000.0)
            
            // Get decoder instance from context
            let decoder = Unmanaged<VideoToolboxDecoder>.fromOpaque(decompressionOutputRefCon!).takeUnretainedValue()
            decoder.handleDecodedFrame(pixelBuffer, pts: ptsMs)
        }
        outputCallback.decompressionOutputRefCon = Unmanaged.passUnretained(self).toOpaque()
        
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDesc,
            decoderSpecification: nil,
            imageBufferAttributes: pixelBufferAttributes as CFDictionary,
            outputCallback: &outputCallback,
            decompressionSessionOut: &session
        )
        
        guard status == noErr, let validSession = session else {
            NSLog("[VideoToolboxDecoder] ❌ Failed to create decompression session: %d", status)
            throw DecoderError.sessionCreationFailed
        }
        
        // Set real-time decoding
        VTSessionSetProperty(
            validSession,
            key: kVTDecompressionPropertyKey_RealTime,
            value: kCFBooleanTrue
        )
        
        self.decompressionSession = validSession
        NSLog("[VideoToolboxDecoder] ✅ VideoToolbox decompression session created")
    }
    
    // MARK: - Decoding
    
    /// Decode packet asynchronously (for maximum throughput)
    func decodePacket(_ packet: PacketInfo) {
        decodeQueue.async { [weak self] in
            self?.decodePacketInternal(packet)
        }
    }
    
    /// Decode packet synchronously (for frame-rate control - blocks until decoded)
    func decodePacketSync(_ packet: PacketInfo) {
        decodeQueue.sync { [weak self] in
            self?.decodePacketInternal(packet)
        }
        // Wait for VideoToolbox to finish async decoding
        if let session = decompressionSession {
            VTDecompressionSessionWaitForAsynchronousFrames(session)
        }
    }
    
    private func decodePacketInternal(_ packet: PacketInfo) {
        // If no format description yet, try to create from keyframe
        if formatDescription == nil && packet.isKeyframe {
            if let formatDesc = createFormatDescriptionFromPacket(packet) {
                self.formatDescription = formatDesc
                do {
                    try createDecompressionSession()
                } catch {
                    NSLog("[VideoToolboxDecoder] ❌ Failed to create session: %@", error.localizedDescription)
                    return
                }
            } else {
                NSLog("[VideoToolboxDecoder] ⚠️ Failed to create format description from keyframe")
                return
            }
        }
        
        guard let session = decompressionSession else {
            // Still waiting for format description
            return
        }
        
        // Create CMBlockBuffer from packet data
        var blockBuffer: CMBlockBuffer?
        let data = packet.data as NSData
        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: data.length,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.length,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard status == noErr, let validBlockBuffer = blockBuffer else {
            NSLog("[VideoToolboxDecoder] ❌ Failed to create block buffer: %d", status)
            return
        }
        
        // Copy packet data to block buffer
        let replaceStatus = CMBlockBufferReplaceDataBytes(
            with: data.bytes,
            blockBuffer: validBlockBuffer,
            offsetIntoDestination: 0,
            dataLength: data.length
        )
        
        guard replaceStatus == noErr else {
            NSLog("[VideoToolboxDecoder] ❌ Failed to copy data to block buffer: %d", replaceStatus)
            return
        }
        
        // Create CMSampleBuffer
        // PTS/DTS/Duration are now in milliseconds from demuxer
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: packet.duration, timescale: 1000),
            presentationTimeStamp: CMTime(value: packet.pts, timescale: 1000),
            decodeTimeStamp: CMTime(value: packet.dts, timescale: 1000)
        )
        
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: validBlockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard sampleStatus == noErr, let validSampleBuffer = sampleBuffer else {
            NSLog("[VideoToolboxDecoder] ❌ Failed to create sample buffer: %d", sampleStatus)
            return
        }
        
        // Decode
        var flagsOut: VTDecodeInfoFlags = []
        let decodeStatus = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: validSampleBuffer,
            flags: [._EnableAsynchronousDecompression],
            frameRefcon: nil,
            infoFlagsOut: &flagsOut
        )
        
        if decodeStatus != noErr {
            NSLog("[VideoToolboxDecoder] ❌ Decode frame failed: %d", decodeStatus)
            droppedFrameCount += 1
        }
    }
    
    private func createFormatDescriptionFromPacket(_ packet: PacketInfo) -> CMVideoFormatDescription? {
        // For H.264, try to extract SPS/PPS from packet
        // This is a simplified implementation - production code would need proper NAL parsing
        NSLog("[VideoToolboxDecoder] 🔍 Attempting to create format description from packet")
        
        // For now, create basic format description
        var formatDesc: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: codecType,
            width: Int32(videoWidth),
            height: Int32(videoHeight),
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )
        
        if status == noErr {
            NSLog("[VideoToolboxDecoder] ✅ Created basic format description")
            return formatDesc
        } else {
            NSLog("[VideoToolboxDecoder] ❌ Failed to create format description: %d", status)
            return nil
        }
    }
    
    // MARK: - Frame Handling
    
    private func handleDecodedFrame(_ pixelBuffer: CVPixelBuffer, pts: Int64) {
        decodedFrameCount += 1
        
        if decodedFrameCount % 30 == 0 {
            NSLog("[VideoToolboxDecoder] 🎬 Decoded %d frames (dropped: %d)", decodedFrameCount, droppedFrameCount)
        }
        
        // Call frame callback directly on decode thread (caller handles sync/render)
        frameCallback?(pixelBuffer, pts)
    }
    
    func setFrameCallback(_ callback: @escaping (CVPixelBuffer, Int64) -> Void) {
        self.frameCallback = callback
    }
    
    // MARK: - Cleanup
    
    func flush() {
        guard let session = decompressionSession else { return }
        VTDecompressionSessionWaitForAsynchronousFrames(session)
    }
    
    func invalidate() {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
            NSLog("[VideoToolboxDecoder] 🔒 Session invalidated")
        }
    }
    
    // MARK: - Error Types
    
    enum DecoderError: Error {
        case unsupportedCodec
        case sessionCreationFailed
        case invalidFormatDescription
    }
}
