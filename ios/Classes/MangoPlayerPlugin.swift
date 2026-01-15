import Flutter
import UIKit

public class MangoPlayerPlugin: NSObject, FlutterPlugin {
  var methodChannelHandler: MethodChannelHandler?
  var eventChannelHandler: EventChannelHandler?
  var textureRegistryHandler: TextureRegistryHandler?
  var playerManager: IJKPlayerManager?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MangoPlayerPlugin()
    instance.setup(registrar: registrar)
  }
  
  private func setup(registrar: FlutterPluginRegistrar) {
    playerManager = IJKPlayerManager()
    
    textureRegistryHandler = TextureRegistryHandler(registry: registrar.textures())
    playerManager?.setTextureRegistryHandler(handler: textureRegistryHandler)
    
    methodChannelHandler = MethodChannelHandler(messenger: registrar.messenger(), playerManager: playerManager!, textureRegistryHandler: textureRegistryHandler!)
    eventChannelHandler = EventChannelHandler(messenger: registrar.messenger(), playerManager: playerManager!)
    
    methodChannelHandler?.startListening()
    eventChannelHandler?.startListening()
    textureRegistryHandler?.startListening(messenger: registrar.messenger())
  }
  
  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    methodChannelHandler?.stopListening()
    eventChannelHandler?.stopListening()
    textureRegistryHandler?.stopListening()
    playerManager?.release()
  }
}
