# 实施计划: MangoPlayer 跨平台音视频播放器插件

**分支**: `001-cross-platform-player` | **日期**: 2025-12-22 | **规范**: [spec.md](spec.md)
**输入**: 来自 `/specs/001-cross-platform-player/spec.md` 的功能规范

**注意**: 此文档由 `/speckit.plan` 命令填充。

## 摘要

MangoPlayer 是一个跨平台 Flutter 音视频播放器插件，支持 Windows/macOS/iOS/Android 四大主要平台，预留 Web 和 HarmonyOS 扩展接口。

**核心技术方案**:
- **播放内核**: ijkplayer (基于 ffmpeg)，提供跨平台一致的解码能力
- **渲染方案**: Flutter External Texture (零拷贝)，实现 Native 级性能
- **架构模式**: 模块化设计 (DataSource/Decoder/Renderer 可扩展)
- **性能目标**: 启动<500ms, 30fps@1080p, 内存<150MB

**主要需求**:
- 基础播放控制 (play/pause/seek/volume)
- 多格式支持 (MP4/MKV/AVI + HLS/RTMP)
- 跨平台一致性 (4 平台 API 100% 一致)
- 模块化扩展能力 (自定义 Decoder/Renderer)
- 零拷贝高性能渲染

## 技术背景

**语言/版本**: 
- Dart 3.0+ (Flutter 层 API)
- Kotlin 1.8+ (Android 平台实现)
- Swift 5.9+ (iOS/macOS 平台实现)
- C++ 17 (Windows 平台实现, ijkplayer 核心)

**主要依赖**: 
- ijkplayer (播放内核, C/C++ 核心)
- ffmpeg 4.x+ (音视频解码)
- Flutter External Texture API (零拷贝渲染)
- Platform Channel (Dart ↔ Native 通信)

**存储**: N/A (无持久化存储需求，仅内存缓冲)

**测试**: 
- Dart: flutter test (单元/Widget 测试)
- Android: JUnit + Espresso (平台集成测试)
- iOS: XCTest (平台集成测试)
- 性能测试: 自定义性能 profiling 工具

**目标平台**: 
- **主要**: Windows 10+, macOS 10.14+, iOS 14+, Android API 24+
- **预留**: HarmonyOS, Web (接口占位)

**项目类型**: Flutter 插件项目 (跨平台 Native 集成)

**性能目标**: 
- 启动时间: <500ms (本地文件), <1000ms (网络视频)
- 渲染帧率: ≥30fps (1080p, 标准硬件)
- 内存占用: <150MB (1080p 单实例)
- Seek 延迟: <200ms (本地), <500ms (网络)

**约束条件**: 
- 跨平台 API 必须 100% 一致 (符合章程 I)
- 零拷贝渲染必须实现 (内存带宽节省 >50%)
- 硬件解码优先 (性能关键路径)
- 模块接口必须支持运行时替换

**规模/范围**: 
- 公共 API: ~30-40 个方法
- 平台实现: 4 个平台 × 3 核心模块 (DataSource/Decoder/Renderer)
- 预计代码量: ~15k-20k 行 (含平台代码)

## 章程检查

*门控: 必须在阶段 0 研究前通过。阶段 1 设计后重新检查。*

基于 `.specify/memory/constitution.md` 中定义的核心原则，验证以下门控条件：

**跨平台一致性 (原则 I)**:
- [x] API 在 Windows/macOS/iOS/Android 上行为一致 (通过统一抽象层实现)
- [x] 平台特定实现已隐藏在统一接口后 (Platform Channel + 抽象接口)
- [x] 平台差异已明确文档化 (Web/HarmonyOS 返回 "不支持" 状态)

**Native 性能优先 (原则 II)**:
- [x] 启动时间 <500ms (ijkplayer 优化 + External Texture)
- [x] 渲染帧率 ≥30fps (1080p) (硬件解码 + 零拷贝渲染)
- [x] 内存占用 <150MB (1080p) (External Texture 内存带宽节省 >50%)
- [x] 性能关键路径已识别待优化 (解码、渲染、纹理传递)

