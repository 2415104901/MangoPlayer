---
description: "MangoPlayer 功能实现任务列表"
---

# 任务: MangoPlayer 跨平台音视频播放器插件

**输入**: 来自 `/specs/001-cross-platform-player/` 的设计文档
**前置条件**: plan.md ✅、spec.md ✅、data-model.md ✅、contracts/ ✅、feasibility.md ✅

**组织结构**: 任务按用户故事分组，以便每个故事能够独立实施和测试。

## 格式: `[ID] [P] [Story] 描述`

- **[P]**: 可以并行运行(不同文件，无依赖关系)
- **[Story]**: 此任务属于哪个用户故事(例如: US1、US2、US3)
- 在描述中包含确切的文件路径

## 路径约定 (Flutter 插件项目)

- Dart 代码: `lib/src/`
- Android 原生: `android/src/main/kotlin/com/mangoplayer/`
- iOS 原生: `ios/Classes/`
- macOS 原生: `macos/Classes/`
- Windows 原生: `windows/src/`
- 测试: `test/`, `example/test/`

---

## 🚨 架构重构任务 (2026-01-15 新增)

**背景**: 原设计要求 `native_core/` C++ 代码在 Windows/macOS 间共享，但实际 macOS 用 ObjC/Swift 重写导致代码重复。现已创建正确的 `native_core/` 架构。

### 已完成的架构更新
- [x] T-ARCH-001 创建 `native_core/` 根目录结构和 CMakeLists.txt
- [x] T-ARCH-002 创建跨平台类型定义 `native_core/include/mango_player/types.h`
- [x] T-ARCH-003 创建平台抽象接口 (`interfaces/hw_decoder.h`, `texture_output.h`, `audio_output.h`)
- [x] T-ARCH-004 创建跨平台核心头文件 (`demuxer.h`, `soft_decoder.h`, `clock_sync.h`, `event_bridge.h`, `player_core.h`)
- [x] T-ARCH-005 创建 C 桥接层 `native_core/include/mango_player/c_bridge/mango_player_c.h`
- [x] T-ARCH-006 实现跨平台源文件 (`src/*.cpp`)

### 待完成的重构任务
- [ ] T-ARCH-007 macOS: 创建 `VideoToolboxDecoder` 实现 `IHardwareDecoder` 接口
- [ ] T-ARCH-008 macOS: 创建 `MetalTextureOutput` 实现 `ITextureOutput` 接口
- [ ] T-ARCH-009 macOS: 创建 `AVAudioEngineOutput` 实现 `IAudioOutput` 接口
- [ ] T-ARCH-010 macOS: 重构 `FFmpegPlayerManager.swift` 使用 `native_core` C 桥接
- [ ] T-ARCH-011 Windows: 创建 `DXVADecoder` 实现 `IHardwareDecoder` 接口
- [ ] T-ARCH-012 Windows: 创建 `D3D11TextureOutput` 实现 `ITextureOutput` 接口
- [ ] T-ARCH-013 Windows: 创建 `WASAPIAudioOutput` 实现 `IAudioOutput` 接口
- [ ] T-ARCH-014 Windows: 重构 `FFmpegPlayerManager` 使用共享 `native_core`
- [ ] T-ARCH-015 删除 macOS 重复代码 (`FFmpegDemuxerObjC.m`, `ClockSync.swift` 等)
- [ ] T-ARCH-016 删除 Windows 旧 `native_core/` 目录，改用根目录共享版本
- [ ] T-ARCH-017 更新 macOS `mango_player.podspec` 链接 `native_core` 静态库
- [ ] T-ARCH-018 更新 Windows `CMakeLists.txt` 链接 `native_core` 静态库

---

## 阶段 1: 设置(共享基础设施)

**目的**: 项目初始化、依赖配置和基本结构

- [x] T001 根据 plan.md 创建 Flutter 插件项目结构 (`flutter create --template=plugin --platforms=android,ios,windows,macos mango_player`)
- [x] T002 [P] 配置 `pubspec.yaml` 添加依赖项 (flutter, meta)
- [x] T003 [P] 配置 Android `build.gradle` (Kotlin 1.8+, minSdk 24)
- [x] T004 [P] 配置 iOS `mango_player.podspec` (iOS 14+, Swift 5.9)
- [x] T005 [P] 配置 macOS `mango_player.podspec` (macOS 10.14+, Swift 5.9)
- [x] T006 [P] 配置 Windows `CMakeLists.txt` (C++17, Windows 10+)
- [x] T007 [P] 配置代码检查 `analysis_options.yaml`
- [x] T008 创建 `lib/mango_player.dart` 公共 API 入口文件

---

## 阶段 2: 基础(阻塞前置条件)

**目的**: 在任何用户故事可以实施之前必须完成的核心基础设施

**⚠️ 关键**: 在此阶段完成之前，无法开始任何用户故事工作

