import Flutter
import Foundation

class EventChannelHandler: NSObject, FlutterStreamHandler {
    private var channel: FlutterEventChannel?
    private let messenger: FlutterBinaryMessenger
    private let playerManager: IJKPlayerManager
    private var eventSink: FlutterEventSink?
    
    init(messenger: FlutterBinaryMessenger, playerManager: IJKPlayerManager) {
        self.messenger = messenger
        self.playerManager = playerManager
    }
    
    func startListening() {
        channel = FlutterEventChannel(name: "com.mangoplayer/events", binaryMessenger: messenger)
        channel?.setStreamHandler(self)
    }
    
    func stopListening() {
        channel?.setStreamHandler(nil)
        channel = nil
        eventSink = nil
        playerManager.setEventSink(sink: nil)
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        playerManager.setEventSink(sink: events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        playerManager.setEventSink(sink: nil)
        return nil
    }
}
