# 数据模型: MangoPlayer

**功能**: MangoPlayer 跨平台音视频播放器插件
**日期**: 2025-12-22
**阶段**: Phase 1 - Design

本文档定义 MangoPlayer 的核心数据模型、实体关系和状态转换。

---

## 核心实体

### 1. MangoPlayerController

**职责**: 播放器控制器，管理播放生命周期和状态

```dart
class MangoPlayerController {
  // === 状态 ===
  PlayerState state;              // 当前播放状态
  MediaSource? currentSource;     // 当前媒体源
  Duration position;              // 当前播放位置
  Duration duration;              // 总时长
  double volume;                  // 音量 (0.0-1.0)
  double playbackSpeed;           // 播放速度 (0.5-2.0)
  
  // === 事件流 ===
  Stream<PlayerState> stateStream;        // 状态变化流
  Stream<PlaybackEvent> eventStream;      // 播放事件流
  Stream<PlayerError> errorStream;        // 错误事件流
  
  // === 控制方法 ===
  Future<void> initialize(MediaSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seekTo(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> dispose();
}
```

**字段说明**:
- `state`: 播放器状态机，见 `PlayerState` 枚举
- `currentSource`: 当前加载的媒体源，null 表示未初始化
- `position`: 当前播放位置，更新频率可配置 (默认 500ms)
- `duration`: 媒体总时长，初始化后可用
- `volume`: 音量级别，0.0 (静音) ~ 1.0 (最大)
- `playbackSpeed`: 播放速度，0.5 (慢速) ~ 2.0 (快速)

**关系**:
- 1:1 → `MediaSource` (当前加载的媒体)
- 1:N → `PlaybackEvent` (发出的事件)
- 1:N → `PlayerError` (发出的错误)

---

### 2. PlayerState

**职责**: 播放器状态枚举

```dart
enum PlayerState {
  idle,           // 空闲状态，未初始化
  initializing,   // 初始化中 (加载媒体)
  ready,          // 就绪，可以播放
  playing,        // 播放中
  paused,         // 已暂停
  buffering,      // 缓冲中 (网络视频)
  completed,      // 播放完成
  error,          // 错误状态
}
```

**状态转换图**:

```
     idle
      ↓ initialize()
  initializing
      ↓
    ready ←───────┐
   ↓  ↓  ↓       │
play pause buffering
   ↓   ↓    ↓     │
playing paused  │
   ↓   ↓    ↓     │
   ↓   └────┘     │
   ↓ (seek)       │
buffering ────────┘
   ↓
completed
   
任何状态 → error (发生错误)
任何状态 → idle (stop/dispose)
```

**验证规则**:
- `idle` 状态下不能调用 `play()/pause()/seek()`
- `initializing` 状态下操作被缓冲，等待 `ready` 后执行
- `error` 状态下需要重新 `initialize()`

---

### 3. MediaSource

**职责**: 媒体源抽象，封装媒体 URI 和元数据

```dart
class MediaSource {
  final Uri uri;                    // 媒体 URI
  final MediaSourceType type;       // 媒体类型
  final Map<String, String>? headers; // HTTP 请求头 (可选)
  final String? mimeType;           // MIME 类型提示 (可选)
  
  // 工厂方法
  factory MediaSource.network(String url, {Map<String, String>? headers});
  factory MediaSource.file(String path);
  factory MediaSource.asset(String assetPath);
}

enum MediaSourceType {
  network,      // 网络资源 (HTTP/HTTPS/HLS/RTMP/RTSP)
  file,         // 本地文件
  asset,        // Flutter Asset
}
```

**字段说明**:
- `uri`: 统一资源标识符，支持多种协议
  - `http://` / `https://`: 网络视频
  - `file://`: 本地文件
  - `asset://`: Flutter Asset
  - `rtmp://`: RTMP 直播流
  - `rtsp://`: RTSP 监控流
- `type`: 媒体源类型，用于选择 DataSourceProvider
- `headers`: 自定义 HTTP 请求头 (如认证 token)
- `mimeType`: MIME 类型提示，辅助解码器选择

**示例**:
```dart
// 网络视频
var source = MediaSource.network(
  'https://example.com/video.mp4',
  headers: {'Authorization': 'Bearer token'}
);

// 本地文件
var source = MediaSource.file('/path/to/video.mp4');

// HLS 流
var source = MediaSource.network('https://example.com/stream.m3u8');
```