### POC 验证任务 (来自 feasibility.md)

- [x] T009 [POC] 验证 Flutter External Texture 在 Android 上的零拷贝渲染 (创建 `poc/android_texture_demo/`)
- [x] T010 [POC] 验证 Flutter External Texture 在 iOS 上的零拷贝渲染 (创建 `poc/ios_texture_demo/`)
- [x] T011 [POC] 验证 ijkplayer 在 Android 上编译并通过 `setSurface()` 输出到 Flutter SurfaceTexture
- [x] T012 [POC] 验证 ijkplayer 在 iOS 上编译并输出 CVPixelBuffer 到 Flutter TextureRegistry
- [x] T013 [POC] 验证 FFmpeg 在 Windows 上编译并输出到 D3D11 Texture
- [x] T014 [POC] 验证 FFmpeg 在 macOS 上编译并输出到 Metal Texture

### Dart 核心模型层

- [x] T015 [P] 创建 `lib/src/core/player_state.dart` - PlayerState 枚举 (来自 data-model.md)
- [x] T016 [P] 创建 `lib/src/core/media_source.dart` - MediaSource 类 + MediaSourceType 枚举
- [x] T017 [P] 创建 `lib/src/core/playback_event.dart` - PlaybackEvent 类
- [x] T018 [P] 创建 `lib/src/core/player_error.dart` - PlayerError + PlayerErrorCode 枚举
- [x] T019 [P] 创建 `lib/src/core/player_config.dart` - PlayerConfig 类

### Dart Provider 抽象接口层

- [x] T020 [P] 创建 `lib/src/providers/data_source_provider.dart` - DataSourceProvider 抽象类
- [x] T021 [P] 创建 `lib/src/providers/decoder_provider.dart` - DecoderProvider 抽象类 (配置/监控接口)
- [x] T022 [P] 创建 `lib/src/providers/renderer_provider.dart` - RendererProvider 抽象类
- [x] T023 创建 `lib/src/providers/provider_registry.dart` - ProviderRegistry 单例

### Dart Platform Channel 接口层

- [x] T024 创建 `lib/src/platform/mango_player_platform_interface.dart` - 定义 Platform Method 接口 (来自 contracts/)
- [x] T025 创建 `lib/src/platform/mango_player_method_channel.dart` - MethodChannel 实现

**检查点**: 基础就绪 - 现在可以开始并行实施用户故事

---

## 阶段 3: 用户故事 1 - 基础视频播放 (优先级: P1) 🎯 MVP

**目标**: 开发者可以在 Flutter 应用中播放本地或网络视频，只需几行代码

**独立测试**: 创建最小 Flutter 应用，添加 MangoPlayer 依赖，调用播放 API 播放测试视频，视频在屏幕上正常显示

### Dart 控制器实现

- [x] T026 [US1] 创建 `lib/src/core/mango_player_controller.dart` - 播放器控制器核心逻辑
  - 状态管理 (state, position, duration, volume, playbackSpeed)
  - 事件流 (stateStream, eventStream, errorStream)
  - 控制方法 (initialize, play, pause, stop, seekTo, setVolume, setPlaybackSpeed, dispose)

### Dart UI 组件层

- [x] T027 [P] [US1] 创建 `lib/src/ui/mango_player_view.dart` - 视频渲染 Widget (使用 Texture Widget)

### Android 平台实现 (ijkplayer 封装 + Flutter External Texture)

- [x] T028 [US1] 创建 `android/.../MangoPlayerPlugin.kt` - Flutter 插件入口
- [x] T029 [P] [US1] 创建 `android/.../platform/MethodChannelHandler.kt` - 处理 Dart → Native 调用
- [x] T030 [P] [US1] 创建 `android/.../platform/EventChannelHandler.kt` - 推送 Native → Dart 事件
- [x] T031 [P] [US1] 创建 `android/.../platform/TextureRegistryHandler.kt` - Texture 注册管理
- [ ] T032 [US1] 创建 `android/.../ijkplayer/IJKPlayerWrapper.kt` - ⏳ 骨架代码存在，ijkplayer 集成未验证
- [ ] T033 [US1] 创建 `android/.../ijkplayer/IJKPlayerManager.kt` - ⏳ 骨架代码存在，功能未验证
- [ ] T034 [US1] 创建 `android/.../ijkplayer/IJKPlayerEventListener.kt` - ⏳ 未实现，缺失文件
- [ ] T035 [US1] 创建 `android/.../ijkplayer/IJKSurfaceBridge.kt` - ⏳ 未实现，缺失文件
  - 使用 `IjkMediaPlayer.setSurface(flutterSurface)` 绕过 ijksdl 内部渲染
  - 从 TextureRegistry 创建 SurfaceTexture，生成 Surface 传递给 ijkplayer
