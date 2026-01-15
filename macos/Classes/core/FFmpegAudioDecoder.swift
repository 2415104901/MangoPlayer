import Foundation
import AVFoundation

/// FFmpeg Audio Decoder
/// Decodes compressed audio packets to PCM data using FFmpeg's software decoder
/// Uses FFmpegAudioDecoderObjC as bridge to FFmpeg C API
class FFmpegAudioDecoder {
    typealias AudioCallback = (Data, Int64, Int) -> Void  // (pcmData, pts, sampleCount)
    
    private var audioCallback: AudioCallback?
    private var objcDecoder: FFmpegAudioDecoderObjC?
    private var isInitialized: Bool = false
    
    // Output format (for AVAudioEngine)
    var outputSampleRate: Int { Int(objcDecoder?.outputSampleRate ?? 44100) }
    var outputChannels: Int { Int(objcDecoder?.outputChannels ?? 2) }
    
    init() {
        objcDecoder = FFmpegAudioDecoderObjC()
    }
    
    deinit {
        objcDecoder?.close()
        objcDecoder = nil
    }
    
    /// Configure the audio decoder with stream parameters
    /// - Parameters:
    ///   - sampleRate: Input sample rate
    ///   - channels: Input channel count  
    ///   - codecId: FFmpeg codec ID
    ///   - extradata: Codec-specific extradata (optional)
    func configure(sampleRate: Int, channels: Int, codecId: Int32, extradata: Data? = nil) {
        guard let decoder = objcDecoder else {
            Log.error("ObjC decoder not available")
            return
        }
        
        let success = decoder.configure(
            withCodecId: codecId,
            sampleRate: Int32(sampleRate),
            channels: Int32(channels),
            extradata: extradata
        )
        
        if success {
            // Set callback to bridge ObjC -> Swift
            decoder.setAudioFrameCallback { [weak self] pcmData, pts, sampleCount in
                self?.audioCallback?(pcmData, pts, Int(sampleCount))
            }
            isInitialized = true
            Log.info("Audio decoder configured: \(sampleRate)Hz, \(channels)ch, codec: \(codecId)")
        } else {
            Log.error("Failed to configure audio decoder")
        }
    }
    
    /// Set callback for decoded audio frames
    /// - Parameter callback: Called with (pcmData, pts, sampleCount)
    func setAudioCallback(_ callback: @escaping AudioCallback) {
        self.audioCallback = callback
    }
    
    /// Decode an audio packet
    /// - Parameter packet: Packet info from demuxer
    func decodePacket(_ packet: PacketInfo) {
        guard isInitialized, let decoder = objcDecoder else { return }
        
        _ = decoder.decodePacket(
            with: packet.data,
            pts: packet.pts,
            dts: packet.dts,
            duration: packet.duration
        )
    }
    
    /// Flush decoder buffers (call after seek)
    func flush() {
        objcDecoder?.flush()
    }
    
    /// Close decoder and release resources
    func close() {
        objcDecoder?.close()
        isInitialized = false
    }
}