**模块化架构 (原则 III)**:
- [x] 功能模块职责单一 (DataSource/Decoder/Renderer 分离)
- [x] 模块接口已明确定义 (Provider 接口 + 注册机制)
- [x] 模块可独立测试 (单元测试 + 集成测试)

**测试优先开发 (原则 IV)**:
- [x] 测试计划已制定 (单元/集成/平台/性能测试，见阶段 1)
- [x] 目标覆盖率 >80% (Dart 层 API + 核心逻辑)

**文档完整性 (原则 V)**:
- [x] API 文档计划已制定 (dartdoc + 示例代码)
- [x] 示例代码计划已制定 (example/ 应用 + quickstart.md)

**API 稳定性 (原则 VI)**:
- [x] 向后兼容性已评估 (新项目，无兼容性包袱)
- [x] 破坏性变更已明确标记 (实验性 API 使用 @experimental 注解)

**✅ 所有门控通过，可进入阶段 0 研究。**

## 项目结构

### 文档(此功能)

```
specs/[###-feature]/
├── plan.md              # 此文件 (/speckit.plan 命令输出)
├── research.md          # 阶段 0 输出 (/speckit.plan 命令)
├── data-model.md        # 阶段 1 输出 (/speckit.plan 命令)
├── quickstart.md        # 阶段 1 输出 (/speckit.plan 命令)
├── contracts/           # 阶段 1 输出 (/speckit.plan 命令)
└── tasks.md             # 阶段 2 输出 (/speckit.tasks 命令 - 非 /speckit.plan 创建)
```

### 源代码(仓库根目录)