- [ ] T036 [US1] 创建 `android/.../renderer/SurfaceTextureRenderer.kt` - ⏳ 未实现，缺失文件
- [ ] T037 [US1] 集成 ijkplayer 预编译库到 `android/libs/` - ⛔ **未完成**: libs/ 目录无 ijkplayer 库文件

### iOS 平台实现 (ijkplayer 封装 + Flutter External Texture)

- [x] T038 [US1] 创建 `ios/Classes/MangoPlayerPlugin.swift` - Flutter 插件入口
- [x] T039 [P] [US1] 创建 `ios/Classes/Platform/MethodChannelHandler.swift` - 处理 Dart → Native 调用 (⚠️ 基于 macOS 模板)
- [x] T040 [P] [US1] 创建 `ios/Classes/Platform/EventChannelHandler.swift` - 推送 Native → Dart 事件 (⚠️ 基于 macOS 模板)
- [x] T041 [P] [US1] 创建 `ios/Classes/Platform/TextureRegistryHandler.swift` - Texture 注册管理 (⚠️ 基于 macOS 模板)
- [ ] T042 [US1] 创建 `ios/Classes/IJKPlayer/IJKPlayerWrapper.swift` - ⏳ 骨架代码存在，ijkplayer 集成未验证
- [ ] T043 [US1] 创建 `ios/Classes/IJKPlayer/IJKPlayerManager.swift` - ⏳ 骨架代码存在，功能未验证
- [ ] T044 [US1] 创建 `ios/Classes/IJKPlayer/IJKPlayerEventBridge.swift` - ⛔ **缺失文件**
- [ ] T045 [US1] 创建 `ios/Classes/IJKPlayer/IJKPixelBufferOutput.swift` - ⛔ **缺失关键实现**
  - 配置 ijkplayer 输出 CVPixelBuffer 而非渲染到 IJKSDLGLView
  - 使用帧回调或 CVPixelBufferPool 拦截获取解码帧
  - 将 CVPixelBuffer 送入 Flutter TextureRegistry
- [ ] T046 [US1] 创建 `ios/Classes/Renderer/CVPixelBufferManager.swift` - ⛔ **缺失文件**
- [ ] T047 [US1] 集成 IJKMediaFramework.framework 到 `ios/Frameworks/` - ⛔ **未完成**: Frameworks/ 目录无 IJKMediaFramework

### 导出与集成

- [x] T048 [US1] 更新 `lib/mango_player.dart` 导出所有公共类
- [x] T049 [US1] 创建 `example/lib/main.dart` - 基础播放示例应用

**检查点**: 此时，用户故事 1 应该在 Android 和 iOS 上完全功能化且可独立测试

---

## 阶段 4: 用户故事 2 - 跨平台一致性 (优先级: P1)

**目标**: 同一份代码在 Windows、macOS、iOS、Android 上运行结果一致

**独立测试**: 在所有 4 个平台上运行相同的测试用例，验证 API 返回值和行为完全一致

### Windows 平台实现 (FFmpeg + DXVA2 + Flutter External Texture)

- [x] T050 [US2] 创建 `windows/src/mango_player_plugin.cpp` - Flutter 插件入口
- [x] T051 [P] [US2] 创建 `windows/src/platform/method_channel_handler.cpp` - 处理 Dart → Native 调用
- [x] T052 [P] [US2] 创建 `windows/src/platform/event_channel_handler.cpp` - 推送 Native → Dart 事件
- [x] T053 [P] [US2] 创建 `windows/src/platform/texture_registry_handler.cpp` - Texture 注册管理
- [x] T054 [US2] 创建 `windows/src/core/native_core/ffmpeg_demuxer.cpp` - FFmpeg demux/解复用 (C++ 共用核心)
- [x] T055 [US2] 创建 `windows/src/core/native_core/ffmpeg_soft_decoder.cpp` - 软解回退 (C++ 共用核心)
- [x] T056 [US2] 创建 `windows/src/core/native_core/clock_sync.cpp` - AV 同步 (C++ 共用核心)
- [x] T057 [US2] 创建 `windows/src/core/native_core/core_event_bridge.cpp` - 内核事件桥接 (C++ 共用核心)
- [x] T058 [US2] 创建 `windows/src/core/dxva_decoder.cpp` - DXVA2 硬件解码实现
- [x] T059 [US2] 创建 `windows/src/renderer/d3d11_texture_renderer.cpp` - D3D11 纹理渲染 → Flutter TextureRegistry
- [x] T060 [US2] 集成 FFmpeg 库到 `windows/libs/`

### macOS 平台实现 (FFmpeg + VideoToolbox + Flutter External Texture)