---

### 4. PlaybackEvent

**职责**: 播放事件，包含位置、缓冲进度等信息

```dart
class PlaybackEvent {
  final Duration position;          // 当前播放位置
  final Duration duration;          // 总时长
  final Duration bufferedPosition;  // 缓冲位置
  final double bufferPercentage;    // 缓冲百分比 (0.0-1.0)
  final PlayerState state;          // 当前状态
  final bool isPlaying;             // 是否正在播放
  final bool isBuffering;           // 是否正在缓冲
}
```

**字段说明**:
- `position`: 当前播放位置，实时更新
- `bufferedPosition`: 已缓冲的最远位置
- `bufferPercentage`: 缓冲百分比，用于显示缓冲进度条
- `isPlaying`: 快捷属性，等价于 `state == PlayerState.playing`
- `isBuffering`: 快捷属性，等价于 `state == PlayerState.buffering`

**更新频率**: 默认 500ms，可通过配置调整

---

### 5. PlayerError

**职责**: 错误信息实体，包含错误码、错误消息和平台详情

```dart
class PlayerError {
  final PlayerErrorCode code;       // 错误码
  final String message;             // 错误消息
  final dynamic platformDetails;    // 平台特定详情 (可选)
  final StackTrace? stackTrace;     // 堆栈追踪 (Debug 模式)
}

enum PlayerErrorCode {
  // 初始化错误
  sourceNotFound,           // 媒体源不存在
  sourceNotSupported,       // 不支持的媒体格式
  networkError,             // 网络错误
  
  // 播放错误
  decodingError,            // 解码错误
  renderingError,           // 渲染错误
  bufferUnderrun,           // 缓冲不足
  
  // 系统错误
  platformNotSupported,     // 平台不支持
  permissionDenied,         // 权限被拒绝
  unknown,                  // 未知错误
}
```

**错误处理流程**:
```dart
controller.errorStream.listen((error) {
  switch (error.code) {
    case PlayerErrorCode.networkError:
      // 显示网络错误提示，提供重试按钮
      break;
    case PlayerErrorCode.sourceNotSupported:
      // 提示用户格式不支持
      break;
    default:
      // 通用错误处理
      break;
  }
});
```

---

### 6. PlayerConfig

**职责**: 播放器配置参数

```dart
class PlayerConfig {
  final bool autoPlay;              // 自动播放 (默认 false)
  final bool looping;               // 循环播放 (默认 false)
  final bool preferHardwareDecoding; // 优先硬件解码 (默认 true)
  final Duration eventUpdateInterval; // 事件更新间隔 (默认 500ms)
  final int bufferSize;             // 缓冲区大小 (默认 10 帧)
  final bool enableLogging;         // 启用日志 (默认 false)
}
```

**使用示例**:
```dart
var controller = MangoPlayerController(
  config: PlayerConfig(
    autoPlay: true,
    preferHardwareDecoding: true,
    eventUpdateInterval: Duration(milliseconds: 100),
  ),
);
```

---

## 扩展模块接口

### 7. DataSourceProvider

**职责**: 数据源采集器接口

```dart
abstract class DataSourceProvider {
  /// 打开数据源
  Future<void> open(Uri uri, {Map<String, String>? headers});
  
  /// 读取数据
  Future<Uint8List> read(int size);
  
  /// 跳转位置
  Future<void> seek(int position);
  
  /// 获取总大小 (如果可用)
  Future<int?> getSize();
  
  /// 关闭数据源
  Future<void> close();
  
  /// 是否支持 seek
  bool get isSeekable;
}
```

**实现示例**:
```dart
class HttpDataSource implements DataSourceProvider {
  @override
  Future<void> open(Uri uri, {Map<String, String>? headers}) async {
    // HTTP 连接实现
  }
  // ... 其他方法实现
}
```

---

### 8. DecoderProvider

**职责**: 解码器接口

```dart
abstract class DecoderProvider {
  /// 配置解码器
  Future<void> configure(VideoConfig config);
  
  /// 解码一帧
  Future<VideoFrame?> decode(Uint8List data);
  
  /// 刷新解码器 (seek 时调用)
  Future<void> flush();
  
  /// 释放解码器
  Future<void> release();
  
  /// 是否支持硬件解码
  bool get supportsHardwareDecoding;
  
  /// 当前使用的编解码器类型
  String get codecType;
}

class VideoConfig {
  final int width;
  final int height;
  final String codec;       // 'h264', 'h265', 'vp8', 'vp9'
  final int? bitrate;
}

class VideoFrame {
  final Uint8List data;     // 像素数据 (软解) 或 null (硬解直接输出纹理)
  final int width;
  final int height;
  final int format;         // 像素格式 (YUV420, RGB, etc.)
  final Duration timestamp; // 时间戳
}
```

