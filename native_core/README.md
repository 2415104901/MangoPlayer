# Native Core 架构说明

**更新日期**: 2026-01-15
**状态**: 架构已创建，平台集成待完成

## 概述

`native_core/` 是 MangoPlayer 的跨平台 C++ 核心库，包含 100% 跨平台的播放逻辑，通过接口模式与平台特定实现解耦。

## 目录结构

```
native_core/
├── CMakeLists.txt                          # 跨平台构建配置
├── include/
│   └── mango_player/
│       ├── types.h                         # 通用类型定义 (唯一含 #ifdef 的文件)
│       ├── demuxer.h                       # FFmpeg 解复用器
│       ├── soft_decoder.h                  # FFmpeg 软解码器
│       ├── clock_sync.h                    # 音视频同步
│       ├── event_bridge.h                  # 事件桥接
│       ├── player_core.h                   # 播放器核心 (组合所有模块)
│       ├── interfaces/
│       │   ├── hw_decoder.h               # 硬件解码器接口
│       │   ├── texture_output.h           # 纹理输出接口
│       │   └── audio_output.h             # 音频输出接口
│       └── c_bridge/
│           └── mango_player_c.h           # C 桥接 API (供 Swift/ObjC 调用)
└── src/
    ├── demuxer.cpp                         # 100% 跨平台
    ├── soft_decoder.cpp                    # 100% 跨平台
    ├── clock_sync.cpp                      # 100% 跨平台
    ├── event_bridge.cpp                    # 100% 跨平台
    ├── player_core.cpp                     # 100% 跨平台
    └── c_bridge/
        └── mango_player_c.cpp             # C 桥接实现
```

## 设计原则

### 1. 接口隔离平台差异

```
┌─────────────────────────────────────────────────────────────┐
│                     PlayerCore (跨平台)                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐│
│  │  Demuxer    │ │ SoftDecoder │ │       ClockSync         ││
│  │  (FFmpeg)   │ │  (FFmpeg)   │ │   (纯数学逻辑)          ││
│  └─────────────┘ └─────────────┘ └─────────────────────────┘│
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              平台抽象接口 (依赖注入)                     ││
│  │  IHardwareDecoder  |  ITextureOutput  |  IAudioOutput   ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    平台特定实现                              │
├──────────────────┬──────────────────┬───────────────────────┤
│      macOS       │     Windows      │      iOS/Android      │
├──────────────────┼──────────────────┼───────────────────────┤
│ VideoToolbox     │ DXVA2Decoder     │ (可选) MediaCodec     │
│ Decoder          │                  │ VideoToolbox          │
├──────────────────┼──────────────────┼───────────────────────┤
│ MetalTexture     │ D3D11Texture     │ OpenGL ES / Metal     │
│ Output           │ Output           │ TextureOutput         │
├──────────────────┼──────────────────┼───────────────────────┤
│ AVAudioEngine    │ WASAPI           │ AudioTrack            │
│ Output           │ AudioOutput      │ AVAudioEngine         │
└──────────────────┴──────────────────┴───────────────────────┘
```

### 2. 代码复用比例

| 模块类型 | 代码占比 | 平台特定代码 |
|---------|---------|-------------|
| FFmpeg 操作 (demux/decode) | ~50% | 无 |
| 同步/状态管理 | ~20% | 无 |
| 事件桥接 | ~10% | 无 |
| 接口定义 | ~5% | 无 |
| 平台类型定义 | ~5% | 仅 `types.h` 中 #ifdef |
| **总跨平台代码** | **~90%** | — |

### 3. 平台集成方式

**macOS/iOS (Swift)**:
```swift
// 通过 C 桥接调用
let player = mango_player_create(hwDecoder, textureOutput, audioOutput)
mango_player_initialize(player, "video.mp4", nil, textureRegistry)
mango_player_play(player)
```

**Windows (C++)**:
```cpp
// 直接链接 C++ 库
auto player = std::make_unique<PlayerCore>(
    std::make_unique<DXVADecoder>(),
    std::make_unique<D3D11TextureOutput>(),
    std::make_unique<WASAPIAudioOutput>()
);
player->Initialize("video.mp4");
player->Play();
```

## 构建说明

### macOS 构建

```bash
cd native_core
mkdir build && cd build
cmake .. -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
make -j$(sysctl -n hw.ncpu)
```

生成 `libmango_player_native_core.a` 和 `libmango_player_c_bridge.a`

### Windows 构建

```bash
cd native_core
mkdir build && cd build
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release
```

### 集成到 Flutter 插件

**macOS `mango_player.podspec`**:
```ruby
s.vendored_libraries = 'libs/libmango_player_native_core.a', 'libs/libmango_player_c_bridge.a'
s.xcconfig = {
  'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/../native_core/include'
}
```

**Windows `CMakeLists.txt`**:
```cmake
add_subdirectory(../native_core ${CMAKE_BINARY_DIR}/native_core)
target_link_libraries(${PLUGIN_NAME} PRIVATE mango_player_native_core)
```

## 迁移计划

### 阶段 1: 保持现有功能 (当前)
- ✅ 创建 `native_core/` 架构
- ⏳ macOS 现有 ObjC 代码仍在运行

### 阶段 2: 平台实现接口
- [ ] macOS: 实现 `VideoToolboxDecoder`, `MetalTextureOutput`, `AVAudioEngineOutput`
- [ ] Windows: 实现 `DXVADecoder`, `D3D11TextureOutput`, `WASAPIAudioOutput`

### 阶段 3: 集成与切换
- [ ] macOS: `FFmpegPlayerManager.swift` 改用 C 桥接调用 `native_core`
- [ ] Windows: `FFmpegPlayerManager.cpp` 使用共享 `native_core`

### 阶段 4: 清理
- [ ] 删除 macOS 重复代码 (`FFmpegDemuxerObjC.m`, `ClockSync.swift` 等)
- [ ] 删除 Windows `src/core/native_core/` 旧目录

## API 参考

详见各头文件中的 Doxygen 注释：

- [demuxer.h](include/mango_player/demuxer.h) - FFmpeg 解复用
- [soft_decoder.h](include/mango_player/soft_decoder.h) - FFmpeg 软解码
- [clock_sync.h](include/mango_player/clock_sync.h) - AV 同步
- [player_core.h](include/mango_player/player_core.h) - 播放器核心
- [mango_player_c.h](include/mango_player/c_bridge/mango_player_c.h) - C 桥接 API