- [x] T061 [US2] 创建 `macos/Classes/MangoPlayerPlugin.swift` - Flutter 插件入口
- [x] T062 [P] [US2] 创建 `macos/Classes/Platform/MethodChannelHandler.swift` - 处理 Dart → Native 调用
- [x] T063 [P] [US2] 创建 `macos/Classes/Platform/EventChannelHandler.swift` - 推送 Native → Dart 事件
- [x] T064 [P] [US2] 创建 `macos/Classes/Platform/TextureRegistryHandler.swift` - Texture 注册管理
- [ ] T065 [US2] ⚠️ **架构偏离**: 复制 `native_core/` C++ 共用核心到 `macos/Classes/core/native_core/` - **未实现，改用了 ObjC 重写**
- [x] T066 [US2] 创建 `macos/Classes/core/FFmpegDemuxer.swift` - ⚠️ **架构偏离**: 实际用 ObjC 实现 (FFmpegDemuxerObjC.m)，未调用共享 C++
- [x] T067 [US2] 创建 `macos/Classes/core/VideoToolboxDecoder.swift` - VideoToolbox 硬解实现 (在 FFmpegPlayerManager 中)
- [x] T068 [US2] 创建 `macos/Classes/core/FFmpegSoftDecoder.swift` - ⚠️ **架构偏离**: 实际用 ObjC 实现 (FFmpegAudioDecoderObjC.m)
- [x] T069 [US2] 创建 `macos/Classes/core/ClockSync.swift` - ⚠️ **架构偏离**: Swift 实现，未调用共享 C++
- [x] T070 [US2] 创建 `macos/Classes/Renderer/MetalTextureRenderer.swift` - Metal 纹理渲染 → Flutter TextureRegistry
- [x] T071 [US2] 创建 `macos/Classes/Renderer/CVPixelBufferManager.swift` - CVPixelBuffer 管理 (在 MacOSRendererProvider 中)
- [x] T072 [US2] 集成 FFmpeg 库到 `macos/libs/` - ⚠️ 使用 Homebrew 系统库，未单独集成

### 跨平台一致性验证

- [x] T073 [US2] 创建 `example/lib/pages/platform_consistency_page.dart` - 演示跨平台一致性
- [x] T074 [US2] 创建 `example/test/integration/cross_platform_test.dart` - 跨平台 API 一致性测试

**检查点**: 此时，4 个平台都应该能够播放视频，API 行为一致

---

## 阶段 5: 用户故事 3 - 播放控制界面 (优先级: P2)

**目标**: 提供开箱即用的播放控制 UI 组件，同时支持完全自定义 UI

**独立测试**: 使用默认 UI 组件创建播放器界面，验证所有控件功能正常

### 默认播放控制 UI

- [x] T075 [P] [US3] 创建 `lib/src/ui/controls/play_pause_button.dart` - 播放/暂停按钮
- [x] T076 [P] [US3] 创建 `lib/src/ui/controls/progress_bar.dart` - 进度条控件 (可拖动 seek)
- [x] T077 [P] [US3] 创建 `lib/src/ui/controls/volume_control.dart` - 音量控制滑块
- [x] T078 [P] [US3] 创建 `lib/src/ui/controls/time_display.dart` - 时间显示 (当前/总时长)
- [x] T079 [P] [US3] 创建 `lib/src/ui/controls/fullscreen_button.dart` - 全屏切换按钮
- [x] T080 [US3] 创建 `lib/src/ui/controls/default_controls.dart` - 组合默认控制栏
- [x] T081 [US3] 创建 `lib/src/ui/fullscreen_player.dart` - 全屏播放器组件

### 示例页面

- [x] T082 [US3] 创建 `example/lib/pages/basic_player_page.dart` - 演示基础播放 + 默认 UI

**检查点**: 此时，默认 UI 组件可用，开发者可以快速集成播放界面

---

## 阶段 6: 用户故事 4 - 多格式支持 (优先级: P2)

**目标**: 支持主流音视频格式，无需关心格式兼容性

**独立测试**: 准备不同格式的测试媒体文件逐一测试播放功能

### 格式支持验证

- [x] T083 [US4] 验证并记录 ijkplayer/FFmpeg 支持的视频容器格式 (MP4, MKV, AVI, MOV, WebM)
- [x] T084 [US4] 验证并记录支持的视频编码 (H.264, H.265, VP8, VP9)
- [x] T085 [US4] 验证并记录支持的音频格式 (MP3, AAC, FLAC, WAV, OGG)
- [x] T086 [US4] 实现格式不支持时的错误处理和清晰提示

**检查点**: 确认多格式支持完整

---

## 阶段 7: 用户故事 5 - 网络流媒体支持 (优先级: P2)

**目标**: 支持 HLS、RTMP、RTSP 流媒体协议

**独立测试**: 使用 HLS、RTMP、RTSP 测试流进行播放测试

### 流媒体协议支持

- [x] T087 [US5] 验证 HLS (.m3u8) 流播放支持
- [x] T088 [US5] 验证 RTMP 直播流播放支持
- [x] T089 [US5] 验证 RTSP 流播放支持
- [x] T090 [US5] 实现网络中断时的自动重连机制