```
# Flutter 插件项目结构 - 展示抽象层与实现层分离

lib/
├── src/
│   ├── core/                                      # 核心 API 层
│   │   ├── mango_player_controller.dart           # 播放器控制器 (对外 API)
│   │   ├── player_state.dart                      # 播放状态枚举
│   │   ├── media_source.dart                      # 媒体源抽象
│   │   ├── playback_event.dart                    # 播放事件
│   │   ├── player_error.dart                      # 错误信息
│   │   └── player_config.dart                     # 播放器配置
│   │
│   ├── providers/                                 # 🔑 抽象接口层 (跨平台契约)
│   │   ├── data_source_provider.dart              # 数据源接口 (抽象类)
│   │   ├── decoder_provider.dart                  # 解码器接口 (抽象类)
│   │   ├── renderer_provider.dart                 # 渲染器接口 (抽象类)
│   │   └── provider_registry.dart                 # 模块注册表
│   │
│   ├── platform/                                  # Platform Channel 抽象层
│   │   └── mango_player_platform_interface.dart   # Platform Method 定义
│   │
│   └── ui/                                        # UI 组件层
│       ├── mango_player_view.dart                 # 视频渲染 Widget
│       └── controls/                              # 默认播放控制 UI
│           ├── default_controls.dart
│           └── fullscreen_player.dart
│
├── mango_player.dart                              # 公共 API 入口 (导出所有公共类)

# ================================================================================
# Android 平台实现 - 实现 providers/ 中定义的抽象接口
# ================================================================================
android/
├── src/main/
│   ├── kotlin/com/mangoplayer/
│   │   ├── MangoPlayerPlugin.kt                   # Flutter 插件入口 (Platform Channel 绑定)
│   │   │
│   │   ├── platform/                              # 🔌 Platform Channel 实现层
│   │   │   ├── MethodChannelHandler.kt            # 处理 Dart → Native 调用
│   │   │   ├── EventChannelHandler.kt             # 推送 Native → Dart 事件
│   │   │   └── TextureRegistryHandler.kt          # Texture 注册管理
│   │   │
│   │   ├── ijkplayer/                             # 🎬 ijkplayer 封装层 (移动端使用 ijkplayer 内核)
│   │   │   ├── IJKPlayerWrapper.kt                # 封装 ijkplayer Java 接口
│   │   │   ├── IJKPlayerManager.kt                # 播放器生命周期管理
│   │   │   ├── IJKPlayerEventListener.kt          # ijkplayer 事件转换
│   │   │   └── IJKSurfaceBridge.kt                # 🔗 ijkplayer → Flutter SurfaceTexture 桥接
│   │   │                                          #    (绕过 ijksdl, 使用 setSurface 对接 Flutter Texture)
│   │   │
│   │   ├── providers/                             # 🔧 Provider 接口实现层
│   │   │   ├── AndroidDataSourceProvider.kt       # 实现 DataSourceProvider (HTTP/File/Asset)
│   │   │   ├── AndroidDecoderProvider.kt          # 实现 DecoderProvider (配置/监控 MediaCodec 硬解)
│   │   │   ├── AndroidRendererProvider.kt         # 实现 RendererProvider (SurfaceTexture)
│   │   │   └── ProviderRegistryImpl.kt            # Provider 注册表实现
│   │   │
│   │   ├── decoder/                               # 解码配置/监控 (基于 ijkplayer, 非自研解码器)
│   │   │   ├── MediaCodecConfigManager.kt         # 配置硬解选项/监听降级
│   │   │   └── DecodeEventBridge.kt               # 将硬解/软解事件桥接到 Dart
│   │   │
│   │   └── renderer/                              # 渲染器具体实现
│   │       ├── SurfaceTextureRenderer.kt          # External Texture 渲染
│   │       └── OpenGLTextureManager.kt            # OpenGL ES 纹理管理
│   │
│   └── res/
│
└── libs/
  ├── ijkplayer-java-0.8.8.aar                   # ijkplayer Java 包装层
  └── ijkplayer-arm64-v8a.so                     # ijkplayer Native 库

# ================================================================================
# iOS 平台实现 - 实现 providers/ 中定义的抽象接口
# ================================================================================
ios/
├── Classes/
│   ├── MangoPlayerPlugin.swift                    # Flutter 插件入口
│   │
│   ├── Platform/                                  # 🔌 Platform Channel 实现层
│   │   ├── MethodChannelHandler.swift
│   │   ├── EventChannelHandler.swift
│   │   └── TextureRegistryHandler.swift
│   │
│   ├── IJKPlayer/                                 # 🎬 ijkplayer 封装层 (移动端使用 ijkplayer 内核)
│   │   ├── IJKPlayerWrapper.swift                 # 封装 ijkplayer Objective-C 接口
│   │   ├── IJKPlayerManager.swift                 # 播放器生命周期管理
│   │   ├── IJKPlayerEventBridge.swift             # 事件桥接
│   │   └── IJKPixelBufferOutput.swift             # 🔗 ijkplayer → CVPixelBuffer 输出
│   │                                              #    (绕过 ijksdl GLView, 获取解码帧送入 Flutter Texture)
│   │
│   ├── Providers/                                 # 🔧 Provider 接口实现层
│   │   ├── IOSDataSourceProvider.swift            # 实现 DataSourceProvider
│   │   ├── IOSDecoderProvider.swift               # 实现 DecoderProvider (配置/监控 VideoToolbox)
│   │   ├── IOSRendererProvider.swift              # 实现 RendererProvider
│   │   └── ProviderRegistryImpl.swift
│   │
│   ├── Decoder/                                   # 解码配置/监控 (基于 ijkplayer, 非自研解码器)
│   │   ├── VideoToolboxConfigManager.swift        # 硬解选项配置/降级监控
│   │   └── DecodeEventBridge.swift                # 硬解/软解事件桥接到 Dart
│   │
│   └── Renderer/                                  # 渲染器具体实现
│       ├── MetalTextureRenderer.swift             # Metal 纹理渲染
│       └── CVPixelBufferManager.swift             # CVPixelBuffer 管理
│
├── Frameworks/
│   └── IJKMediaFramework.framework                # ijkplayer 预编译框架
│
└── Assets/

# ================================================================================
# macOS 平台实现 - FFmpeg + VideoToolbox 管线 (无 ijkplayer)
# ================================================================================
macos/
├── Classes/
│   ├── MangoPlayerPlugin.swift                    # Flutter 插件入口
│   │
│   ├── Platform/                                  # 🔌 Platform Channel 实现层
│   │   ├── MethodChannelHandler.swift
│   │   ├── EventChannelHandler.swift
│   │   └── TextureRegistryHandler.swift
│   │
│   ├── core/                                      # 🧠 播放内核封装 (FFmpeg + VideoToolbox)
│   │   ├── native_core/                           # 共用 C++ 核心 (mac/win 复用)
│   │   │   ├── ffmpeg_demuxer.cpp                 # demux/解复用 (C++)
│   │   │   ├── ffmpeg_soft_decoder.cpp            # 软解回退 (C++)
│   │   │   ├── clock_sync.cpp                     # AV 同步 (C++)
│   │   │   └── core_event_bridge.cpp              # 内核事件桥接 (C++)
│   │   ├── FFmpegDemuxer.swift                    # Swift/C++ 混编桥 (调用 native_core)
│   │   ├── VideoToolboxDecoder.swift              # 硬解实现
│   │   ├── FFmpegSoftDecoder.swift                # 软解回退包装 (Swift 调用 C++)
│   │   ├── ClockSync.swift                        # AV 同步包装 (Swift 调用 C++)
│   │   └── CoreEventBridge.swift                  # 内核事件桥接包装
│   │
│   ├── Providers/                                 # 🔧 Provider 接口实现层
│   │   ├── MacOSDataSourceProvider.swift          # 实现 DataSourceProvider
│   │   ├── MacOSDecoderProvider.swift             # 实现 DecoderProvider (配置/监控 VT/软解)
│   │   ├── MacOSRendererProvider.swift            # 实现 RendererProvider (Metal)
│   │   └── ProviderRegistryImpl.swift
│   │
│   ├── Decoder/                                   # 解码实现/配置 (FFmpeg + VT)
│   │   ├── VideoToolboxConfigManager.swift        # 硬解配置与降级监控
│   │   └── SoftDecodeFallback.swift               # 软解回退处理
│   │
│   └── Renderer/                                  # 渲染器具体实现
│       ├── MetalTextureRenderer.swift             # Metal 纹理渲染
│       └── CVPixelBufferManager.swift             # CVPixelBuffer 管理
│
├── libs/
│   └── ffmpeg.dylib                               # ffmpeg 动态库
│
└── Assets/

# ================================================================================
# Windows 平台实现 - FFmpeg + DXVA2 管线 (无 ijkplayer)
# ================================================================================
windows/
├── include/
│   ├── mango_player_plugin.h
│   └── providers/                                 # Provider 接口 C++ 头文件
│       ├── data_source_provider.h
│       ├── decoder_provider.h
│       └── renderer_provider.h
│
├── src/
│   ├── mango_player_plugin.cpp                    # Flutter 插件入口
│   │
│   ├── platform/                                  # 🔌 Platform Channel 实现层
│   │   ├── method_channel_handler.cpp
│   │   ├── event_channel_handler.cpp
│   │   └── texture_registry_handler.cpp
│   │
│   ├── core/                                      # 🧠 播放内核封装 (FFmpeg + DXVA2)
│   │   ├── native_core/                           # 共用 C++ 核心 (与 mac 复用)
│   │   │   ├── ffmpeg_demuxer.cpp                 # demux/解复用 (C++)
│   │   │   ├── ffmpeg_soft_decoder.cpp            # 软解回退 (C++)
│   │   │   ├── clock_sync.cpp                     # AV 同步 (C++)
│   │   │   └── core_event_bridge.cpp              # 内核事件桥接 (C++)
│   │   ├── ffmpeg_demuxer_win.cpp                 # 平台适配封装 (调用 native_core)
│   │   ├── dxva_decoder.cpp                       # 硬件解码实现
│   │   ├── ffmpeg_soft_decoder_win.cpp            # 软解回退包装 (调用 native_core)
│   │   ├── clock_sync_win.cpp                     # AV 同步包装 (调用 native_core)
│   │   └── core_event_bridge_win.cpp              # 内核事件桥接包装
│   │
│   ├── providers/                                 # 🔧 Provider 接口实现层
│   │   ├── windows_data_source_provider.cpp       # 实现 DataSourceProvider
│   │   ├── windows_decoder_provider.cpp           # 实现 DecoderProvider (配置/监控 DXVA/软解)
│   │   ├── windows_renderer_provider.cpp          # 实现 RendererProvider
│   │   └── provider_registry_impl.cpp
│   │
│   ├── decoder/                                   # 解码实现/配置 (FFmpeg + DXVA2)
│   │   ├── dxva_config_manager.cpp                # 硬解配置与降级监控
│   │   └── soft_decode_fallback.cpp               # 软解回退处理
│   │
│   └── renderer/                                  # 渲染器具体实现
│       ├── d3d11_texture_renderer.cpp             # D3D11 纹理渲染
│       └── texture_manager.cpp                    # 纹理管理
│
└── libs/
  └── ffmpeg.lib                                 # ffmpeg 静态库

# ================================================================================
# 测试层
# ================================================================================
test/
├── unit/
│   ├── providers/                                 # Provider 接口单元测试
│   │   ├── data_source_provider_test.dart
│   │   ├── decoder_provider_test.dart
│   │   └── renderer_provider_test.dart
│   ├── mango_player_controller_test.dart
│   └── media_source_test.dart
│
└── widget/
    └── mango_player_view_test.dart

example/
├── lib/
│   ├── main.dart
│   └── pages/
│       ├── basic_player_page.dart                 # 演示基础播放
│       ├── custom_provider_page.dart              # 演示自定义 Provider
│       └── platform_consistency_page.dart         # 演示跨平台一致性
│
└── test/
    ├── integration/
    │   ├── playback_flow_test.dart                # 端到端播放流程测试
    │   └── cross_platform_test.dart               # 跨平台 API 一致性测试
    │
    └── performance/
        ├── startup_time_test.dart                 # 启动性能测试
        ├── memory_test.dart                       # 内存占用测试
        └── frame_rate_test.dart                   # 帧率测试
```

