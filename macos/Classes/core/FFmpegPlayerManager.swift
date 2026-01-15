import Foundation
import FlutterMacOS
import AVFoundation
import VideoToolbox
import CoreVideo

/// FFmpeg Player Manager for macOS
/// Manages playback using FFmpeg demuxing + VideoToolbox hardware decoding
/// Architecture: Demuxer (FFmpeg) -> Decoder (VideoToolbox) -> Renderer (Metal) -> Flutter Texture
class FFmpegPlayerManager: NSObject {
    
    // MARK: - Dependencies
    
    private var textureRegistryHandler: TextureRegistryHandler?
    private var eventSink: FlutterEventSink?
    
    // MARK: - State
    
    private var currentState: String = "idle"
    private var duration: Int64 = 0
    private var position: Int64 = 0
    private var volume: Float = 1.0
    private var isMuted: Bool = false
    private var playbackSpeed: Float = 1.0
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    
    // MARK: - Core Components
    
    private var demuxer: FFmpegDemuxerWrapper?
    private var videoDecoder: VideoToolboxDecoder?
    private var audioDecoder: FFmpegAudioDecoder?
    private var clockSync: ClockSync?
    private var textureRenderer: MetalTextureRenderer?
    
    // MARK: - Audio Output
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?
    
    // MARK: - Playback Control
    
    private var isPlaying: Bool = false
    private var isPaused: Bool = false
    private var playbackQueue: DispatchQueue?
    private var progressTimer: Timer?
    
    // MARK: - Frame Rate Control
    
    private var videoFrameRate: Double = 30.0
    private var frameInterval: TimeInterval = 1.0 / 30.0  // Default 30fps
    private var lastFrameTime: CFAbsoluteTime = 0
    private var isFirstFrame: Bool = true
    private var firstFramePts: Int64 = 0
    private var playbackStartTime: CFAbsoluteTime = 0
    private var pausedAtPts: Int64 = 0       // PTS when paused
    private var pausedAtTime: CFAbsoluteTime = 0  // Wall clock when paused
    
    // MARK: - Thread Synchronization
    
    private let stateLock = NSLock()
    private var decodingLoopActive: Bool = false
    
    // MARK: - Frame Queue / Backpressure Control
    
    /// Semaphore to limit pending frames in decode pipeline (backpressure)
    private let frameQueueSemaphore = DispatchSemaphore(value: 5)  // Max 5 frames in flight
    
    /// Queue for pending video frames (for proper timing)
    private var pendingFrames: [(pixelBuffer: CVPixelBuffer, pts: Int64)] = []
    private let frameQueueLock = NSLock()
    
    /// Rendering thread
    private var renderingQueue: DispatchQueue?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        clockSync = ClockSync()
        playbackQueue = DispatchQueue(label: "com.mangoplayer.playback", qos: .userInitiated)
        renderingQueue = DispatchQueue(label: "com.mangoplayer.rendering", qos: .userInteractive)
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let playerNode = audioPlayerNode else { return }
        
        engine.attach(playerNode)
        