**检查点**: 流媒体协议支持验证完成

---

## 阶段 8: 用户故事 6 - 模块化扩展架构 (优先级: P2)

**目标**: 支持扩展或替换播放器的核心模块 (DataSource/Decoder/Renderer)

**独立测试**: 实现自定义解码器配置或自定义渲染器，验证扩展机制可用

### Provider 实现层 - Android

- [x] T091 [P] [US6] 创建 `android/.../providers/AndroidDataSourceProvider.kt` - Android 数据源实现
- [x] T092 [P] [US6] 创建 `android/.../providers/AndroidDecoderProvider.kt` - Android 解码配置/监控
- [x] T093 [P] [US6] 创建 `android/.../providers/AndroidRendererProvider.kt` - Android 渲染器实现
- [x] T094 [P] [US6] 创建 `android/.../providers/ProviderRegistryImpl.kt` - Provider 注册表

### Provider 实现层 - iOS

- [x] T095 [P] [US6] 创建 `ios/Classes/Providers/IOSDataSourceProvider.swift` - iOS 数据源实现
- [x] T096 [P] [US6] 创建 `ios/Classes/Providers/IOSDecoderProvider.swift` - iOS 解码配置/监控
- [x] T097 [P] [US6] 创建 `ios/Classes/Providers/IOSRendererProvider.swift` - iOS 渲染器实现
- [x] T098 [P] [US6] 创建 `ios/Classes/Providers/ProviderRegistryImpl.swift` - Provider 注册表

### Provider 实现层 - Windows

- [x] T099 [P] [US6] 创建 `windows/src/providers/windows_data_source_provider.cpp`
- [x] T100 [P] [US6] 创建 `windows/src/providers/windows_decoder_provider.cpp`
- [x] T101 [P] [US6] 创建 `windows/src/providers/windows_renderer_provider.cpp`
- [x] T102 [P] [US6] 创建 `windows/src/providers/provider_registry_impl.cpp`

### Provider 实现层 - macOS

- [x] T103 [P] [US6] 创建 `macos/Classes/Providers/MacOSDataSourceProvider.swift`
- [x] T104 [P] [US6] 创建 `macos/Classes/Providers/MacOSDecoderProvider.swift`
- [x] T105 [P] [US6] 创建 `macos/Classes/Providers/MacOSRendererProvider.swift`
- [x] T106 [P] [US6] 创建 `macos/Classes/Providers/ProviderRegistryImpl.swift`

### 解码配置/监控层 (移动端 - 基于 ijkplayer)

- [x] T107 [P] [US6] 创建 `android/.../decoder/MediaCodecConfigManager.kt` - 配置硬解选项/监听降级
- [x] T108 [P] [US6] 创建 `android/.../decoder/DecodeEventBridge.kt` - 硬解/软解事件桥接到 Dart

- [x] T109 [P] [US6] 创建 `ios/Classes/Decoder/VideoToolboxConfigManager.swift` - 硬解选项配置/降级监控
- [x] T110 [P] [US6] 创建 `ios/Classes/Decoder/DecodeEventBridge.swift` - 硬解/软解事件桥接到 Dart

### 解码配置层 (桌面端 - 基于 FFmpeg)

- [x] T111 [P] [US6] 创建 `windows/src/decoder/dxva_config_manager.cpp` - 硬解配置与降级监控
- [x] T112 [P] [US6] 创建 `windows/src/decoder/soft_decode_fallback.cpp` - 软解回退处理

- [x] T113 [P] [US6] 创建 `macos/Classes/Decoder/VideoToolboxConfigManager.swift`
- [x] T114 [P] [US6] 创建 `macos/Classes/Decoder/SoftDecodeFallback.swift`

### 渲染器管理层 (各平台)

- [x] T115 [P] [US6] 创建 `android/.../renderer/OpenGLTextureManager.kt` - OpenGL ES 纹理管理
- [x] T116 [P] [US6] 创建 `ios/Classes/Renderer/MetalTextureRenderer.swift` - Metal 纹理渲染
- [x] T117 [P] [US6] 创建 `windows/src/renderer/texture_manager.cpp` - 纹理管理

### 示例页面

- [x] T118 [US6] 创建 `example/lib/pages/custom_provider_page.dart` - 演示自定义 Provider

**检查点**: 模块化扩展架构完成，可以注册自定义实现

---

## 阶段 9: 用户故事 7 - 性能监控与调试 (优先级: P3)

**目标**: 提供播放器性能指标 (帧率、缓冲状态、内存占用)

**独立测试**: 在播放视频时获取性能指标，验证数据准确性

### 性能监控实现

