# 研究报告: MangoPlayer 技术选型与最佳实践

**功能**: MangoPlayer 跨平台音视频播放器插件
**日期**: 2025-12-22
**阶段**: Phase 0 - Research

本文档记录技术选型决策、最佳实践研究和替代方案评估。

---

## 1. ijkplayer 桌面端移植方案

### 决策: 基于 ijkplayer C/C++ 核心进行 Windows/macOS 移植

**研究背景**:
ijkplayer 官方仅支持 iOS/Android，需要评估桌面端移植可行性。

**技术路径**:

#### Windows 平台
- **编译工具链**: MSVC 2019+ / MinGW-w64
- **依赖库**: 
  - ffmpeg (Windows 构建，支持 DXVA2 硬件解码)
  - SDL2 (可选，用于音频输出)
  - D3D11 (纹理渲染)
- **移植要点**:
  - ijkplayer 核心为 C/C++，跨平台兼容性好
  - 需要适配 Windows 平台的音频输出 (WASAPI/DirectSound)
  - 硬件解码使用 DXVA2 API
  - External Texture 通过 D3D11 Texture2D 实现

**参考项目**:
- `mpv`: 跨平台播放器，已有 Windows 成熟实现
- `VLC`: 使用类似 ffmpeg 架构，Windows 支持完善
- `dart-vlc`: Flutter VLC 插件，已验证 Windows FFI 可行性

#### macOS 平台
- **编译工具链**: Xcode Clang
- **依赖库**:
  - ffmpeg (macOS 构建，支持 VideoToolbox 硬件解码)
  - AudioUnit (音频输出)
  - Metal (纹理渲染)
- **移植要点**:
  - 与 iOS 共享大部分代码
  - 使用 VideoToolbox 硬件解码 (与 iOS 相同 API)
  - External Texture 通过 CVPixelBuffer → Metal Texture

**Rationale**:
- ijkplayer 核心为 C/C++，无平台锁定
- Windows/macOS 均有成熟的 ffmpeg 移植经验
- 社区已有初步桌面端尝试，技术可行性已验证

**Alternatives considered**:
- **libmpv**: 功能强大，但 API 复杂，集成成本高，且破坏跨平台一致性 (移动端仍需 ijkplayer)
- **自研播放器**: 从零实现工作量巨大 (>3月)，不切实际

---

## 2. Flutter External Texture 实现方案

### 决策: 使用 Flutter Texture Widget + 平台原生纹理传递

**研究背景**:
零拷贝渲染是性能关键，需要评估 External Texture 在 4 平台的实现路径。

**技术路径**:

#### Android (OpenGL ES / Vulkan)
```kotlin
// 创建 SurfaceTexture
val surfaceTexture = SurfaceTexture(textureId)
// 注册到 Flutter Texture Registry
val textureEntry = textureRegistry.createSurfaceTexture()
val textureId = textureEntry.id()
// 解码器输出到 Surface
val surface = Surface(surfaceTexture)
mediaCodec.configure(..., surface, ...)
```
- **纹理类型**: SurfaceTexture (OpenGL ES)
- **硬件解码**: MediaCodec 直接输出到 SurfaceTexture
- **零拷贝**: GPU 直接读取解码输出，无 CPU 拷贝

#### iOS (Metal)
```swift
// 创建 CVPixelBuffer
var pixelBuffer: CVPixelBuffer?
// 注册到 Flutter Texture Registry
let texture = textureRegistry.register(self)
// 解码器输出 CVPixelBuffer
VTDecompressionSessionCreate(...) // VideoToolbox 解码
// CVPixelBuffer → Metal Texture
let metalTexture = CVMetalTextureGetTexture(cvMetalTexture)
```
- **纹理类型**: CVPixelBuffer → Metal Texture
- **硬件解码**: VideoToolbox 直接输出 CVPixelBuffer
- **零拷贝**: Metal 直接使用 CVPixelBuffer，无拷贝

#### Windows (D3D11)
```cpp
// 创建 D3D11 Texture2D
ID3D11Texture2D* texture;
device->CreateTexture2D(&desc, nullptr, &texture);
// 注册到 Flutter Texture Registry
auto texture_registrar = GetTextureRegistrar();
auto texture_id = texture_registrar->RegisterTexture(...);
// 解码器输出到 D3D11 Texture (通过 DXVA2)
DXVA2_VideoProcessBlt(..., texture, ...);
```
- **纹理类型**: ID3D11Texture2D
- **硬件解码**: DXVA2 输出到 D3D11 纹理
- **零拷贝**: GPU 直接读取，无 CPU 拷贝

#### macOS (Metal)
```swift
// 与 iOS 类似
let metalTexture = CVMetalTextureCache...
```
- **纹理类型**: CVPixelBuffer → Metal Texture
- **硬件解码**: VideoToolbox
- **零拷贝**: 同 iOS