---

## 架构分层说明

### 第 1 层: Dart 抽象接口层 (`lib/src/providers/`)
```dart
// 定义跨平台契约，所有平台必须实现
// 注意: DecoderProvider 不是"替换"ijkplayer 解码器，
//      而是"配置"ijkplayer 的解码选项 (软解/硬解切换)
abstract class DecoderProvider {
  Future<void> configure(VideoConfig config);  // 配置解码选项
  Future<void> enableHardwareDecode(bool enable); // 启用/禁用硬解
  bool get supportsHardwareDecoding;            // 查询硬解支持
  Stream<DecoderEvent> get events;              // 解码事件 (如降级通知)
}
```

### 第 2 层: Platform Channel 桥接层 (`platform/`)
- **Dart 侧**: `mango_player_platform_interface.dart`
- **Native 侧**: `MethodChannelHandler`, `EventChannelHandler`
- 负责 Dart ↔ Native 通信

### 第 3 层: 播放内核封装层 (`core/` 或 `ijkplayer/`)
- **职责**: 将播放内核适配为符合平台习惯的 API；对上暴露一致的 Provider 能力。
- **按平台实现**:
  - 移动端 (Android/iOS): 使用 ijkplayer (内含 FFmpeg 软解 + MediaCodec/VideoToolbox 硬解 + 自动降级)。封装层仅配置选项并桥接事件。
  - 桌面端 (Windows/macOS): 使用 FFmpeg + 平台硬解 (DXVA2/VideoToolbox) 自研管线，封装层提供同样的播放/seek/事件/纹理输出接口。