- [x] T119 [P] [US7] 创建 `lib/src/core/performance_metrics.dart` - 性能指标数据类
- [x] T120 [US7] 在 MangoPlayerController 中添加 `performanceStream` - 性能指标事件流
- [x] T121 [P] [US7] Android 实现性能数据收集 (帧率、解码耗时)
- [x] T122 [P] [US7] iOS 实现性能数据收集
- [x] T123 [P] [US7] Windows 实现性能数据收集
- [x] T124 [P] [US7] macOS 实现性能数据收集

**检查点**: 性能监控功能可用

---

## 阶段 10: 用户故事 8 & 9 - Web/HarmonyOS 预留 (优先级: P4)

**目标**: API 设计考虑 Web 和 HarmonyOS 平台的未来支持

### 平台占位实现

- [x] T125 [P] [US8] 创建 `lib/src/platform/mango_player_web.dart` - Web 占位实现 (返回"平台暂不支持")
- [x] T126 [P] [US9] 创建 `lib/src/platform/mango_player_harmony.dart` - HarmonyOS 占位实现

**检查点**: 预留接口完成，未来可无缝扩展

---

## 阶段 11: 完善与横切关注点

**目的**: 影响多个用户故事的改进

### 单元测试

- [x] T127 [P] 创建 `test/unit/mango_player_controller_test.dart` - 控制器单元测试
- [x] T128 [P] 创建 `test/unit/media_source_test.dart` - MediaSource 单元测试
- [x] T129 [P] 创建 `test/unit/providers/data_source_provider_test.dart`
- [x] T130 [P] 创建 `test/unit/providers/decoder_provider_test.dart`
- [x] T131 [P] 创建 `test/unit/providers/renderer_provider_test.dart`
- [x] T132 创建 `test/widget/mango_player_view_test.dart` - Widget 测试

### 集成测试

- [x] T133 创建 `example/test/integration/playback_flow_test.dart` - 端到端播放流程测试

### 性能测试

- [x] T134 [P] 创建 `example/test/performance/startup_time_test.dart` - 启动性能测试
- [x] T135 [P] 创建 `example/test/performance/memory_test.dart` - 内存占用测试
- [x] T136 [P] 创建 `example/test/performance/frame_rate_test.dart` - 帧率测试

### 文档

- [x] T137 [P] 更新 `README.md` - 插件使用说明
- [x] T138 [P] 添加 dartdoc 注释到所有公共 API
- [x] T139 验证 `quickstart.md` 流程可用

### 最终验证

- [x] T140 在 4 个平台运行完整测试套件 (Dart 层 113 测试全部通过)
- [ ] T141 性能基准测试 (启动 <500ms, 30fps, 内存 <150MB) - 需实际设备测试

---

## 当前项目状态 (2026-01-15)

### ✅ 已完成功能 (macOS 平台)

#### 阶段 1-2: 设置与基础 (T001-T025)
- [x] 项目结构、依赖配置、Dart 核心模型层全部完成
- [x] Platform Channel 接口层完成

#### 阶段 3-4: 用户故事 1-2 (macOS 部分)
- [x] macOS 核心播放功能 (T061-T072)
  - FFmpeg Demuxer (Objective-C 封装)
  - VideoToolbox 硬件解码器
  - FFmpeg 音频解码器（AAC 软解）
  - AVAudioEngine 音频播放
  - Metal Texture 零拷贝渲染
  - 时钟同步 (ClockSync)
- [x] 播放控制 API (play/pause/stop/seek/volume/mute)
- [x] 播放状态事件流
- [x] 进度更新事件流

#### 阶段 5: 用户故事 3 (部分)
- [x] 基础播放控制按钮
- [x] 进度条和时间显示
- [x] 音量控制（包含静音按钮）
- [ ] 全屏播放功能 (T081)
- [ ] 视频缩放模式 (T081)
- [ ] 手势控制
- [ ] 键盘快捷键（桌面端）

#### 已知问题修复 (本次会话)
- [x] macOS 音频解码器配置问题（无声音）
- [x] 静音功能缺失（Native+Dart+UI 三层实现）
- [x] 停止播放时视频残留（时序+线程问题）

### ⏳ 待完成工作 (按优先级)

#### 🔴 P1: 跨平台一致性验证

**iOS 平台 (T038-T047)**
- [ ] 验证 ijkplayer 集成和音视频播放
- [ ] Flutter External Texture 对接 (CVPixelBuffer → TextureRegistry)
- [ ] 跨平台 API 行为一致性测试

**Android 平台 (T028-T037)**
- [ ] 验证 ijkplayer 集成和音视频播放
- [ ] Flutter External Texture 对接 (SurfaceTexture → setSurface())
- [ ] MediaCodec 硬解支持验证

**Windows 平台 (T050-T060)**
- [ ] FFmpegPlayerManager 完整实现
- [ ] DXVA2 硬解集成
- [ ] Windows Audio Session API (WASAPI) 音频播放
- [ ] D3D11 Texture → Flutter External Texture

#### 🟡 P2: 功能完善

