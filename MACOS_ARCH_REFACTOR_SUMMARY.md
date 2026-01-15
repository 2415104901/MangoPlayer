# macOS 全链路架构重构完成总结

## 完成的任务 (Tasks Completed)

根据 `specs/001-cross-platform-player/tasks.md` 中的 macOS 全链路要求，已完成以下任务：

### ✅ T-ARCH-007: macOS VideoToolboxDecoder 实现
**文件**: `macos/Classes/NativeCore/VideoToolboxDecoder.h/mm`
- 实现了 `IHardwareDecoder` 接口
- 使用 Apple VideoToolbox API 进行硬件解码
- 支持 H.264 和 H.265/HEVC 解码
- 输出 CVPixelBuffer 用于零拷贝渲染
- 异步解码 + 回调处理

### ✅ T-ARCH-008: macOS MetalTextureOutput 实现  
**文件**: `macos/Classes/NativeCore/MetalTextureOutput.h/mm`
- 实现了 `ITextureOutput` 接口
- 使用 Metal 框架创建纹理
- 处理硬件解码帧（CVPixelBuffer）和软件解码帧
- 与 Flutter TextureRegistry 集成

### ✅ T-ARCH-009: macOS AVAudioEngineOutput 实现
**文件**: `macos/Classes/NativeCore/AVAudioEngineOutput.h/mm`
- 实现了 `IAudioOutput` 接口
- 使用 AVAudioEngine + AVAudioPlayerNode 播放音频
- 支持音量和静音控制
- 管理音频缓冲区用于 AV 同步

### ✅ T-ARCH-017: 更新 mango_player.podspec
**修改内容**:
1. 添加 `.mm` 文件到 source_files（支持 Objective-C++）
2. 链接 native_core 静态库：
   - `libmango_player_native_core.a`
   - `libmango_player_c_bridge.a`
3. 添加 native_core include 路径到 HEADER_SEARCH_PATHS
4. 添加 NativeCore 头文件到 public_header_files
5. 排除 `.template` 文件

### ✅ 额外完成: 修复 native_core 编译错误
**文件**: `native_core/include/mango_player/interfaces/hw_decoder.h`
- 修复了 C++ 枚举前向声明问题
- 直接包含 FFmpeg 头文件而不是前向声明枚举类型

**文件**: `native_core/CMakeLists.txt`
- 为 c_bridge 目标添加 FFmpeg 头文件路径

### ✅ 额外完成: 更新 BridgingHeader.h
**文件**: `macos/Classes/BridgingHeader.h`
- 添加 `mango_player/c_bridge/mango_player_c.h` 导入
- 添加 NativeCore 平台实现头文件导入

### ✅ 构建验证
- native_core 静态库成功编译 (arm64 + x86_64)
- macOS 应用成功构建
- 所有新代码通过编译

## 架构概览

```
Flutter Dart Layer (MangoPlayerController)
    ↓ MethodChannel
Swift Platform Layer (MethodChannelHandler)
    ↓ (未来) 通过 NativeCorePlayerBridge
C Bridge API (mango_player_c.h)
    ↓
Native Core C++ (PlayerCore, Demuxer, SoftDecoder, ClockSync)
    ↓ 依赖注入
Platform Implementations (Objective-C++):
    - VideoToolboxDecoder (IHardwareDecoder)
    - MetalTextureOutput (ITextureOutput)
    - AVAudioEngineOutput (IAudioOutput)
```

## 构建说明

### 1. 构建 native_core 库
```bash
cd native_core
mkdir -p build && cd build
cmake .. -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
make -j4
```

输出:
- `libmango_player_native_core.a`
- `libmango_player_c_bridge.a`

### 2. 构建 Flutter 应用
```bash
cd example
flutter build macos
```

## 未完成的任务

### T-ARCH-010: 重构 FFmpegPlayerManager.swift
**状态**: 未开始
**说明**: 
- 需要将 `FFmpegPlayerManager.swift` 重构为使用 `NativeCorePlayerBridge`
- 已创建桥接模板：`macos/Classes/NativeCore/NativeCorePlayerBridge.swift.template`
- 需要解决 C 桥接函数的 Swift 导入问题

**建议步骤**:
1. 在模块映射中正确导出 C 桥接函数
2. 实现 `NativeCorePlayerBridge.swift` 的完整功能
3. 更新 `MethodChannelHandler.swift` 使用新桥接层
4. 测试音视频播放功能
5. 验证内存管理正确

### T-ARCH-015: 删除 macOS 重复代码
**状态**: 未开始
**计划删除的文件**:
- `macos/Classes/core/FFmpegDemuxerObjC.m/h` → 被 native_core/demuxer.cpp 替代
- `macos/Classes/core/ClockSync.swift` → 被 native_core/clock_sync.cpp 替代
- `macos/Classes/core/FFmpegAudioDecoderObjC.m/h` → 被 native_core/soft_decoder.cpp 替代

**注意**: 仅在 T-ARCH-010 完成并验证后才能安全删除

### T-ARCH-019, 021, 022, 025, 026
**状态**: 依赖 T-ARCH-010
这些任务是关于其他平台或更高级功能，需要先完成 macOS 基础重构

## 技术债务

1. **C 桥接导入问题**: 
   - Swift 无法直接找到 `mango_player_create` 等 C 函数
   - 可能需要创建模块映射文件 (module.modulemap)

2. **静态库路径硬编码**:
   - podspec 中使用相对路径 `../native_core/build/`
   - 生产环境应使用 vendored 库或 CocoaPods 子模块

3. **FFmpeg 路径硬编码**:
   - 依赖 Homebrew 安装路径 `/opt/homebrew/Cellar/ffmpeg/8.0.1`
   - 应改为通过 pkg-config 或捆绑 FFmpeg

4. **NativeCorePlayerBridge 未集成**:
   - 当前仍使用旧的 `FFmpegPlayerManager.swift`
   - 新桥接层仅作为模板存在

## 测试建议

完成 T-ARCH-010 后:

1. **功能测试**:
   - 基础播放（本地文件 + 网络流）
   - 播放控制（播放/暂停/停止/seek）
   - 音量控制和静音
   - 视频渲染（Metal texture）

2. **性能测试**:
   - 内存占用 < 150MB
   - 帧率 ≥ 30fps (1080p)
   - 启动时间 < 500ms

3. **稳定性测试**:
   - 内存泄漏检测
   - 多次播放循环
   - Seek 稳定性
   - 格式兼容性

## 下一步行动

**短期（1-2天）**:
1. 解决 C 桥接函数导入问题
2. 实现 `NativeCorePlayerBridge.swift`
3. 集成到 `MethodChannelHandler.swift`

**中期（3-5天）**:
1. 完整测试音视频播放
2. 性能验证和优化
3. 删除重复代码 (T-ARCH-015)

**长期（1-2周）**:
1. 跨平台验证（iOS, Windows, Android）
2. 文档完善
3. API 示例和教程

## 参考文档

- `macos/NATIVE_CORE_INTEGRATION.md` - 详细架构说明
- `native_core/README.md` - native_core 库说明
- `native_core/include/mango_player/c_bridge/mango_player_c.h` - C 桥接 API
- `specs/001-cross-platform-player/tasks.md` - 任务列表

## 贡献者

- 架构设计: 基于 `specs/001-cross-platform-player/`
- 实现日期: 2026-01-15
- 平台: macOS (arm64 + x86_64)