- **共享策略 (✅ 已更新 2026-01-15)**:
  - **核心原则**: 将 `native_core/` 提升到项目根目录（与 `macos/`, `windows/`, `ios/`, `android/` 同级）
  - **跨平台模块** (~70% 代码无平台差异):
    - `native_core/src/demuxer.cpp` - FFmpeg 解复用 (100% 跨平台)
    - `native_core/src/soft_decoder.cpp` - FFmpeg 软解码 (100% 跨平台)
    - `native_core/src/clock_sync.cpp` - AV 同步 (100% 跨平台)
    - `native_core/src/player_core.cpp` - 播放核心逻辑，通过接口调用平台实现
  - **平台抽象接口** (~25% 代码通过接口隔离):
    - `native_core/include/interfaces/hw_decoder.h` - 硬解接口 (VideoToolbox/DXVA2/MediaCodec)
    - `native_core/include/interfaces/texture_output.h` - 纹理输出接口 (Metal/D3D11/OpenGL)
    - `native_core/include/interfaces/audio_output.h` - 音频输出接口
  - **平台特定实现** (各平台独立实现接口):
    - macOS: `macos/Classes/platform/` (VideoToolboxDecoder, MetalTextureOutput)
    - Windows: `windows/src/platform/` (DXVADecoder, D3D11TextureOutput)
    - iOS/Android: 如不使用 ijkplayer，可复用 native_core + 平台硬解
  - **构建集成**:
    - macOS: 通过 CMake 编译 native_core 为静态库，Swift 通过 C 桥接层调用
    - Windows: CMake 直接链接 native_core 源码
    - iOS/Android: 可选集成 (如放弃 ijkplayer 则复用)
