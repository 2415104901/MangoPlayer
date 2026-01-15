# MangoPlayer Platform Channel API Contract

**Protocol**: Platform Channel (Method Channel + Event Channel)
**Platform**: Flutter ↔ Native (Android/iOS/Windows/macOS)

本文档定义 Dart 层与 Native 层之间的通信契约。

---

## Method Channel: `com.mangoplayer/player`

### 1. initialize

**描述**: 初始化播放器并加载媒体源

**Dart → Native**:
```json
{
  "method": "initialize",
  "arguments": {
    "uri": "https://example.com/video.mp4",
    "type": "network",  // "network" | "file" | "asset"
    "headers": {        // 可选
      "Authorization": "Bearer token"
    },
    "mimeType": "video/mp4"  // 可选
  }
}
```

**Native → Dart**:
```json
{
  "success": true,
  "duration": 120000  // 媒体总时长 (毫秒)
}
```

**Error Response**:
```json
{
  "success": false,
  "code": "source_not_found",  // PlayerErrorCode
  "message": "Media file not found",
  "platformDetails": {...}  // 平台特定详情 (可选)
}
```

---

### 2. play

**描述**: 开始播放

**Dart → Native**:
```json
{
  "method": "play",
  "arguments": null
}
```

**Native → Dart**:
```json
{
  "success": true
}
```

---

### 3. pause

**描述**: 暂停播放

**Dart → Native**:
```json
{
  "method": "pause",
  "arguments": null
}
```

**Native → Dart**:
```json
{
  "success": true
}
```

---

### 4. stop

**描述**: 停止播放并释放资源

**Dart → Native**:
```json
{
  "method": "stop",
  "arguments": null
}
```

**Native → Dart**:
```json
{
  "success": true
}
```

---

### 5. seekTo

**描述**: 跳转到指定位置

**Dart → Native**:
```json
{
  "method": "seekTo",
  "arguments": {
    "position": 30000  // 目标位置 (毫秒)
  }
}
```

**Native → Dart**:
```json
{
  "success": true,
  "actualPosition": 30120  // 实际跳转位置 (毫秒，可能与请求位置略有偏差)
}
```

---

### 6. setVolume

**描述**: 设置音量

**Dart → Native**:
```json
{
  "method": "setVolume",
  "arguments": {
    "volume": 0.8  // 音量级别 (0.0-1.0)
  }
}
```

**Native → Dart**:
```json
{
  "success": true
}
```

**Validation**:
- `volume` 必须在 [0.0, 1.0] 范围内

---

### 7. setPlaybackSpeed

**描述**: 设置播放速度

**Dart → Native**:
```json
{
  "method": "setPlaybackSpeed",
  "arguments": {
    "speed": 1.5  // 播放速度 (0.5-2.0)
  }
}
```

**Native → Dart**:
```json
{
  "success": true
}
```

**Validation**:
- `speed` 必须在 [0.5, 2.0] 范围内

---

### 8. getPosition

**描述**: 获取当前播放位置

**Dart → Native**:
```json
{
  "method": "getPosition",
  "arguments": null
}
```

**Native → Dart**:
```json
{
  "success": true,
  "position": 45000  // 当前位置 (毫秒)
}
```

---

### 9. getDuration

**描述**: 获取媒体总时长

**Dart → Native**:
```json
{
  "method": "getDuration",
  "arguments": null
}
```

**Native → Dart**:
```json
{
  "success": true,
  "duration": 120000  // 总时长 (毫秒)
}
```

---

### 10. dispose

**描述**: 释放播放器资源

**Dart → Native**:
```json
{
  "method": "dispose",
  "arguments": null
}
```

**Native → Dart**:
```json
{
  "success": true
}
```

---

## Event Channel: `com.mangoplayer/events`

**描述**: 播放事件流 (State/Progress/Buffer/Error)

**Native → Dart** (持续推送):

### Event: StateChanged
```json
{
  "type": "state",
  "state": "playing",  // "idle" | "initializing" | "ready" | "playing" | "paused" | "buffering" | "completed" | "error"
  "timestamp": 1703246400000
}
```

### Event: ProgressUpdate
```json
{
  "type": "progress",
  "position": 45000,          // 当前位置 (毫秒)
  "duration": 120000,         // 总时长 (毫秒)
  "bufferedPosition": 50000,  // 缓冲位置 (毫秒)
  "bufferPercentage": 0.42,   // 缓冲百分比 (0.0-1.0)
  "timestamp": 1703246400000
}
```

**更新频率**: 默认 500ms，可通过配置调整

### Event: BufferingUpdate
```json
{
  "type": "buffering",
  "isBuffering": true,
  "bufferPercentage": 0.15,
  "timestamp": 1703246400000
}
```

### Event: Error
```json
{
  "type": "error",
  "code": "decoding_error",  // PlayerErrorCode
  "message": "Failed to decode video frame",
  "platformDetails": {
    "nativeErrorCode": -11828,
    "nativeMessage": "Codec error"
  },
  "timestamp": 1703246400000
}
```

### Event: Completed
```json
{
  "type": "completed",
  "timestamp": 1703246400000
}
```

