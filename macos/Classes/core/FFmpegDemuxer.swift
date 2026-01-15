import Foundation

/// Configuration for demuxer
struct DemuxerConfig {
    let uri: String
    let headers: [String: String]
    let startTimeMs: Int64
}

/// Packet information
struct PacketInfo {
    let streamIndex: Int
    let pts: Int64
    let dts: Int64
    let duration: Int64
    let isKeyframe: Bool
    let isVideo: Bool
    let isAudio: Bool
    let data: Data
}

/// FFmpeg Demuxer Wrapper - Uses Objective-C bridge to access libavformat
/// This Swift wrapper provides clean API while delegating to FFmpegDemuxerObjC
class FFmpegDemuxerWrapper {
    // Objective-C wrapper instance (bridges to FFmpeg C API)
    private var objcDemuxer: FFmpegDemuxerObjC
    
    // Cached stream info
    private var streamInfo: FFmpegStreamInfo?
    private var isOpened: Bool = false
    
    // Synchronization
    private let queue = DispatchQueue(label: "com.mangoplayer.ffmpegdemuxer")
    
    init() {
        objcDemuxer = FFmpegDemuxerObjC()
    }
    
    deinit {
        close()
    }
    
    /// Open media file and extract stream info
    func open(config: DemuxerConfig) -> Bool {
        return queue.sync { () -> Bool in
            guard !isOpened else {
                NSLog("[FFmpegDemuxer] ⚠️ Already opened")
                return true
            }
            
            NSLog("[FFmpegDemuxer] 🔓 Opening: %@", config.uri)
            
            // Convert headers to NSDictionary
            var headersDict: [String: String]? = nil
            if !config.headers.isEmpty {
                headersDict = config.headers
            }
            
            // Call Objective-C wrapper
            let success = objcDemuxer.open(withURI: config.uri, headers: headersDict)
            
            if !success {
                NSLog("[FFmpegDemuxer] ❌ Failed to open")
                return false
            }
            
            // Get stream info
            guard let info = objcDemuxer.getStreamInfo() else {
                NSLog("[FFmpegDemuxer] ❌ Failed to get stream info")
                objcDemuxer.close()
                return false
            }
            
            streamInfo = info
            isOpened = true
            
            NSLog("[FFmpegDemuxer] ✅ Opened successfully")
            NSLog("[FFmpegDemuxer] ⏱️ Duration: %lld ms (%.2f s)", info.duration, Double(info.duration) / 1000.0)
            NSLog("[FFmpegDemuxer] 🎥 Video: %dx%d, %.2f fps, codec: %@", 
                  info.videoWidth, info.videoHeight, info.videoFrameRate, info.videoCodecName)
            
            if info.audioStreamIndex >= 0 {
                NSLog("[FFmpegDemuxer] 🔊 Audio: %d Hz, %d channels, codec: %@",
                      info.audioSampleRate, info.audioChannels, info.audioCodecName)
            }
            
            return true
        }
    }
    
    /// Get video duration in milliseconds
    func getDuration() -> Int64 {
        return queue.sync {
            return streamInfo?.duration ?? 0
        }
    }
    
    /// Get video stream index
    func getVideoStreamIndex() -> Int {
        return queue.sync {
            return Int(streamInfo?.videoStreamIndex ?? -1)
        }
    }
    
    /// Get audio stream index
    func getAudioStreamIndex() -> Int {
        return queue.sync {
            return Int(streamInfo?.audioStreamIndex ?? -1)
        }
    }
    
    /// Get video resolution
    func getVideoSize() -> (width: Int, height: Int) {
        return queue.sync {
            let width = Int(streamInfo?.videoWidth ?? 0)
            let height = Int(streamInfo?.videoHeight ?? 0)
            return (width, height)
        }
    }
    
    /// Get video codec ID
    func getVideoCodecId() -> Int32 {
        return queue.sync {
            return streamInfo?.videoCodecId ?? 0
        }
    }
    
    /// Get video extradata (SPS/PPS for H.264/HEVC)
    func getVideoExtradata() -> Data? {
        return queue.sync {
            return streamInfo?.videoExtradata
        }
    }
    
    /// Get video codec name
    func getVideoCodecName() -> String {
        return queue.sync {
            return streamInfo?.videoCodecName ?? "unknown"
        }
    }
    
    /// Get video frame rate
    func getVideoFrameRate() -> Double {
        return queue.sync {
            return streamInfo?.videoFrameRate ?? 30.0
        }
    }
    
    /// Get audio codec ID
    func getAudioCodecId() -> Int32 {
        return queue.sync {
            return streamInfo?.audioCodecId ?? 0
        }
    }
    
    /// Get audio sample rate
    func getAudioSampleRate() -> Int {
        return queue.sync {
            return Int(streamInfo?.audioSampleRate ?? 44100)
        }
    }
    
    /// Get audio channels
    func getAudioChannels() -> Int {
        return queue.sync {
            return Int(streamInfo?.audioChannels ?? 2)
        }
    }
    
    /// Get audio codec name
    func getAudioCodecName() -> String {
        return queue.sync {
            return streamInfo?.audioCodecName ?? "unknown"
        }
    }
    
    /// Check if audio stream exists
    func hasAudioStream() -> Bool {
        return queue.sync {
            return (streamInfo?.audioStreamIndex ?? -1) >= 0
        }
    }
    
    /// Read next packet
    func readPacket() -> PacketInfo? {
        return queue.sync { () -> PacketInfo? in
            guard isOpened else {
                return nil
            }
            
            guard let objcPacket = objcDemuxer.readPacket() else {
                return nil
            }
            
            return PacketInfo(
                streamIndex: Int(objcPacket.streamIndex),
                pts: objcPacket.pts,
                dts: objcPacket.dts,
                duration: objcPacket.duration,
                isKeyframe: objcPacket.isKeyframe,
                isVideo: objcPacket.isVideo,
                isAudio: objcPacket.isAudio,
                data: objcPacket.data
            )
        }
    }
    
    /// Seek to specific timestamp
    func seek(toMs timestampMs: Int64) -> Bool {
        return queue.sync { () -> Bool in
            guard isOpened else {
                return false
            }
            
            let success = objcDemuxer.seek(toTimestamp: timestampMs)
            
            if !success {
                NSLog("[FFmpegDemuxer] ❌ Seek failed")
                return false
            }
            
            NSLog("[FFmpegDemuxer] ✅ Seeked to %lld ms", timestampMs)
            return true
        }
    }
    
    /// Close demuxer and release resources
    func close() {
        queue.sync {
            if isOpened {
                NSLog("[FFmpegDemuxer] 🔒 Closing demuxer")
                objcDemuxer.close()
                streamInfo = nil
                isOpened = false
            }
        }
    }
}