- **澄清**:
  - 移动端不需要自研解码器，解码发生在 ijkplayer 内核；`decoder/` 目录在移动端用于解码配置/监控与事件桥接。
  - 桌面端需要实现解码管线；`core/` 和 `decoder/` 会包含 FFmpeg 软解、硬解适配和同步逻辑。

### 第 4 层: 渲染对接层 (Flutter External Texture)

**核心策略**: 绕过 ijkplayer 内置的 ijksdl 渲染模块，将解码帧输出到 Flutter TextureRegistry。

**Android 渲染对接** (`IJKSurfaceBridge.kt` + `SurfaceTextureRenderer.kt`):
```kotlin
// 1. 从 Flutter TextureRegistry 创建 SurfaceTexture
val textureEntry = textureRegistry.createSurfaceTexture()
val surfaceTexture = textureEntry.surfaceTexture()
val surface = Surface(surfaceTexture)

// 2. 将 Surface 传给 ijkplayer (绕过 ijksdl 内部渲染)
ijkMediaPlayer.setSurface(surface)

// 3. ijkplayer 解码后直接渲染到此 Surface
//    Flutter 通过 Texture Widget 显示 textureEntry.id()
```
- **关键**: 使用 `IjkMediaPlayer.setSurface()` 而非 ijkplayer 的 `SurfaceView/TextureView`
- ijkplayer 的 `ijksdl` 仍处理音频输出，但视频帧直接写入 Flutter 提供的 Surface

**iOS 渲染对接** (`IJKPixelBufferOutput.swift` + `CVPixelBufferManager.swift`):
```swift
// 1. 设置 ijkplayer 输出 CVPixelBuffer (而非 GLKView 渲染)
//    需要配置 ijkplayer 选项或使用回调机制
ijkPlayer.setOptionIntValue(1, forKey: "videotoolbox-pixelbuffer-output", ofCategory: .player)

// 2. 注册帧回调，获取 CVPixelBuffer
ijkPlayer.setVideoFrameCallback { pixelBuffer in
    // 3. 将 CVPixelBuffer 送入 Flutter TextureRegistry
    self.textureRegistry.register(pixelBuffer)
}
```
- **关键**: 配置 ijkplayer 输出 `CVPixelBuffer` 而非渲染到 `IJKSDLGLView`
- 如 ijkplayer 原生不支持此回调，可能需要修改 ijkmedia 层或使用 `CVPixelBufferPool` 拦截

**对接要点**:
| 平台 | ijkplayer 输出方式 | Flutter 接收方式 | 绕过的 ijksdl 组件 |
|------|-------------------|-----------------|-------------------|
| Android | `setSurface(flutterSurface)` | SurfaceTexture → TextureRegistry | SurfaceView/TextureView |
| iOS | CVPixelBuffer 回调 | CVPixelBuffer → TextureRegistry | IJKSDLGLView/OpenGL ES |