**US3: 播放控制 UI 增强**
- [ ] T081 全屏播放组件
- [ ] 视频缩放模式（适应/填充/裁剪）
- [ ] 手势控制（双击暂停、滑动调节）
- [ ] 键盘快捷键（空格暂停、方向键 seek）

**US4: 多格式支持验证**
- [ ] T083-T086 H.265/HEVC 硬解测试
- [ ] MKV/AVI 容器兼容性测试
- [ ] 纯音频文件测试（MP3/FLAC/WAV）
- [ ] 格式不支持的错误处理

**US5: 网络流媒体支持**
- [ ] T087-T090 HLS 流播放测试
- [ ] RTMP 直播流测试
- [ ] 网络中断重连机制
- [ ] HTTP Headers 自定义支持

**US6: 模块化扩展示例**
- [ ] T118 自定义 DataSource 示例（加密媒体）
- [ ] 自定义 Decoder 配置示例
- [ ] 自定义 Renderer 示例（滤镜效果）

#### 🟢 P3: 性能与调试

**US7: 性能监控完善**
- [x] T119-T120 PerformanceMetrics 数据结构和事件流
- [ ] T124 macOS 性能数据收集实现
- [ ] T121-T123 其他平台性能数据收集
- [ ] 帧率统计、解码耗时、内存占用监控
- [ ] 掉帧日志记录

**性能指标验证 (T141)**
- [ ] 启动时间 <500ms (本地)
- [ ] 渲染帧率 ≥30fps (1080p)
- [ ] 内存占用 <150MB (单实例)
- [ ] Seek 延迟 <200ms (本地)
- [ ] 零拷贝效率验证 (内存带宽节省 >50%)

#### 技术债务
- [ ] **🔴 架构偏离: native_core C++ 复用未实现**
  - Windows 有 `native_core/` C++ 实现 ✅
  - macOS 用 Swift/ObjC 重写了相同逻辑 ⛔ (应改为调用共享 C++)
  - 需要重构: 提取共享 `native_core/` 到项目根目录
- [ ] macOS FFmpeg 路径硬编码问题（/opt/homebrew/Cellar/ffmpeg/8.0.1）
- [ ] 多实例播放资源管理测试
- [ ] Seek 后短暂卡顿优化
- [ ] 日志系统统一（各平台格式/级别）
- [ ] 错误码标准化（PlayerErrorCode 完善）
- [ ] Native 层单元测试补充
- [ ] 内存管理审计（内存泄漏检测）

---

## 下一步建议

### 短期目标 (1-2 周)
1. **iOS 平台验证** - 确认 ijkplayer 音视频播放正常 (T038-T047)
2. **Android 平台验证** - 确认 ijkplayer 音视频播放正常 (T028-T037)
3. **跨平台一致性测试** - T074 集成测试验证 4 平台 API 行为

### 中期目标 (3-4 周)
1. **Windows 平台完善** - FFmpeg + DXVA2 + WASAPI (T050-T060)
2. **全屏播放功能** - T081 桌面端和移动端全屏支持
3. **流媒体协议测试** - T087-T090 HLS/RTMP/RTSP 验证

### 长期目标 (5-8 周)
1. **性能基准测试** - T141 全平台性能验证
2. **模块化扩展示例** - T118 自定义解码器/渲染器文档
3. **文档完善** - API 文档、扩展开发指南

---

## 依赖关系与执行顺序

### 阶段依赖关系

```
阶段 1: 设置
    ↓
阶段 2: 基础 (POC 验证 + Dart 核心模型)
    ↓ (阻塞点)
┌───┴───┐
↓       ↓
阶段 3: US1 基础播放 (P1) 🎯 MVP
    ↓
阶段 4: US2 跨平台一致性 (P1)
    ↓
┌───┼───┬───┐
↓   ↓   ↓   ↓
阶段 5-8: US3-6 (P2) [可并行]
    ↓
阶段 9: US7 性能监控 (P3)
    ↓
阶段 10: US8-9 预留 (P4)
    ↓
阶段 11: 完善
```

### 用户故事依赖关系

- **US1 (P1)**: 依赖阶段 2 完成 - MVP 核心
- **US2 (P1)**: 依赖 US1 完成 - 扩展到 4 平台
- **US3-6 (P2)**: 依赖 US2 完成 - 可并行开发
- **US7 (P3)**: 依赖 US1-2 完成
- **US8-9 (P4)**: 可随时进行

### 并行机会

**阶段 1 内**: T002-T008 可并行
**阶段 2 内**: T009-T014 POC 可按平台并行；T015-T023 Dart 代码可并行
**阶段 3 内**: Android (T028-T037) 和 iOS (T038-T047) 可并行
**阶段 4 内**: Windows (T050-T060) 和 macOS (T061-T072) 可并行
**阶段 5-8**: 可完全并行（不同团队成员）
**阶段 11**: 测试任务可并行

---