---

### 9. RendererProvider

**职责**: 渲染器接口

```dart
abstract class RendererProvider {
  /// 初始化渲染器
  Future<void> initialize(int width, int height);
  
  /// 获取纹理 ID
  int get textureId;
  
  /// 渲染一帧
  Future<void> render(VideoFrame frame);
  
  /// 更新尺寸
  Future<void> resize(int width, int height);
  
  /// 释放渲染器
  Future<void> release();
}
```

---

### 10. ProviderRegistry

**职责**: 模块注册表

```dart
class ProviderRegistry {
  // 单例模式
  static final ProviderRegistry instance = ProviderRegistry._();
  
  /// 注册数据源 Provider
  void registerDataSource(String scheme, DataSourceProvider Function() factory);
  
  /// 注册解码器 Provider
  void registerDecoder(String codec, DecoderProvider Function() factory);
  
  /// 注册渲染器 Provider
  void registerRenderer(String type, RendererProvider Function() factory);
  
  /// 获取 DataSource Provider
  DataSourceProvider getDataSource(String scheme);
  
  /// 获取 Decoder Provider
  DecoderProvider getDecoder(String codec);
  
  /// 获取 Renderer Provider
  RendererProvider getRenderer(String type);
}
```

**使用示例**:
```dart
// 注册自定义解码器
ProviderRegistry.instance.registerDecoder('h265', () => CustomH265Decoder());

// 注册自定义数据源 (如加密媒体)
ProviderRegistry.instance.registerDataSource('encrypted', () => EncryptedDataSource());
```

---

## 实体关系图

```
MangoPlayerController (1) ─── (1) MediaSource
         │
         │ (1)
         ↓
    PlayerState (enum)
         │
         │ (1:N)
         ↓
  PlaybackEvent
         │
         │ (0:N)
         ↓
   PlayerError
         
MangoPlayerController (1) ─── (1) ProviderRegistry
                                      │
                                      │ (1:N)
                                      ↓
                              DataSourceProvider
                              DecoderProvider
                              RendererProvider
```

---

## 状态管理

### PlayerState 状态机

**初始状态**: `idle`

**转换规则**:
```
idle + initialize() → initializing
initializing + success → ready
initializing + error → error

ready + play() → playing
ready + error → error

playing + pause() → paused
playing + seek() → buffering
playing + end of media → completed
playing + error → error

paused + play() → playing
paused + seek() → buffering

buffering + buffer filled → playing
buffering + error → error

completed + seek() → playing
completed + stop() → idle

error + stop() → idle
任何状态 + dispose() → idle
```

---

## 验证规则

### MangoPlayerController
- `volume` 必须在 [0.0, 1.0] 范围内
- `playbackSpeed` 必须在 [0.5, 2.0] 范围内
- `initialize()` 必须在 `idle` 或 `error` 状态调用
- `play()/pause()/seek()` 必须在 `ready/playing/paused/buffering` 状态调用
- `dispose()` 后 Controller 不可再使用

### MediaSource
- `uri` 不能为空
- `network` 类型必须使用 `http://`, `https://`, `rtmp://`, `rtsp://` 协议
- `file` 类型必须使用 `file://` 协议或绝对路径
- `asset` 类型必须使用 `asset://` 协议

### ProviderRegistry
- 同一 scheme/codec/type 只能注册一个 Provider (后注册覆盖前注册)
- 未注册的 scheme/codec/type 调用 `get*()` 方法抛出异常

---

## 总结

**核心实体**: 10 个
- Controller: MangoPlayerController, ProviderRegistry
- Data: MediaSource, PlaybackEvent, PlayerError, PlayerConfig
- Enum: PlayerState, MediaSourceType, PlayerErrorCode
- Provider Interfaces: DataSourceProvider, DecoderProvider, RendererProvider

**状态转换**: PlayerState 状态机定义清晰

**验证规则**: 所有字段范围和调用约束已明确

**进入阶段 1.2: 生成 API 合同 (contracts/)**