- **示例** (Android):
  ```kotlin
  class IJKPlayerWrapper {
      private val ijkMediaPlayer = IjkMediaPlayer()
      // 通过 setOption 配置硬解、缓冲、旋转处理等
  }
  ```
- **示例** (Windows):
  ```cpp
  // core/dxva_decoder.cpp
  // 初始化 DXVA2，失败则发事件回落到 ffmpeg_soft_decoder
  ```

### 第 5 层: 解码配置与渲染实现层 (`decoder/`, `renderer/`)
- **职责**: 
  - `decoder/`: 移动端为解码配置/监控，桌面端包含实际解码实现
  - `renderer/`: 平台特定纹理管理 (OpenGL ES/Metal/D3D11)
- **示例**: 移动端 `MediaCodecConfigManager.kt`，桌面端 `dxva_decoder.cpp`

---

## 关键设计决策

**✅ 抽象与实现分离**:
- Dart 层定义 `DecoderProvider` 接口
- Android 实现 `AndroidDecoderProvider`
- iOS 实现 `IOSDecoderProvider`
- Windows 实现 `WindowsDecoderProvider`

**✅ 播放内核封装独立**:
- 移动端有独立的 `IJKPlayerWrapper`（基于 ijkplayer 内核）
- 桌面端有独立的 FFmpeg+硬解封装 (`core/`)，暴露同样的播放/事件接口
- 封装层均提供符合平台习惯的 API (Kotlin/Swift/C++ 风格)

**✅ 渲染方案: Flutter External Texture (绕过 ijksdl)**:
- **不使用** ijkplayer 内置的 `ijksdl` 渲染模块 (SurfaceView/IJKSDLGLView)
- **使用** Flutter TextureRegistry 实现零拷贝渲染
- Android: `IjkMediaPlayer.setSurface(flutterSurface)` 直接输出到 Flutter SurfaceTexture
- iOS: 配置 ijkplayer 输出 CVPixelBuffer，注入 Flutter TextureRegistry
- 优势: 与 Flutter Widget 树无缝集成，支持叠加、变换、动画

**✅ 模块化可替换**:
- 通过 `ProviderRegistry` 注册自定义实现
- 可以完全替换 ijkplayer 为其他播放器内核

---

**结构决策总结**: 
- 采用 **分层架构**: 抽象层 → 桥接层 → 封装层 → 渲染对接层 → 实现层
- 移动端封装 `ijkplayer/`；桌面端封装 `core/`(FFmpeg+硬解)，对上暴露同样的 Provider 能力
- **渲染统一**: 全平台使用 Flutter External Texture，移动端绕过 ijksdl，桌面端直接输出到 TextureRegistry
- 桌面端共用 `native_core/` C++（demux/软解/AV 同步/事件），mac 通过 Swift/C++ 混编桥接，win 直接链接；平台差异集中在硬解适配与纹理输出
- 各平台实现隔离在 `android/`, `ios/`, `windows/`, `macos/` 目录，跨平台一致性由 Dart 抽象接口保证

## 复杂度跟踪

*说明: 本节记录可能违反章程的复杂设计选择及其正当理由。*

**当前无需跟踪的复杂度违规。**

所有设计决策符合章程要求：
- 模块化架构符合原则 III
- External Texture 为性能必需，符合原则 II
- 4 平台实现为跨平台一致性所需，符合原则 I

---

## 阶段 0 研究总结

**研究文档**: [research.md](research.md)

**关键研究主题**:
1. ijkplayer 桌面端移植方案 - ✅ 可行 (C/C++ 核心可移植)
2. Flutter External Texture 实现 - ✅ 4 平台路径明确
3. 跨平台一致性保证策略 - ✅ Platform Channel + 统一抽象层
4. 模块化扩展机制设计 - ✅ Provider 接口 + 运行时注册
5. 硬件解码最佳实践 - ✅ 平台原生解码器 + 软解回退
6. 性能优化最佳实践 - ✅ 零拷贝 + 异步解码 + 缓冲管理
7. 流媒体协议支持 - ✅ ffmpeg 原生支持