**Rationale**:
- 所有平台均支持 GPU 纹理直接传递
- Flutter Texture API 已为 4 平台提供统一抽象
- 零拷贝实现可节省 >50% 内存带宽 (符合 FR-045)

**Alternatives considered**:
- **Pixel Buffer 方案**: CPU 拷贝像素数据到 Dart 侧，性能差，内存占用高
- **Native View 嵌入**: 破坏 Flutter UI 一致性，不推荐

---

## 3. 跨平台一致性保证策略

### 决策: Platform Channel + 统一抽象层

**研究背景**:
4 平台 API 必须 100% 一致 (章程 I)，需要设计统一抽象机制。

**技术架构**:

```
Dart 层 (公共 API)
    ↓ Platform Channel
Platform Interface (抽象接口)
    ↓
各平台实现 (Android/iOS/Windows/macOS)
```

**统一抽象层设计**:

#### Dart 层接口
```dart
abstract class MangoPlayerPlatform {
  Future<void> initialize(MediaSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Stream<PlaybackEvent> get eventStream;
  // ... 其他接口
}
```

#### 平台实现契约
- **方法签名**: 所有平台实现必须完全一致
- **返回值语义**: 相同输入必须产生相同输出
- **错误处理**: 统一错误码 (见 `player_error.dart`)
- **异步行为**: 使用 Future/Stream 统一异步模型

**平台差异处理**:
- **能力查询**: `PlatformCapabilities.hasHardwareDecoder()`
- **优雅降级**: 硬件解码不可用时自动回退到软解
- **明确提示**: 不支持的功能返回 `UnsupportedPlatformError`

**Rationale**:
- Platform Channel 是 Flutter 官方推荐的跨平台通信方案
- 抽象层隔离平台实现细节，确保 API 一致性
- 错误码统一避免平台特定异常泄漏

**Alternatives considered**:
- **FFI 直接调用**: 跨平台一致性难以保证，Android/iOS 系统 API 差异大
- **多个独立插件**: 维护成本高，无法保证一致性

---

## 4. 模块化扩展机制设计

### 决策: Provider 接口 + 运行时注册

**研究背景**:
需要支持自定义 DataSource/Decoder/Renderer (FR-031~040)。

**设计模式**: 策略模式 + 工厂模式

#### Provider 接口定义
```dart
// 数据源接口
abstract class DataSourceProvider {
  Future<void> open(Uri uri);
  Future<Uint8List> read(int size);
  Future<void> seek(int position);
  Future<void> close();
}

// 解码器接口
abstract class DecoderProvider {
  Future<void> configure(VideoConfig config);
  Future<VideoFrame> decode(Uint8List data);
  bool get supportsHardwareDecoding;
}

// 渲染器接口
abstract class RendererProvider {
  int get textureId;
  Future<void> render(VideoFrame frame);
  Future<void> release();
}
```

#### 运行时注册机制
```dart
class ProviderRegistry {
  void registerDataSource(String type, DataSourceProvider Function() factory);
  void registerDecoder(String codec, DecoderProvider Function() factory);
  void registerRenderer(String type, RendererProvider Function() factory);
  
  DataSourceProvider getDataSource(String type);
  DecoderProvider getDecoder(String codec);
  RendererProvider getRenderer(String type);
}

// 使用示例
registry.registerDecoder('h265', () => CustomH265Decoder());
```

**Rationale**:
- Provider 接口定义清晰，易于实现
- 运行时注册支持动态扩展
- 工厂模式延迟实例化，节省资源

**Alternatives considered**:
- **编译时插件**: 灵活性差，需要重新编译
- **继承方式**: 耦合度高，不符合模块化原则

---

## 5. 硬件解码最佳实践

### 决策: 优先使用平台原生硬件解码器

**研究背景**:
硬件解码是性能关键 (章程 II)，需要研究各平台最佳实践。

**平台特定方案**:

#### Android: MediaCodec
```kotlin
val decoder = MediaCodec.createDecoderByType("video/avc")
val format = MediaFormat.createVideoFormat("video/avc", width, height)
decoder.configure(format, surface, null, 0)
decoder.start()
```
- **优点**: 系统原生，性能最佳
- **支持编码**: H.264, H.265 (API 21+), VP8, VP9
- **注意**: 不同设备硬件解码器能力差异大

#### iOS/macOS: VideoToolbox
```swift
var session: VTDecompressionSession?
VTDecompressionSessionCreate(
    allocator: kCFAllocatorDefault,
    formatDescription: formatDesc,
    decoderSpecification: nil,  // 让系统选择最佳解码器
    imageBufferAttributes: attrs,
    outputCallback: &callback,
    decompressionSessionOut: &session
)
```
- **优点**: 统一 API，iOS/macOS 共享代码
- **支持编码**: H.264, H.265, JPEG
- **注意**: 需要处理 HDR/SDR 色彩空间转换