---

## Texture Channel: `com.mangoplayer/texture`

**描述**: External Texture 注册和更新

### 1. registerTexture

**Dart → Native**:
```json
{
  "method": "registerTexture",
  "arguments": null
}
```

**Native → Dart**:
```json
{
  "success": true,
  "textureId": 12345  // Flutter Texture ID
}
```

### 2. unregisterTexture

**Dart → Native**:
```json
{
  "method": "unregisterTexture",
  "arguments": {
    "textureId": 12345
  }
}
```

**Native → Dart**:
```json
{
  "success": true
}
```

---

## Provider Registry Channel: `com.mangoplayer/providers`

**描述**: 模块注册和查询 (可选，用于自定义模块)

### 1. registerProvider

**Dart → Native**:
```json
{
  "method": "registerProvider",
  "arguments": {
    "type": "decoder",  // "dataSource" | "decoder" | "renderer"
    "name": "custom_h265",
    "className": "com.example.CustomH265Decoder"  // Native 类名
  }
}
```

**Native → Dart**:
```json
{
  "success": true
}
```

### 2. getProviderInfo

**Dart → Native**:
```json
{
  "method": "getProviderInfo",
  "arguments": {
    "type": "decoder",
    "name": "h265"
  }
}
```

**Native → Dart**:
```json
{
  "success": true,
  "info": {
    "supportsHardware": true,
    "supportedCodecs": ["h264", "h265"],
    "version": "1.0.0"
  }
}
```

---

## Error Codes (PlayerErrorCode)

所有平台必须使用统一的错误码：

```dart
enum PlayerErrorCode {
  // 初始化错误
  "source_not_found",       // 媒体源不存在
  "source_not_supported",   // 不支持的媒体格式
  "network_error",          // 网络错误
  
  // 播放错误
  "decoding_error",         // 解码错误
  "rendering_error",        // 渲染错误
  "buffer_underrun",        // 缓冲不足
  
  // 系统错误
  "platform_not_supported", // 平台不支持
  "permission_denied",      // 权限被拒绝
  "unknown",                // 未知错误
}
```

---

## Platform-Specific Implementations

### Android (Kotlin)

```kotlin
class MangoPlayerPlugin : FlutterPlugin, MethodCallHandler {
  private val methodChannel = MethodChannel(binaryMessenger, "com.mangoplayer/player")
  private val eventChannel = EventChannel(binaryMessenger, "com.mangoplayer/events")
  private val textureChannel = MethodChannel(binaryMessenger, "com.mangoplayer/texture")
  
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initialize" -> handleInitialize(call, result)
      "play" -> handlePlay(result)
      "pause" -> handlePause(result)
      // ... 其他方法
    }
  }
  
  private fun handleInitialize(call: MethodCall, result: Result) {
    val uri = call.argument<String>("uri")!!
    val type = call.argument<String>("type")!!
    val headers = call.argument<Map<String, String>>("headers")
    
    try {
      // 初始化逻辑
      val duration = playerController.initialize(uri, type, headers)
      result.success(mapOf("success" to true, "duration" to duration))
    } catch (e: Exception) {
      result.error("initialization_error", e.message, null)
    }
  }
}
```

### iOS (Swift)

```swift
public class MangoPlayerPlugin: NSObject, FlutterPlugin {
  let methodChannel: FlutterMethodChannel
  let eventChannel: FlutterEventChannel
  let textureChannel: FlutterMethodChannel
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      handleInitialize(call, result)
    case "play":
      handlePlay(result)
    case "pause":
      handlePause(result)
    // ... 其他方法
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func handleInitialize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let uri = args["uri"] as? String,
          let type = args["type"] as? String else {
      result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
      return
    }
    
    do {
      let duration = try playerController.initialize(uri: uri, type: type)
      result(["success": true, "duration": duration])
    } catch {
      result(FlutterError(code: "initialization_error", message: error.localizedDescription, details: nil))
    }
  }
}
```

---

## Cross-Platform Consistency Requirements

**所有平台实现必须保证**:

1. **方法签名一致**: 相同的 method 名称和 arguments 结构
2. **返回值一致**: 相同输入产生相同输出结构
3. **错误码统一**: 使用 `PlayerErrorCode` 枚举，不暴露平台特定错误码
4. **时间单位统一**: 所有时间值使用毫秒 (milliseconds)
5. **状态值统一**: PlayerState 字符串值完全一致
6. **异步行为一致**: 所有方法均为异步 (Future)，事件流持续推送

**验证方法**: 集成测试必须在所有平台运行相同测试用例，验证一致性。

---

## 总结

**Method Channel**: 10 个方法 (initialize, play, pause, stop, seekTo, setVolume, setPlaybackSpeed, getPosition, getDuration, dispose)

**Event Channel**: 5 种事件类型 (state, progress, buffering, error, completed)

**Texture Channel**: 2 个方法 (registerTexture, unregisterTexture)

**Provider Channel**: 2 个方法 (registerProvider, getProviderInfo)

**Error Codes**: 10 个统一错误码

**跨平台一致性**: 已明确所有要求

**进入阶段 1.3: 生成 quickstart.md**