        // Default audio format: 44.1kHz, stereo, float32
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)
        
        if let format = audioFormat {
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        }
        
        do {
            try engine.start()
            Log.info("Audio engine started")
        } catch {
            Log.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    func setTextureRegistryHandler(handler: TextureRegistryHandler?) {
        self.textureRegistryHandler = handler
    }
    
    func setEventSink(sink: FlutterEventSink?) {
        self.eventSink = sink
    }
    
    // MARK: - Player Control API
    
    /// Initialize player with media source
    /// - Parameters:
    ///   - uri: Media URL (file:// or http(s)://)
    ///   - type: Media type ("network", "file", "asset")
    ///   - headers: HTTP headers for network streams
    ///   - result: Async result callback
    ///   - textureId: Flutter texture ID for rendering
    func initialize(uri: String, type: String, headers: [String: String]?, result: @escaping FlutterResult, textureId: Int64?) {
        Log.info("initialize called - uri: \(uri), type: \(type), textureId: \(String(describing: textureId))")
        updateState("initializing")
        
        guard let queue = playbackQueue else {
            Log.error("playbackQueue is nil")
            result(FlutterError(code: "init_failed", message: "Playback queue not initialized", details: nil))
            return
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Step 1: Create demuxer
            self.demuxer = FFmpegDemuxerWrapper()
            let config = DemuxerConfig(
                uri: uri,
                headers: headers ?? [:],
                startTimeMs: 0
            )
            
            Log.info("Opening FFmpeg demuxer...")
            guard self.demuxer?.open(config: config) == true else {
                Log.error("Failed to open demuxer")
                DispatchQueue.main.async {
                    self.updateState("error")
                    result(FlutterError(code: "open_failed", message: "Failed to open media", details: nil))
                }
                return
            }
            
            // Step 2: Extract stream info
            self.duration = self.demuxer?.getDuration() ?? 0
            let videoSize = self.demuxer?.getVideoSize() ?? (width: 0, height: 0)
            self.videoWidth = videoSize.width
            self.videoHeight = videoSize.height
            
            Log.info("Demuxer opened - duration: \(self.duration)ms, size: \(videoSize.width)x\(videoSize.height)")
            
            // Get video frame rate for timing control
            self.videoFrameRate = self.demuxer?.getVideoFrameRate() ?? 30.0
            self.frameInterval = 1.0 / self.videoFrameRate
            Log.info("Video frame rate: \(self.videoFrameRate) fps, interval: \(self.frameInterval * 1000)ms")
            
            // Step 3: Create video decoder (VideoToolbox hardware decoder)
            if let demuxer = self.demuxer {
                let codecId = demuxer.getVideoCodecId()
                let codecName = demuxer.getVideoCodecName()
                let extradata = demuxer.getVideoExtradata()
                
                Log.info("Creating VideoToolbox decoder - codec: \(codecName) (ID: \(codecId)), size: \(videoSize.width)x\(videoSize.height), extradata: \(extradata?.count ?? 0) bytes")
                
                do {
                    let decoder = try VideoToolboxDecoder(
                        codecId: codecId,
                        width: videoSize.width,
                        height: videoSize.height,
                        extradata: extradata
                    )
                    
                    // Set frame callback - decoder will call this for each decoded frame
                    decoder.setFrameCallback { [weak self] pixelBuffer, pts in
                        guard let self = self else { return }
                        self.onVideoFrame(pixelBuffer: pixelBuffer, pts: pts)
                    }
                    
                    self.videoDecoder = decoder
                    Log.info("VideoToolbox decoder created successfully")
                } catch {
                    Log.error("Failed to create VideoToolbox decoder: \(error.localizedDescription)")
                    // Continue without video decoder - audio-only playback
                }
            }
            
            // Step 4: Create and configure audio decoder
            if let demuxer = self.demuxer, demuxer.hasAudioStream() {
                let audioCodecId = demuxer.getAudioCodecId()
                let audioSampleRate = demuxer.getAudioSampleRate()
                let audioChannels = demuxer.getAudioChannels()
                let audioCodecName = demuxer.getAudioCodecName()
                
                Log.info("Audio stream found - codec: \(audioCodecName) (ID: \(audioCodecId)), \(audioSampleRate)Hz, \(audioChannels)ch")
                
                self.audioDecoder = FFmpegAudioDecoder()
                self.audioDecoder?.configure(
                    sampleRate: audioSampleRate,
                    channels: audioChannels,
                    codecId: audioCodecId,
                    extradata: nil  // AAC extradata could be added if available
                )
                self.audioDecoder?.setAudioCallback { [weak self] audioData, pts, sampleCount in
                    self?.onAudioFrame(audioData: audioData, pts: pts, sampleCount: sampleCount)
                }
                Log.info("Audio decoder created and configured")
            } else {
                Log.info("No audio stream found")
            }
            
            // Step 5: Set up texture renderer if texture ID provided
            if let tid = textureId, let handler = self.textureRegistryHandler {
                self.textureRenderer = handler.getTextureRenderer(textureId: tid)
                Log.info("Texture renderer set up - textureId: \(tid)")
            } else {
                Log.warning("No texture renderer - textureId: \(String(describing: textureId)), handler: \(self.textureRegistryHandler != nil)")
            }
            
            // Step 6: Reset clock sync and frame timing
            self.clockSync?.reset()
            self.isFirstFrame = true
            self.firstFramePts = 0
            self.playbackStartTime = 0
            self.lastFrameTime = 0
            
            // Step 7: Notify Flutter initialization complete
            DispatchQueue.main.async {
                self.updateState("ready")
                result([
                    "success": true,
                    "duration": self.duration,
                    "width": self.videoWidth,
                    "height": self.videoHeight
                ])
            }
        }
    }
    
    /// Start or resume playback
    func play() {
        Log.info("play() called - currentState: \(currentState), isPaused: \(isPaused), isPlaying: \(isPlaying)")
        
        guard currentState == "ready" || currentState == "paused" || currentState == "completed" else {
            Log.warning("play() ignored - invalid state: \(currentState)")
            return
        }
        
        stateLock.lock()
        let wasResumingFromPause = isPaused && isPlaying
        isPaused = false
        stateLock.unlock()
        
        if wasResumingFromPause {
            // Resume from pause - adjust playback start time to account for pause duration
            let pauseDuration = CFAbsoluteTimeGetCurrent() - pausedAtTime
            playbackStartTime += pauseDuration
            
            clockSync?.resume()
            audioPlayerNode?.play()
            Log.info("Resumed from pause - pause duration: \(Int(pauseDuration * 1000))ms")
        } else {
            // Start fresh playback (or restart after completed)
            if currentState == "completed" {
                // Reset for replay
                isFirstFrame = true
                firstFramePts = 0
                playbackStartTime = 0
                position = 0
                _ = demuxer?.seek(toMs: 0)
                videoDecoder?.flush()
                audioDecoder?.flush()
            }
            startPlayback()
            Log.debug("Started fresh playback")
        }
        
        updateState("playing")
        startProgressTimer()
    }
    
    /// Pause playback
    func pause() {
        Log.info("pause() called - currentState: \(currentState)")
        guard currentState == "playing" else { return }
        
        // Record pause time for resume
        pausedAtPts = position
        pausedAtTime = CFAbsoluteTimeGetCurrent()
        
        stateLock.lock()
        isPaused = true
        stateLock.unlock()
        
        clockSync?.pause()
        audioPlayerNode?.pause()
        stopProgressTimer()
        updateState("paused")
        
        Log.info("Paused at pts: \(pausedAtPts)ms")
    }
    
    /// Stop playback and reset to idle
    func stop() {
        Log.info("stop() called - currentState: \(currentState)")
        
        stateLock.lock()
        isPlaying = false
        isPaused = false
        stateLock.unlock()
        
        // Wait for decoding loop to exit (with timeout)
        var waitCount = 0
        while decodingLoopActive && waitCount < 200 {  // Max 2 seconds wait
            Thread.sleep(forTimeInterval: 0.01)
            waitCount += 1
        }
        
        if decodingLoopActive {
            Log.warning("Decoding loop did not exit within timeout")
        }
        
        stopProgressTimer()
        
        // Stop audio playback
        audioPlayerNode?.stop()
        
        // Flush audio buffers to prevent stale audio on next play
        audioDecoder?.flush()
        
        clockSync?.reset()
        position = 0
        isFirstFrame = true
        firstFramePts = 0
        playbackStartTime = 0
        
        // Clear pending frames
        frameQueueLock.lock()
        pendingFrames.removeAll()
        frameQueueLock.unlock()
        
        updateState("idle")
        
        // Clear texture to black - do this on main thread after state update
        DispatchQueue.main.async { [weak self] in
            self?.textureRenderer?.clear()
        }
        
        Log.info("Stopped - decoding loop exited: \(!decodingLoopActive)")
    }
    
    /// Seek to specific position
    /// - Parameter position: Target position in milliseconds
    func seekTo(position: Int64) {
        self.position = position
        
        guard let queue = playbackQueue else { return }
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Seek demuxer
            _ = self.demuxer?.seek(toMs: position)
            
            // Flush decoders
            self.videoDecoder?.flush()
            self.audioDecoder?.flush()
            
            // Update clock
            self.clockSync?.seek(position)
            
            Log.info("Seeked to \(position)ms")
        }
    }
    
    /// Set volume level
    /// - Parameter volume: Volume (0.0 - 1.0)
    func setVolume(volume: Float) {
        self.volume = max(0.0, min(1.0, volume))
        // Apply volume if not muted
        if !isMuted {
            audioEngine?.mainMixerNode.outputVolume = self.volume
        }
        Log.info("Volume set to \(self.volume)")
    }
    
    /// Set muted state
    /// - Parameter muted: true to mute, false to unmute
    func setMuted(muted: Bool) {
        self.isMuted = muted
        audioEngine?.mainMixerNode.outputVolume = muted ? 0.0 : self.volume
        Log.info("Muted: \(muted)")
    }
    
    /// Get current muted state
    func getMuted() -> Bool {
        return isMuted
    }
    
    /// Set playback speed
    /// - Parameter speed: Speed multiplier (0.5 - 2.0)
    func setPlaybackSpeed(speed: Float) {
        self.playbackSpeed = max(0.5, min(2.0, speed))
        clockSync?.setSpeed(Double(speed))
    }
    
    /// Get current playback position
    /// - Returns: Position in milliseconds
    func getPosition() -> Int64 {
        // Use clock sync for accurate position
        return clockSync?.getCurrentPts() ?? position
    }
    
    /// Get media duration
    /// - Returns: Duration in milliseconds
    func getDuration() -> Int64 {
        return duration
    }
    
    /// Release all resources
    func release() {
        stop()
        
        audioEngine?.stop()
        audioEngine = nil
        audioPlayerNode = nil
        
        videoDecoder = nil
        audioDecoder = nil
        demuxer?.close()
        demuxer = nil
        textureRenderer = nil
        
        Log.info("Released")
    }
    
    // MARK: - Private Methods
    
    /// Start playback loop
    private func startPlayback() {
        stateLock.lock()
        isPlaying = true
        isPaused = false
        stateLock.unlock()
        
        // Reset frame timing for fresh playback
        isFirstFrame = true
        firstFramePts = 0
        playbackStartTime = 0
        lastFrameTime = 0
        
        // Start audio
        audioPlayerNode?.play()
        
        guard let queue = playbackQueue else {
            Log.error("playbackQueue is nil in startPlayback")
            return
        }
        
        queue.async { [weak self] in
            self?.decodingLoop()
        }
    }
    
    /// Main decoding loop - runs on playback queue
    private func decodingLoop() {
        Log.info("Decoding loop started")
        decodingLoopActive = true
        defer { decodingLoopActive = false }
        
        var packetCount = 0
        var videoPacketCount = 0
        
        while true {
            // Check state with lock
            stateLock.lock()
            let shouldContinue = isPlaying
            let shouldPause = isPaused
            stateLock.unlock()
            
            if !shouldContinue {
                Log.info("Decoding loop: isPlaying=false, exiting")
                break
            }
            
            // Handle pause
            if shouldPause {
                Thread.sleep(forTimeInterval: 0.02)
                continue
            }
            
            guard let demuxer = demuxer else {
                Log.warning("Demuxer is nil, breaking loop")
                break
            }
            
            // Read next packet
            guard let packet = demuxer.readPacket() else {
                // End of file - with synchronous decoding, all frames have been rendered
                Log.info("End of file reached - total packets: \(packetCount), video: \(videoPacketCount)")
                
                stateLock.lock()
                isPlaying = false
                stateLock.unlock()
                
                DispatchQueue.main.async { [weak self] in
                    self?.stopProgressTimer()
                    self?.updateState("completed")
                }
                break
            }
            
            packetCount += 1
            
            // Decode packet based on stream type
            if packet.isVideo {
                videoPacketCount += 1
                
                // Use synchronous decoding for proper frame-rate control
                // This blocks until the frame is decoded AND the callback completes
                // The callback (onVideoFrame) handles frame timing and rendering
                videoDecoder?.decodePacketSync(packet)
                
                // Check if we should continue after decoding
                stateLock.lock()
                var stillPlaying = isPlaying
                var stillPaused = isPaused
                stateLock.unlock()
                
                if !stillPlaying {
                    break
                }
                
                // Handle pause in decode loop - wait until resumed or stopped
                while stillPaused && stillPlaying {
                    Thread.sleep(forTimeInterval: 0.02)
                    stateLock.lock()
                    stillPaused = isPaused
                    stillPlaying = isPlaying
                    stateLock.unlock()
                }
                
                if !stillPlaying {
                    break
                }
            } else if packet.isAudio {
                audioDecoder?.decodePacket(packet)
            }
        }
        
        Log.info("Decoding loop ended")
    }
    
    /// Video frame callback - called by VideoToolbox decoder for each decoded frame
    /// - Parameters:
    ///   - pixelBuffer: Decoded frame
    ///   - pts: Presentation timestamp in milliseconds
    private func onVideoFrame(pixelBuffer: CVPixelBuffer, pts: Int64) {
        // First frame: initialize timing
        if isFirstFrame {
            playbackStartTime = CFAbsoluteTimeGetCurrent()
            firstFramePts = pts
            isFirstFrame = false
            lastFrameTime = playbackStartTime
            clockSync?.setMasterPts(pts)
            Log.info("First frame - pts: \(pts)ms, playback clock initialized")
        }
        
        // Check if paused - if paused, skip this frame (decode loop handles pause)
        stateLock.lock()
        let paused = isPaused
        stateLock.unlock()
        
        if paused {
            return
        }
        
        // Frame rate control: calculate when this frame should be displayed
        let relativePts = pts - firstFramePts  // Time since first frame in ms
        let targetTime = playbackStartTime + (Double(relativePts) / 1000.0) / Double(playbackSpeed)
        let now = CFAbsoluteTimeGetCurrent()
        let waitTime = targetTime - now
        
        // If frame is early, wait for the right time
        if waitTime > 0.001 {
            // Cap wait time to reasonable bounds (max 500ms to allow recovery from stalls)
            let cappedWait = min(waitTime, 0.5)
            Thread.sleep(forTimeInterval: cappedWait)
        }
        
        // Update position for progress reporting
        position = pts
        lastFrameTime = CFAbsoluteTimeGetCurrent()
        
        // Render to texture synchronously to maintain timing
        if let renderer = textureRenderer {
            DispatchQueue.main.sync {
                renderer.updateWithPixelBuffer(pixelBuffer, pts: pts)
            }
        }
    }
    
    /// Audio frame callback - called by audio decoder for each decoded audio frame
    /// - Parameters:
    ///   - audioData: Decoded PCM audio data
    ///   - pts: Presentation timestamp in milliseconds
    ///   - sampleCount: Number of samples in the audio data
    private func onAudioFrame(audioData: Data, pts: Int64, sampleCount: Int) {
        guard let engine = audioEngine,
              let playerNode = audioPlayerNode,
              let format = audioFormat else {
            Log.warning("onAudioFrame: audioEngine, playerNode or format is nil")
            return
        }
        
        // Ensure audio engine is running
        if !engine.isRunning {
            do {
                try engine.start()
                Log.debug("Audio engine started in onAudioFrame")
            } catch {
                Log.error("Failed to start audio engine: \(error.localizedDescription)")
                return
            }
        }
        
        // Convert Data to AVAudioPCMBuffer using actual sample count
        let frameCount = UInt32(sampleCount)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            Log.warning("Failed to allocate AVAudioPCMBuffer")
            return
        }
        
        buffer.frameLength = frameCount
        
        // Copy audio data with volume scaling
        audioData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            if let floatData = buffer.floatChannelData {
                let srcPtr = bytes.bindMemory(to: Float.self)
                for i in 0..<Int(frameCount) {
                    for ch in 0..<Int(format.channelCount) {
                        floatData[ch][i] = srcPtr[i * Int(format.channelCount) + ch] * volume
                    }
                }
            }
        }
        
        // Schedule buffer for playback
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        
        // Ensure player node is running
        if !playerNode.isPlaying {
            playerNode.play()
            Log.debug("Audio player node started playing")
        }
    }
    
    /// Update player state and notify Flutter
    /// - Parameter state: New state ("idle", "ready", "playing", "paused", "completed", "error")
    private func updateState(_ state: String) {
        Log.info("State change: \(currentState) -> \(state)")
        currentState = state
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.eventSink?([
                "type": "state",
                "state": state
            ])
        }
    }
    
    /// Start progress timer - sends periodic position updates to Flutter
    private func startProgressTimer() {
        stopProgressTimer()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            Log.info("Starting progress timer (interval: 500ms)")
            
            self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                let currentPosition = self.getPosition()
                let bufferedPosition = currentPosition // TODO: Implement actual buffering
                let bufferPercentage = self.duration > 0 ? Double(bufferedPosition) / Double(self.duration) : 0.0
                
                // Send progress event to Flutter
                self.eventSink?([
                    "type": "progress",
                    "position": currentPosition,
                    "duration": self.duration,
                    "bufferedPosition": bufferedPosition,
                    "bufferPercentage": bufferPercentage
                ])
                
                Log.debug("Progress: \(currentPosition)ms / \(self.duration)ms (\(Int(bufferPercentage * 100))%)")
            }
        }
    }
    
    /// Stop progress timer
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