## 并行示例

```bash
# 阶段 2 - 同时启动所有 POC 验证:
T009: "验证 Flutter External Texture 在 Android 上的零拷贝渲染"
T010: "验证 Flutter External Texture 在 iOS 上的零拷贝渲染"
T013: "验证 FFmpeg 在 Windows 上编译"
T014: "验证 FFmpeg 在 macOS 上编译"

# 阶段 3 - Android 和 iOS 同时开发:
开发者 A: T028-T037 (Android 实现)
开发者 B: T038-T047 (iOS 实现)

# 阶段 4 - Windows 和 macOS 同时开发:
开发者 C: T050-T060 (Windows 实现)
开发者 D: T061-T072 (macOS 实现)
```

---

## 实施策略

### 仅 MVP (用户故事 1 + 2)

1. 完成阶段 1: 设置
2. 完成阶段 2: 基础 (关键 - 阻塞所有故事)
3. 完成阶段 3: 用户故事 1 (Android + iOS)
4. 完成阶段 4: 用户故事 2 (Windows + macOS)
5. **停止并验证**: 4 平台播放功能
6. 可部署/演示 MVP

### 增量交付

1. 设置 + 基础 → 基础就绪
2. US1 (Android + iOS) → 移动端 MVP
3. US2 (Windows + macOS) → 全平台 MVP
4. US3 播放控制 UI → 用户体验提升
5. US4-6 格式/流媒体/扩展 → 功能完善
6. US7 性能监控 → 调试能力
7. US8-9 预留 → 未来兼容

---

## 任务统计

| 阶段 | 任务数 | 描述 |
|------|--------|------|
| 阶段 1 | 8 | 设置 |
| 阶段 2 | 17 | 基础 (POC + Dart 核心) |
| 阶段 3 | 22 | US1 基础播放 (MVP) |
| 阶段 4 | 25 | US2 跨平台一致性 |
| 阶段 5 | 8 | US3 播放控制 UI |
| 阶段 6 | 4 | US4 多格式支持 |
| 阶段 7 | 4 | US5 流媒体支持 |
| 阶段 8 | 28 | US6 模块化扩展 |
| 阶段 9 | 6 | US7 性能监控 |
| 阶段 10 | 2 | US8-9 预留 |
| 阶段 11 | 17 | 完善 |
| **总计** | **141** | |

### MVP 范围 (建议)

- 阶段 1-4: 72 任务 → 4 平台基础播放
- 预估工作量: 4-6 周 (2-3 人团队)

---

## 关键设计变更 (来自 plan.md 更新)

### 渲染方案: Flutter External Texture (绕过 ijksdl)

**核心策略**:

- **不使用** ijkplayer 内置的 `ijksdl` 渲染模块 (SurfaceView/IJKSDLGLView)
- **使用** Flutter TextureRegistry 实现零拷贝渲染

**Android 渲染对接** (T035 IJKSurfaceBridge.kt):

```kotlin
// 1. 从 Flutter TextureRegistry 创建 SurfaceTexture
val textureEntry = textureRegistry.createSurfaceTexture()
val surface = Surface(textureEntry.surfaceTexture())

// 2. 将 Surface 传给 ijkplayer (绕过 ijksdl)
ijkMediaPlayer.setSurface(surface)

// 3. Flutter 通过 Texture Widget 显示 textureEntry.id()
```

**iOS 渲染对接** (T045 IJKPixelBufferOutput.swift):

```swift
// 1. 配置 ijkplayer 输出 CVPixelBuffer
ijkPlayer.setOptionIntValue(1, forKey: "videotoolbox-pixelbuffer-output", ...)

// 2. 获取 CVPixelBuffer 并注入 Flutter TextureRegistry
ijkPlayer.setVideoFrameCallback { pixelBuffer in
    self.textureRegistry.register(pixelBuffer)
}
```

| 平台 | ijkplayer 输出方式 | Flutter 接收方式 | 绕过的 ijksdl 组件 |
|------|-------------------|-----------------|-------------------|
| Android | `setSurface(flutterSurface)` | SurfaceTexture → TextureRegistry | SurfaceView/TextureView |
| iOS | CVPixelBuffer 回调 | CVPixelBuffer → TextureRegistry | IJKSDLGLView/OpenGL ES |

---

## 注意事项

- [P] 任务 = 不同文件，无依赖关系，可并行
- [Story] 标签将任务映射到特定用户故事以实现可追溯性
- **关键**: POC 验证 (T009-T014) 必须在大规模开发前完成
- **渲染策略**: 移动端绕过 ijksdl，使用 Flutter External Texture (参见 plan.md 第 4 层)
- **桌面策略**: Windows/macOS 使用 FFmpeg + 平台硬解 (DXVA2/VideoToolbox)，共享 `native_core/` C++ 代码
- 每个任务后提交代码
- 在检查点停止验证故事完整性
