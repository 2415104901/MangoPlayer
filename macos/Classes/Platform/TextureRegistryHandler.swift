import FlutterMacOS
import Foundation
import CoreVideo
import Metal

class TextureRegistryHandler: NSObject {
    private var channel: FlutterMethodChannel?
    private let registry: FlutterTextureRegistry
    private var textureManagers = [Int64: MetalTextureRenderer]()
    
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
            let renderer = MetalTextureRenderer(registry: registry)
            let textureId = registry.register(renderer)
            renderer.textureId = textureId
            textureManagers[textureId] = renderer
            result(["success": true, "textureId": textureId])
            
        case "unregisterTexture":
            guard let args = call.arguments as? [String: Any],
                  let textureId = (args["textureId"] as? NSNumber)?.int64Value else {
                result(FlutterError(code: "invalid_arguments", message: "textureId is null", details: nil))
                return
            }
            if let renderer = textureManagers.removeValue(forKey: textureId) {
                renderer.dispose()
                registry.unregisterTexture(textureId)
                result(["success": true])
            } else {
                result(FlutterError(code: "invalid_arguments", message: "texture not found", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func getTextureRenderer(textureId: Int64) -> MetalTextureRenderer? {
        return textureManagers[textureId]
    }
}