#### Windows: DXVA2 / D3D11 Video
```cpp
// 创建 DXVA2 解码器
IDirectXVideoDecoderService* service;
hr = DXVA2CreateVideoService(d3dDevice, IID_IDirectXVideoDecoderService, (void**)&service);

IDirectXVideoDecoder* decoder;
hr = service->CreateVideoDecoder(guidDecoder, &desc, &config, surfaces, surfaceCount, &decoder);
```
- **优点**: Windows 原生，性能好
- **支持编码**: H.264, H.265 (Windows 10+), VC-1
- **注意**: 需要 D3D11 设备上下文

**回退策略**:
```
1. 尝试硬件解码器
2. 硬件不支持 → 回退到 ffmpeg 软解
3. 记录警告日志
```

**Rationale**:
- 硬件解码功耗低、性能高 (30fps@1080p 目标需要硬解支持)
- 平台原生解码器与系统集成最好
- 软解作为回退保证兼容性

**Alternatives considered**:
- **纯 ffmpeg 软解**: 性能差，功耗高，无法满足性能要求
- **第三方硬解库**: 兼容性和稳定性不如系统原生

---

## 6. 性能优化最佳实践

### 研究主题: 达成 30fps@1080p, <150MB 内存目标

**优化路径**:

#### 1. 零拷贝渲染 (已覆盖)
- External Texture 避免 CPU 拷贝
- 预期收益: 内存带宽节省 >50%

#### 2. 异步解码
```dart
// 解码线程与渲染线程分离
isolate.spawn(_decodeWorker, receivePort.sendPort);
```
- 避免阻塞 UI 线程
- 预期收益: 帧率稳定性提升

#### 3. 缓冲区管理
```dart
class BufferPool {
  final int maxSize = 10; // 最多缓存 10 帧
  final Queue<VideoFrame> _pool = Queue();
  
  VideoFrame acquire() => _pool.isNotEmpty ? _pool.removeFirst() : VideoFrame();
  void release(VideoFrame frame) {
    if (_pool.length < maxSize) _pool.add(frame);
  }
}
```
- 复用 VideoFrame 对象，减少 GC
- 预期收益: 内存占用降低 20-30%

#### 4. 按需加载
- 视频不播放时释放解码器资源
- 后台时暂停解码
- 预期收益: 内存占用降低 30-40%

**性能监控**:
```dart
class PerformanceMonitor {
  int frameCount = 0;
  int droppedFrames = 0;
  double avgDecodeTime = 0;
  
  void recordFrame(Duration decodeTime) {
    frameCount++;
    avgDecodeTime = (avgDecodeTime * (frameCount - 1) + decodeTime.inMilliseconds) / frameCount;
  }
}
```

**Rationale**:
- 性能优化需要系统性方法
- 监控指标支持性能调优
- 分阶段优化，逐步达成目标

---

## 7. 流媒体协议支持策略

### 决策: ffmpeg 原生协议支持 + 自定义扩展

**支持协议**:

#### HLS (HTTP Live Streaming)
- **实现**: ffmpeg libavformat (内置支持)
- **特性**: 自适应码率、多音轨、字幕
- **代码**: 无需额外实现，ffmpeg 处理 .m3u8

#### RTMP (Real-Time Messaging Protocol)
- **实现**: ffmpeg librtmp
- **特性**: 低延迟直播 (~3秒)
- **代码**: URL scheme `rtmp://`

#### RTSP (Real-Time Streaming Protocol)
- **实现**: ffmpeg libavformat
- **特性**: 网络摄像头、监控流
- **代码**: URL scheme `rtsp://`

**扩展点**:
```dart
class CustomStreamProtocol extends DataSourceProvider {
  @override
  Future<void> open(Uri uri) async {
    // 自定义协议实现 (如加密流)
  }
}
```

**Rationale**:
- ffmpeg 已支持主流协议，无需重新实现
- DataSourceProvider 接口支持自定义协议扩展

---

## 总结

### 所有研究已完成，技术路径明确

**关键决策**:
1. ijkplayer (C/C++) 移植到 Windows/macOS - 可行
2. External Texture 零拷贝渲染 - 4 平台路径明确
3. Platform Channel 统一抽象层 - 保证一致性
4. Provider 接口模块化扩展 - 设计完成
5. 硬件解码优先 + 软解回退 - 策略明确
6. 性能优化路径 - 系统性方案
7. 流媒体协议 - ffmpeg 原生支持

**无遗留 NEEDS CLARIFICATION 项。**

**进入阶段 1: 设计数据模型和接口合同。**
