import Foundation
import Flutter
import IJKMediaFramework

class IJKPlayerManager: NSObject, IJKPlayerFrameDelegate {
    private let playerWrapper = IJKPlayerWrapper()
    private var eventSink: FlutterEventSink?
    private var textureRegistryHandler: TextureRegistryHandler?
    private var currentTextureId: Int64?
    
    override init() {
        super.init()
        playerWrapper.frameDelegate = self
        setupListeners()
    }
    
    func setTextureRegistryHandler(handler: TextureRegistryHandler?) {
        self.textureRegistryHandler = handler
    }
    
    private func setupListeners() {
        NotificationCenter.default.addObserver(self, selector: #selector(onStateChanged), name: NSNotification.Name.IJKMPMoviePlayerLoadStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onPlaybackFinished), name: NSNotification.Name.IJKMPMoviePlayerPlaybackDidFinish, object: nil)
        // Add more listeners
    }
    
    @objc private func onStateChanged(notification: Notification) {
        guard let player = playerWrapper.getPlayer() else { return }
        let loadState = player.loadState
        if loadState.contains(.playthroughOK) {
            eventSink?(["type": "state", "state": "ready"])
            eventSink?(["type": "progress", "duration": playerWrapper.getDuration()])
        } else if loadState.contains(.stalled) {
            eventSink?(["type": "buffering", "isBuffering": true])
        }
    }
    
    @objc private func onPlaybackFinished(notification: Notification) {
        eventSink?(["type": "state", "state": "completed"])
        eventSink?(["type": "completed"])
    }
    
    func initialize(uri: String, type: String, headers: [String: String]?, result: @escaping FlutterResult, textureId: Int64?) {
        self.currentTextureId = textureId
        playerWrapper.createPlayer(uri: uri, headers: headers)
        eventSink?(["type": "state", "state": "initializing"])
        result(["success": true, "duration": 0])
    }
    
    func play() {
        playerWrapper.play()
        eventSink?(["type": "state", "state": "playing"])
    }
    
    func pause() {
        playerWrapper.pause()
        eventSink?(["type": "state", "state": "paused"])
    }
    
    func stop() {
        playerWrapper.stop()
        eventSink?(["type": "state", "state": "idle"])
    }
    
    func seekTo(position: Int64) {
        playerWrapper.seekTo(position: position)
    }
    
    func setVolume(volume: Float) {
        playerWrapper.setVolume(volume: volume)
    }
    
    func setPlaybackSpeed(speed: Float) {
        playerWrapper.setPlaybackSpeed(speed: speed)
    }
    
    func getPosition() -> Int64 {
        return playerWrapper.getPosition()
    }
    
    func getDuration() -> Int64 {
        return playerWrapper.getDuration()
    }
    
    func release() {
        playerWrapper.release()
        NotificationCenter.default.removeObserver(self)
    }
    
    func setEventSink(sink: FlutterEventSink?) {
        self.eventSink = sink
    }
    
    // IJKPlayerFrameDelegate
    func onVideoFrame(pixelBuffer: CVPixelBuffer) {
        if let textureId = currentTextureId, let manager = textureRegistryHandler?.getTextureManager(textureId: textureId) {
            manager.updatePixelBuffer(pixelBuffer)
        }
    }
}
