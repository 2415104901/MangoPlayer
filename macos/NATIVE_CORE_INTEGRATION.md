# macOS Native Core Integration

This document describes the macOS architecture refactoring to use the shared `native_core` C++ library.

## Completed Tasks

### T-ARCH-007: VideoToolboxDecoder Implementation
- **File**: `macos/Classes/NativeCore/VideoToolboxDecoder.h/mm`
- **Description**: Implements `IHardwareDecoder` interface using Apple VideoToolbox framework
- **Features**:
  - H.264 and H.265/HEVC hardware decoding
  - Outputs CVPixelBuffer for zero-copy rendering
  - Async decompression with callback handling

### T-ARCH-008: MetalTextureOutput Implementation
- **File**: `macos/Classes/NativeCore/MetalTextureOutput.h/mm`
- **Description**: Implements `ITextureOutput` interface using Metal framework
- **Features**:
  - Creates CVPixelBuffer textures compatible with Metal
  - Handles both hardware-decoded frames (CVPixelBuffer) and software-decoded frames
  - Integrates with Flutter TextureRegistry

### T-ARCH-009: AVAudioEngineOutput Implementation
- **File**: `macos/Classes/NativeCore/AVAudioEngineOutput.h/mm`
- **Description**: Implements `IAudioOutput` interface using AVAudioEngine
- **Features**:
  - PCM audio playback with AVAudioPlayerNode
  - Volume and mute control
  - Buffer management for AV sync

### T-ARCH-017: Updated mango_player.podspec
- **Changes**:
  - Added `.mm` files to source_files pattern (for Objective-C++)
  - Linked `native_core` static libraries (libmango_player_native_core.a, libmango_player_c_bridge.a)
  - Added native_core include paths to HEADER_SEARCH_PATHS
  - Added NativeCore headers to public headers

### Bridge Implementation
- **File**: `macos/Classes/NativeCore/NativeCorePlayerBridge.swift`
- **Description**: Swift wrapper for the native_core C bridge
- **Features**:
  - Manages platform-specific implementation lifecycle
  - Provides Swift-friendly API over C bridge functions
  - Demonstrates how to use the C bridge from Swift

### Updated BridgingHeader.h
- Added imports for:
  - `mango_player/c_bridge/mango_player_c.h`
  - VideoToolboxDecoder.h
  - MetalTextureOutput.h
  - AVAudioEngineOutput.h

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Dart Layer                        │
│                   (MangoPlayerController)                    │
└────────────────────────┬────────────────────────────────────┘
                         │ MethodChannel
┌────────────────────────▼────────────────────────────────────┐
│                  Swift Platform Layer                        │
│              (MethodChannelHandler.swift)                    │
│                          │                                   │
│              ┌───────────▼──────────┐                       │
│              │NativeCorePlayerBridge│                       │
│              │      (Swift)         │                       │
│              └───────────┬──────────┘                       │
└──────────────────────────┼──────────────────────────────────┘
                           │ C Bridge API
┌──────────────────────────▼──────────────────────────────────┐
│                    Native Core C++ Layer                     │
│                  (mango_player_c.h/.cpp)                    │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │PlayerCore    │  │Demuxer       │  │SoftDecoder      │  │
│  │(player_core) │→ │(demuxer)     │→ │(soft_decoder)   │  │
│  └──────┬───────┘  └──────────────┘  └─────────────────┘  │
│         │                                                    │
│         │ Injects interfaces                                │
│         ▼                                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Platform Abstraction Interfaces             │  │
│  │  - IHardwareDecoder                                  │  │
│  │  - ITextureOutput                                    │  │
│  │  - IAudioOutput                                      │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────┬───────────────────────────────────┘
                           │ Implemented by
┌──────────────────────────▼───────────────────────────────────┐
│              macOS Platform Implementations                  │
│                 (Objective-C++/.mm files)                    │
│                                                              │
│  ┌─────────────────────┐  ┌──────────────────────────┐     │
│  │VideoToolboxDecoder  │  │MetalTextureOutput        │     │
│  │(VideoToolbox API)   │  │(Metal+CVPixelBuffer)     │     │
│  └─────────────────────┘  └──────────────────────────┘     │
│                                                              │
│  ┌─────────────────────┐                                    │
│  │AVAudioEngineOutput  │                                    │
│  │(AVAudioEngine API)  │                                    │
│  └─────────────────────┘                                    │
└──────────────────────────────────────────────────────────────┘
```

## Building

1. Build native_core first:
```bash
cd native_core
mkdir -p build && cd build
cmake .. -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
make -j4
```

2. Build the Flutter plugin:
```bash
cd ../..
flutter build macos
```

## Next Steps (T-ARCH-010)

Refactor `FFmpegPlayerManager.swift` to use `NativeCorePlayerBridge` instead of direct implementations. This involves:

1. Replace direct FFmpeg calls with C bridge calls
2. Remove duplicate code (demuxer, clock sync, decoder)
3. Use NativeCorePlayerBridge for all playback operations

## Next Steps (T-ARCH-015)

Delete redundant macOS code:
- `macos/Classes/core/FFmpegDemuxerObjC.m/h` (replaced by native_core demuxer)
- `macos/Classes/core/ClockSync.swift` (replaced by native_core clock_sync)
- Other duplicate implementations

## Testing

Currently, the old implementation (FFmpegPlayerManager) is still in use. To test the new implementation:

1. Update MethodChannelHandler to use NativeCorePlayerBridge
2. Run integration tests
3. Verify audio/video playback works
4. Check for memory leaks

## Notes

- The C bridge API is defined in `native_core/include/mango_player/c_bridge/mango_player_c.h`
- Platform implementations are in `macos/Classes/NativeCore/`
- Swift accesses C bridge through BridgingHeader.h
- The podspec links static libraries from `native_core/build/`
