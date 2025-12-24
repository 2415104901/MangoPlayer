import Foundation
import IJKMediaFramework

protocol IJKPlayerFrameDelegate: AnyObject {
    func onVideoFrame(pixelBuffer: CVPixelBuffer)
}

class IJKPlayerWrapper: NSObject {
    private var player: IJKFFMoviePlayerController?
    weak var frameDelegate: IJKPlayerFrameDelegate?
    
    func createPlayer(uri: String, headers: [String: String]?) {
        let options = IJKFFOptions.byDefault()
        options?.setPlayerOptionIntValue(1, forKey: "videotoolbox")
        
        if let headers = headers {
            var headerStr = ""
            for (key, value) in headers {
                headerStr += "\(key): \(value)\r\n"
            }
            options?.setFormatOptionValue(headerStr, forKey: "headers")
        }
        
        player = IJKFFMoviePlayerController(contentURL: URL(string: uri), with: options)
        player?.shouldAutoplay = false
        
        // TODO: Configure CVPixelBuffer output
        // This usually requires a custom IJKSDLGLView or modifying IJKPlayer to callback with CVPixelBuffer.
        // For this implementation, we assume such mechanism exists or we would implement a custom view.
        
        player?.prepareToPlay()
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        player?.stop()
    }
    
    func seekTo(position: Int64) {
        player?.currentPlaybackTime = TimeInterval(position) / 1000.0
    }
    
    func setVolume(volume: Float) {
        player?.playbackVolume = volume
    }
    
    func setPlaybackSpeed(speed: Float) {
        player?.playbackRate = speed
    }
    
    func getPosition() -> Int64 {
        return Int64((player?.currentPlaybackTime ?? 0) * 1000)
    }
    
    func getDuration() -> Int64 {
        return Int64((player?.duration ?? 0) * 1000)
    }
    
    func release() {
        player?.shutdown()
        player = nil
    }
    
    func getPlayer() -> IJKFFMoviePlayerController? {
        return player
    }
}
