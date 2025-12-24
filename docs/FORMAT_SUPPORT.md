# MangoPlayer 格式支持文档

**版本**: 1.0.0
**更新日期**: 2024-12

本文档记录 MangoPlayer 支持的媒体格式、编码和协议。

---

## 视频容器格式

MangoPlayer 基于 ijkplayer/FFmpeg 内核，支持以下视频容器格式：

| 格式 | 扩展名 | 支持状态 | 备注 |
|------|--------|----------|------|
| MP4 | `.mp4`, `.m4v` | ✅ 完全支持 | 最常用格式，推荐使用 |
| MKV | `.mkv` | ✅ 完全支持 | 支持多音轨/字幕 |
| AVI | `.avi` | ✅ 完全支持 | 旧格式，兼容性好 |
| MOV | `.mov` | ✅ 完全支持 | Apple QuickTime 格式 |
| WebM | `.webm` | ✅ 完全支持 | VP8/VP9 + Vorbis/Opus |
| FLV | `.flv` | ✅ 完全支持 | Flash 视频格式 |
| TS | `.ts`, `.m2ts` | ✅ 完全支持 | MPEG 传输流 |
| 3GP | `.3gp`, `.3g2` | ✅ 完全支持 | 移动端格式 |
| WMV | `.wmv`, `.asf` | ⚠️ 部分支持 | 需要特定编解码器 |

---

## 视频编码

| 编码 | 支持状态 | 硬解支持 | 备注 |
|------|----------|----------|------|
| H.264/AVC | ✅ 完全支持 | ✅ 全平台 | 最广泛使用的编码 |
| H.265/HEVC | ✅ 完全支持 | ✅ 部分平台 | Android 5.0+, iOS 11+ |
| VP8 | ✅ 完全支持 | ⚠️ 软解为主 | WebM 常用编码 |
| VP9 | ✅ 完全支持 | ⚠️ 部分平台 | WebM 高效编码 |
| AV1 | ⚠️ 实验性 | ⚠️ 新设备 | 需要 FFmpeg 5.0+ |
| MPEG-4 | ✅ 完全支持 | ✅ 全平台 | 旧格式 |
| MPEG-2 | ✅ 完全支持 | ✅ 部分平台 | DVD/广播 |
| MJPEG | ✅ 完全支持 | ❌ 软解 | Motion JPEG |

### 硬件解码平台支持

| 平台 | 硬解技术 | H.264 | H.265 | VP9 |
|------|----------|-------|-------|-----|
| Android | MediaCodec | ✅ | ✅ API 21+ | ✅ API 24+ |
| iOS | VideoToolbox | ✅ | ✅ iOS 11+ | ❌ |
| macOS | VideoToolbox | ✅ | ✅ 10.13+ | ❌ |
| Windows | DXVA2 | ✅ | ✅ Win10+ | ⚠️ 部分 GPU |

---

## 音频格式

| 格式 | 扩展名 | 支持状态 | 备注 |
|------|--------|----------|------|
| MP3 | `.mp3` | ✅ 完全支持 | 最常用音频格式 |
| AAC | `.aac`, `.m4a` | ✅ 完全支持 | 高质量音频 |
| FLAC | `.flac` | ✅ 完全支持 | 无损音频 |
| WAV | `.wav` | ✅ 完全支持 | PCM 无压缩 |
| OGG Vorbis | `.ogg`, `.oga` | ✅ 完全支持 | 开源格式 |
| Opus | `.opus` | ✅ 完全支持 | 低延迟编码 |
| WMA | `.wma` | ⚠️ 部分支持 | Windows Media Audio |
| AC3 | `.ac3` | ✅ 完全支持 | Dolby Digital |
| DTS | `.dts` | ⚠️ 部分支持 | 需要解码器 |

---

## 流媒体协议

| 协议 | 支持状态 | 备注 |
|------|----------|------|
| HTTP/HTTPS | ✅ 完全支持 | 渐进式下载 |
| HLS | ✅ 完全支持 | `.m3u8` 自适应流 |
| RTMP | ✅ 完全支持 | 直播推流/拉流 |
| RTSP | ✅ 完全支持 | 监控/摄像头 |
| DASH | ⚠️ 部分支持 | 需要额外配置 |
| SRT | ⚠️ 实验性 | 需要 FFmpeg 编译选项 |

---

## 字幕格式

| 格式 | 扩展名 | 支持状态 | 备注 |
|------|--------|----------|------|
| SRT | `.srt` | ✅ 完全支持 | 最常用格式 |
| ASS/SSA | `.ass`, `.ssa` | ✅ 完全支持 | 高级样式 |
| WebVTT | `.vtt` | ✅ 完全支持 | Web 标准 |
| TTML | `.ttml` | ⚠️ 部分支持 | XML 格式 |
| PGS | 内嵌 | ⚠️ 部分支持 | 蓝光字幕 |

---

## 格式检测与错误处理

### 不支持格式的错误代码

当遇到不支持的格式时，MangoPlayer 会返回清晰的错误信息：

```dart
// 错误代码
enum PlayerErrorCode {
  sourceNotSupported,     // 不支持的媒体格式
  codecNotSupported,      // 不支持的编解码器
  // ...
}

// 错误处理示例
controller.errorStream.listen((error) {
  switch (error.code) {
    case PlayerErrorCode.sourceNotSupported:
      print('不支持的格式: ${error.message}');
      break;
    case PlayerErrorCode.codecNotSupported:
      print('不支持的编码: ${error.message}');
      // 提示用户转码或使用其他格式
      break;
    default:
      print('播放错误: ${error.message}');
  }
});
```

### 格式检测方法

```dart
// 检查格式是否支持（静态方法）
bool isSupported = await MangoPlayer.isFormatSupported('video/mp4');
bool isCodecSupported = await MangoPlayer.isCodecSupported('h264');

// 获取支持的格式列表
List<String> supportedFormats = await MangoPlayer.getSupportedFormats();
```

---

## 推荐配置

### 最佳兼容性

为了获得最佳的跨平台兼容性，推荐使用以下配置：

**视频**:
- 容器: MP4
- 编码: H.264 (Baseline/Main Profile)
- 分辨率: 1920x1080 或更低
- 帧率: 30fps 或 60fps

**音频**:
- 编码: AAC-LC
- 采样率: 44100Hz 或 48000Hz
- 声道: 立体声 (2 声道)

### 高质量配置

**视频**:
- 容器: MP4 或 MKV
- 编码: H.265/HEVC (Main Profile)
- 分辨率: 4K (3840x2160)
- 帧率: 60fps

**音频**:
- 编码: AAC-LC 或 FLAC
- 采样率: 48000Hz
- 声道: 5.1 环绕声

---

## 常见问题

### Q: 为什么某些 MKV 文件无法播放？

A: MKV 是容器格式，内部可能包含不同的编解码器。请检查视频和音频编码是否在支持列表中。

### Q: 如何播放加密的 HLS 流？

A: MangoPlayer 支持 AES-128 加密的 HLS 流。确保在 headers 中包含正确的认证信息。

### Q: 为什么硬件解码没有生效？

A: 硬件解码依赖设备支持。可以通过性能监控接口检查当前的解码模式：
```dart
controller.performanceStream.listen((metrics) {
  print('解码模式: ${metrics.decoderType}'); // "hardware" 或 "software"
});
```
