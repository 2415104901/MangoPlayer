import Foundation
import FlutterMacOS
import AVFoundation
import VideoToolbox
import CoreVideo

/// FFmpeg Player Manager for macOS
/// Manages playback using FFmpeg + VideoToolbox
class FFmpegPlayerManager: NSObject {
    private var textureRegistryHandler: TextureRegistryHandler?
    private var eventSink: FlutterEventSink?
    
    // Playback state
    private var currentState: String = "idle"
    private var duration: Int64 = 0
    private var position: Int64 = 0
    private var volume: Float = 1.0
    private var playbackSpeed: Float = 1.0
    
    // Core components (placeholder for FFmpeg integration)
    private var demuxer: FFmpegDemuxerWrapper?
    private var videoDecoder: VideoToolboxDecoder?
    private var audioDecoder: FFmpegAudioDecoder?
    private var clockSync: ClockSync?
    private var textureRenderer: MetalTextureRenderer?
    
    // Playback control
    private var isPlaying: Bool = false
    private var isPaused: Bool = false
    private var playbackQueue: DispatchQueue?
    private var progressTimer: Timer?
    
    override init() {
        super.init()
        clockSync = ClockSync()
        playbackQueue = DispatchQueue(label: "com.mangoplayer.playback", qos: .userInitiated)
    }
    
    func setTextureRegistryHandler(handler: TextureRegistryHandler?) {
        self.textureRegistryHandler = handler
    }
    
    func setEventSink(sink: FlutterEventSink?) {
        self.eventSink = sink
    }
    
    // MARK: - Player Control
    
    func initialize(uri: String, type: String, headers: [String: String]?, result: @escaping FlutterResult, textureId: Int64?) {
        updateState("initializing")
        
        playbackQueue?.async { [weak self] in
            guard let self = self else { return }
            
            // Create demuxer
            self.demuxer = FFmpegDemuxerWrapper()
            
            let config = DemuxerConfig(
                uri: uri,
                headers: headers ?? [:],
                startTimeMs: 0
            )
            
            guard self.demuxer?.open(config: config) == true else {
                DispatchQueue.main.async {
                    self.updateState("error")
                    result(FlutterError(code: "open_failed", message: "Failed to open media", details: nil))
                }
                return
            }
            
            self.duration = self.demuxer?.getDuration() ?? 0
            
            // Create video decoder (VideoToolbox for hardware acceleration)
            if let videoCodecId = self.demuxer?.getVideoCodecId() {
                self.videoDecoder = VideoToolboxDecoder(codecId: videoCodecId)
                self.videoDecoder?.setFrameCallback { [weak self] pixelBuffer, pts in
                    self?.onVideoFrame(pixelBuffer: pixelBuffer, pts: pts)
                }
            }
            
            // Set up texture renderer if texture ID provided
            if let tid = textureId, let handler = self.textureRegistryHandler {
                self.textureRenderer = handler.getTextureRenderer(textureId: tid)
            }
            
            // Reset clock
            self.clockSync?.reset()
            
            DispatchQueue.main.async {
                self.updateState("ready")
                result(["success": true, "duration": self.duration])
            }
        }
    }
    
    func play() {
        guard currentState == "ready" || currentState == "paused" || currentState == "completed" else { return }
        
        if isPaused {
            isPaused = false
            clockSync?.resume()
        } else {
            startPlayback()
        }
        
        updateState("playing")
        startProgressTimer()
    }
    
    func pause() {
        guard currentState == "playing" else { return }
        
        isPaused = true
        clockSync?.pause()
        updateState("paused")
    }
    
    func stop() {
        isPlaying = false
        isPaused = false
        stopProgressTimer()
        
        clockSync?.reset()
        position = 0
        
        updateState("idle")
    }
    
    func seekTo(position: Int64) {
        self.position = position
        
        playbackQueue?.async { [weak self] in
            guard let self = self else { return }
            
            self.demuxer?.seek(toPosition: position)
            self.videoDecoder?.flush()
            self.audioDecoder?.flush()
            self.clockSync?.seek(position)
        }
    }
    
    func setVolume(volume: Float) {
        self.volume = max(0.0, min(1.0, volume))
        // Apply to audio output
    }
    
    func setPlaybackSpeed(speed: Float) {
        self.playbackSpeed = max(0.5, min(2.0, speed))
        clockSync?.setSpeed(Double(speed))
    }
    
    func getPosition() -> Int64 {
        return clockSync?.getCurrentPts() ?? position
    }
    
    func getDuration() -> Int64 {
        return duration
    }
    
    func release() {
        stop()
        
        videoDecoder = nil
        audioDecoder = nil
        demuxer?.close()
        demuxer = nil
        textureRenderer = nil
    }
    
    // MARK: - Private Methods
    
    private func startPlayback() {
        isPlaying = true
        isPaused = false
        
        playbackQueue?.async { [weak self] in
            self?.decodingLoop()
        }
    }
    
    private func decodingLoop() {
        while isPlaying && !isPaused {
            guard let demuxer = demuxer else { break }
            
            // Read packet
            guard let packet = demuxer.readPacket() else {
                // End of file
                DispatchQueue.main.async { [weak self] in
                    self?.updateState("completed")
                }
                break
            }
            
            // Decode based on stream type
            if packet.isVideo {
                videoDecoder?.decodePacket(packet)
            } else if packet.isAudio {
                audioDecoder?.decodePacket(packet)
            }
            
            // Check for pause during loop
            while isPaused && isPlaying {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
    }
    
    private func onVideoFrame(pixelBuffer: CVPixelBuffer, pts: Int64) {
        // Update clock
        clockSync?.setMasterPts(pts)
        position = pts
        
        // Render to texture
        textureRenderer?.updateWithPixelBuffer(pixelBuffer, pts: pts)
    }
    
    private func updateState(_ state: String) {
        currentState = state
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.eventSink?([
                "type": "state",
                "state": state
            ])
        }
    }
    
    private func startProgressTimer() {
        stopProgressTimer()
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentPosition = self.getPosition()
            let bufferedPosition = currentPosition // Simplified
            let bufferPercentage = self.duration > 0 ? Double(bufferedPosition) / Double(self.duration) : 0.0
            
            self.eventSink?([
                "type": "progress",
                "position": currentPosition,
                "duration": self.duration,
                "bufferedPosition": bufferedPosition,
                "bufferPercentage": bufferPercentage
            ])
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