**所有 NEEDS CLARIFICATION 项已解决。**

---

## 阶段 1 设计总结

**数据模型**: [data-model.md](data-model.md)

**核心实体**: 10 个
- Controller: MangoPlayerController, ProviderRegistry
- Data: MediaSource, PlaybackEvent, PlayerError, PlayerConfig
- Enum: PlayerState, MediaSourceType, PlayerErrorCode
- Provider Interfaces: DataSourceProvider, DecoderProvider, RendererProvider

**API 合同**: [contracts/platform-channel-api.md](contracts/platform-channel-api.md)

**API 定义**:
- Method Channel: 10 个方法
- Event Channel: 5 种事件类型
- Texture Channel: 2 个方法
- Provider Channel: 2 个方法

**快速开始**: [quickstart.md](quickstart.md)

**集成步骤**: 3 步即可完成基础播放 (目标 10 分钟内)

**代理上下文**: ✅ 已更新 GitHub Copilot 上下文

---

## 章程重新检查 (阶段 1 后)

**跨平台一致性 (原则 I)**:
- [x] API 在 Windows/macOS/iOS/Android 上行为一致 (通过 Platform Channel 统一抽象)
- [x] 平台特定实现已隐藏 (Native 层实现细节不暴露)
- [x] 平台差异已文档化 (contracts/ 定义了一致性要求)

**Native 性能优先 (原则 II)**:
- [x] 启动时间 <500ms (ijkplayer 优化)
- [x] 渲染帧率 ≥30fps (硬件解码 + External Texture)
- [x] 内存占用 <150MB (零拷贝渲染)
- [x] 性能关键路径已识别 (解码、渲染、纹理传递)

**模块化架构 (原则 III)**:
- [x] 功能模块职责单一 (DataSource/Decoder/Renderer 分离)
- [x] 模块接口已明确定义 (data-model.md 中的 Provider 接口)
- [x] 模块可独立测试 (接口设计支持 Mock)

**测试优先开发 (原则 IV)**:
- [x] 测试计划已制定 (单元/Widget/集成/平台/性能测试)
- [x] 目标覆盖率 >80% (Dart 层 API + 核心逻辑)

**文档完整性 (原则 V)**:
- [x] API 文档计划已制定 (dartdoc 注释 + pub.dev 文档)
- [x] 示例代码已提供 (quickstart.md + example/ 应用)

**API 稳定性 (原则 VI)**:
- [x] 向后兼容性已评估 (新项目，无历史包袱)
- [x] 破坏性变更已标记 (实验性 API 使用 @experimental)

**✅ 所有章程检查通过，设计符合要求。**

---

## 下一步：进入阶段 2 (任务分解)

**命令**: `/speckit.tasks`

**输出**: `tasks.md` (将计划分解为可执行的开发任务)

**任务组织**: 按用户故事分组，优先级排序

**预计任务数量**: 20-30 个任务 (涵盖 Dart API、4 平台实现、测试、文档)

---

## 附录

### 生成的制品

```
specs/001-cross-platform-player/
├── plan.md              # 本文件 (实施计划)
├── research.md          # 阶段 0 研究报告
├── data-model.md        # 阶段 1 数据模型
├── quickstart.md        # 阶段 1 快速开始指南
└── contracts/
    └── platform-channel-api.md  # 阶段 1 API 合同
```

### 技术栈总结

**Dart 层**: Flutter 3.0+, Dart 3.0+
**Android**: Kotlin 1.8+, ijkplayer, MediaCodec
**iOS/macOS**: Swift 5.9+, ijkplayer, VideoToolbox, Metal
**Windows**: C++ 17, ijkplayer, DXVA2, D3D11
**依赖**: ijkplayer, ffmpeg 4.x+, Flutter External Texture API

---

**✅ 计划阶段完成。分支 `001-cross-platform-player` 准备就绪。**
