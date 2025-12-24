import Flutter
import Foundation

class TextureRegistryHandler: NSObject {
    private var channel: FlutterMethodChannel?
    private let registry: FlutterTextureRegistry
    private var textureManagers = [Int64: CVPixelBufferManager]()
    
    init(registry: FlutterTextureRegistry) {
        self.registry = registry
    }
    
    func startListening(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.mangoplayer/texture", binaryMessenger: messenger)
        channel?.setMethodCallHandler(handle)
    }
    
    func stopListening() {
        channel?.setMethodCallHandler(nil)
        channel = nil
        textureManagers.values.forEach { $0.dispose() }
        textureManagers.removeAll()
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "registerTexture":
            let manager = CVPixelBufferManager(registry: registry)
            let textureId = registry.register(manager)
            manager.textureId = textureId
            textureManagers[textureId] = manager
            result(["success": true, "textureId": textureId])
            
        case "unregisterTexture":
            guard let args = call.arguments as? [String: Any],
                  let textureId = (args["textureId"] as? NSNumber)?.int64Value else {
                result(FlutterError(code: "invalid_arguments", message: "textureId is null", details: nil))
                return
            }
            if let manager = textureManagers.removeValue(forKey: textureId) {
                manager.dispose()
                registry.unregisterTexture(textureId)
                result(["success": true])
            } else {
                result(FlutterError(code: "invalid_arguments", message: "texture not found", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func getTextureManager(textureId: Int64) -> CVPixelBufferManager? {
        return textureManagers[textureId]
    }
}
