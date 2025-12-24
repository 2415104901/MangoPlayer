import FlutterMacOS
import Foundation

class MethodChannelHandler: NSObject {
    private var channel: FlutterMethodChannel?
    private let messenger: FlutterBinaryMessenger
    private let playerManager: FFmpegPlayerManager
    private let textureRegistryHandler: TextureRegistryHandler
    
    init(messenger: FlutterBinaryMessenger, playerManager: FFmpegPlayerManager, textureRegistryHandler: TextureRegistryHandler) {
        self.messenger = messenger
        self.playerManager = playerManager
        self.textureRegistryHandler = textureRegistryHandler
    }
    
    func startListening() {
        channel = FlutterMethodChannel(name: "com.mangoplayer/player", binaryMessenger: messenger)
        channel?.setMethodCallHandler(handle)
    }
    
    func stopListening() {
        channel?.setMethodCallHandler(nil)
        channel = nil
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            guard let args = call.arguments as? [String: Any],
                  let uri = args["uri"] as? String,
                  let type = args["type"] as? String else {
                result(FlutterError(code: "invalid_arguments", message: "uri or type is null", details: nil))
                return
            }
            let headers = args["headers"] as? [String: String]
            let textureId = (args["textureId"] as? NSNumber)?.int64Value
            
            playerManager.initialize(uri: uri, type: type, headers: headers, result: result, textureId: textureId)
            
        case "play":
            playerManager.play()
            result(["success": true])
            
        case "pause":
            playerManager.pause()
            result(["success": true])
            
        case "stop":
            playerManager.stop()
            result(["success": true])
            
        case "seekTo":
            guard let args = call.arguments as? [String: Any],
                  let position = args["position"] as? Int else {
                result(FlutterError(code: "invalid_arguments", message: "position is null", details: nil))
                return
            }
            playerManager.seekTo(position: Int64(position))
            result(["success": true, "actualPosition": position])
            
        case "setVolume":
            guard let args = call.arguments as? [String: Any],
                  let volume = args["volume"] as? Double else {
                result(FlutterError(code: "invalid_arguments", message: "volume is null", details: nil))
                return
            }
            playerManager.setVolume(volume: Float(volume))
            result(["success": true])
            
        case "setPlaybackSpeed":
            guard let args = call.arguments as? [String: Any],
                  let speed = args["speed"] as? Double else {
                result(FlutterError(code: "invalid_arguments", message: "speed is null", details: nil))
                return
            }
            playerManager.setPlaybackSpeed(speed: Float(speed))
            result(["success": true])
            
        case "getPosition":
            let position = playerManager.getPosition()
            result(["success": true, "position": position])
            
        case "getDuration":
            let duration = playerManager.getDuration()
            result(["success": true, "duration": duration])
            
        case "dispose":
            playerManager.release()
            result(["success": true])
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
