import Foundation
import Flutter

/// 解码事件桥接器
///
/// 将 ijkplayer/VideoToolbox 的解码事件桥接到 Dart 层。
/// 支持硬解/软解切换通知、解码器信息、性能指标等事件。
///
/// 任务: T110 [US6]
public class DecodeEventBridge: NSObject, FlutterStreamHandler {
    
    // MARK: - Event Types
    
    public enum EventType: String {
        case decoderChanged = "decoderChanged"
        case fallback = "fallback"
        case performance = "performance"
        case error = "error"
        case info = "info"
    }
    
    // MARK: - Data Structures
    
    /// 解码器信息事件
    public struct DecoderInfoEvent {
        let codecName: String
        let codecType: String  // "hardware" or "software"
        let mimeType: String?
        let width: Int
        let height: Int
    }
    
    /// 降级事件
    public struct FallbackEvent {
        let fromCodec: String
        let toCodec: String
        let reason: String
        let timestamp: TimeInterval
    }
    
    /// 性能指标事件
    public struct PerformanceEvent {
        let decodeTimeMs: Int64
        let frameDropCount: Int
        let bufferLevel: Int
        let timestamp: TimeInterval
    }
    
    // MARK: - Properties
    
    private var eventSink: FlutterEventSink?
    private var pendingEvents: [[String: Any]] = []
    private let eventQueue = DispatchQueue(label: "com.mangoplayer.decode.events")
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        // 发送所有待发送的事件
        eventQueue.async { [weak self] in
            guard let self = self else { return }
            for event in self.pendingEvents {
                self.sendToFlutter(event)
            }
            self.pendingEvents.removeAll()
        }
        
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    // MARK: - Public Methods
    
    /// 发送解码器变更事件
    public func sendDecoderChanged(info: DecoderInfoEvent) {
        let event: [String: Any] = [
            "type": EventType.decoderChanged.rawValue,
            "data": [
                "codecName": info.codecName,
                "codecType": info.codecType,
                "mimeType": info.mimeType ?? "",
                "width": info.width,
                "height": info.height,
                "timestamp": Date().timeIntervalSince1970 * 1000
            ]
        ]
        sendEvent(event)
    }
    
    /// 发送降级事件
    public func sendFallback(event: FallbackEvent) {
        let eventData: [String: Any] = [
            "type": EventType.fallback.rawValue,
            "data": [
                "fromCodec": event.fromCodec,
                "toCodec": event.toCodec,
                "reason": event.reason,
                "timestamp": event.timestamp
            ]
        ]
        sendEvent(eventData)
    }
    
    /// 发送性能指标事件
    public func sendPerformance(event: PerformanceEvent) {
        let eventData: [String: Any] = [
            "type": EventType.performance.rawValue,
            "data": [
                "decodeTimeMs": event.decodeTimeMs,
                "frameDropCount": event.frameDropCount,
                "bufferLevel": event.bufferLevel,
                "timestamp": event.timestamp
            ]
        ]
        sendEvent(eventData)
    }
    
    /// 发送错误事件
    public func sendError(code: String, message: String, details: [String: Any]? = nil) {
        let event: [String: Any] = [
            "type": EventType.error.rawValue,
            "data": [
                "code": code,
                "message": message,
                "details": details ?? [:],
                "timestamp": Date().timeIntervalSince1970 * 1000
            ]
        ]
        sendEvent(event)
    }
    
    /// 发送信息事件
    public func sendInfo(_ info: String, data: [String: Any]? = nil) {
        let event: [String: Any] = [
            "type": EventType.info.rawValue,
            "data": [
                "info": info,
                "data": data ?? [:],
                "timestamp": Date().timeIntervalSince1970 * 1000
            ]
        ]
        sendEvent(event)
    }
    
    /// 根据 ijkplayer 的解码器标志判断解码器类型
    public func parseDecoderType(flags: Int) -> String {
        // ijkplayer 解码器标志位
        // AVCODEC_HW_DECODER = 0x01
        return (flags & 0x01) != 0 ? "hardware" : "software"
    }
    
    /// 从 ijkplayer 的 notification 解析解码器信息
    ///
    /// - Parameters:
    ///   - notification: ijkplayer 发送的通知名称
    ///   - userInfo: 通知携带的信息
    public func handleIjkNotification(notification: String, userInfo: [AnyHashable: Any]?) {
        switch notification {
        case "IJKMPMoviePlayerFirstVideoFrameRenderedNotification":
            sendInfo("video_rendering_started", data: userInfo as? [String: Any])
            
        case "IJKMPMoviePlayerFirstAudioFrameRenderedNotification":
            sendInfo("audio_rendering_started", data: userInfo as? [String: Any])
            
        case "IJKMPMoviePlayerVideoDecoderOpenNotification":
            if let decoderType = userInfo?["decoder_type"] as? String {
                sendInfo("decoder_type", data: ["type": decoderType])
            }
            
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func sendEvent(_ event: [String: Any]) {
        eventQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.eventSink != nil {
                self.sendToFlutter(event)
            } else {
                // 缓存事件，等待监听器连接
                self.pendingEvents.append(event)
            }
        }
    }
    
    private func sendToFlutter(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }
    
    // MARK: - Cleanup
    
    public func dispose() {
        eventSink = nil
        pendingEvents.removeAll()
    }
}
