# MangoPlayer 流媒体协议支持文档

**版本**: 1.0.0
**更新日期**: 2024-12

本文档记录 MangoPlayer 对流媒体协议的支持情况和配置指南。

---

## HLS (HTTP Live Streaming)

### 支持状态: ✅ 完全支持

HLS 是 Apple 开发的自适应比特率流媒体协议，广泛用于点播和直播。

### 功能特性

- ✅ VOD (点播) 播放
- ✅ Live (直播) 播放
- ✅ 自适应比特率切换
- ✅ AES-128 加密
- ✅ 多音轨切换
- ✅ 多字幕轨切换
- ⚠️ fMP4 段（需要较新版本 FFmpeg）

### 使用示例

```dart
// 播放 HLS 流
await controller.initialize(
  MediaSource.network('https://example.com/live/stream.m3u8'),
);

// 带认证的 HLS 流
await controller.initialize(
  MediaSource.network(
    'https://example.com/protected/stream.m3u8',
    headers: {
      'Authorization': 'Bearer your_token',
    },
  ),
);
```

### 配置选项

```dart
// 在 PlayerConfig 中配置 HLS 参数
final config = PlayerConfig(
  hlsMaxBufferDuration: Duration(seconds: 30),
  hlsMinBufferDuration: Duration(seconds: 10),
  preferredBitrate: 2000000, // 2 Mbps
);

final controller = MangoPlayerController(config: config);
```

---

## RTMP (Real-Time Messaging Protocol)

### 支持状态: ✅ 完全支持

RTMP 是 Adobe 开发的实时消息传输协议，常用于直播推流和拉流。

### 功能特性

- ✅ RTMP 拉流播放
- ✅ RTMPS (RTMP over TLS)
- ✅ 低延迟播放
- ⚠️ RTMPE (加密) - 部分支持
- ❌ RTMP 推流 (本库仅支持播放)

### 使用示例

```dart
// 播放 RTMP 直播流
await controller.initialize(
  MediaSource.network('rtmp://live.example.com/app/stream_key'),
);

// RTMPS 安全连接
await controller.initialize(
  MediaSource.network('rtmps://live.example.com/app/stream_key'),
);
```

### 延迟优化配置

```dart
// 低延迟配置
final config = PlayerConfig(
  bufferDuration: Duration(milliseconds: 500),
  maxBufferDuration: Duration(seconds: 2),
  enableLowLatency: true,
);
```

---

## RTSP (Real-Time Streaming Protocol)

### 支持状态: ✅ 完全支持

RTSP 常用于 IP 摄像头、监控系统和专业视频设备。

### 功能特性

- ✅ RTSP over UDP
- ✅ RTSP over TCP
- ✅ 基本认证 (Basic Auth)
- ✅ 摘要认证 (Digest Auth)
- ⚠️ RTSPS (RTSP over TLS) - 部分支持

### 使用示例

```dart
// 播放 RTSP 流（摄像头）
await controller.initialize(
  MediaSource.network('rtsp://camera.local:554/stream1'),
);

// 带认证的 RTSP 流
await controller.initialize(
  MediaSource.network(
    'rtsp://admin:password@camera.local:554/stream1',
  ),
);

// 或使用 headers（推荐）
await controller.initialize(
  MediaSource.network(
    'rtsp://camera.local:554/stream1',
    headers: {
      'Authorization': 'Basic base64_encoded_credentials',
    },
  ),
);
```

### 传输模式配置

```dart
// 强制使用 TCP 传输（更稳定，适用于防火墙环境）
final config = PlayerConfig(
  rtspTransport: RtspTransport.tcp,
);
```

---

## 自动重连机制

### 功能概述

MangoPlayer 内置了网络中断时的自动重连机制，确保流媒体播放的稳定性。

### 配置选项

```dart
final config = PlayerConfig(
  // 启用自动重连
  enableAutoReconnect: true,
  
  // 最大重连次数
  maxReconnectAttempts: 5,
  
  // 重连间隔（指数退避）
  reconnectDelay: Duration(seconds: 2),
  
  // 最大重连间隔
  maxReconnectDelay: Duration(seconds: 30),
);
```

### 重连事件监听

```dart
// 监听重连事件
controller.eventStream.listen((event) {
  if (event is ReconnectingEvent) {
    print('正在重连... 尝试次数: ${event.attempt}/${event.maxAttempts}');
  } else if (event is ReconnectedEvent) {
    print('重连成功！');
  } else if (event is ReconnectFailedEvent) {
    print('重连失败: ${event.reason}');
  }
});

// 监听错误以处理永久性连接失败
controller.errorStream.listen((error) {
  if (error.code == PlayerErrorCode.networkError) {
    // 显示网络错误提示
    showNetworkErrorDialog();
  }
});
```

### 手动重连

```dart
// 手动触发重连
await controller.reconnect();

// 或者重新初始化
await controller.stop();
await controller.initialize(originalSource);
await controller.play();
```

---

## 网络状态监控

### 缓冲状态

```dart
controller.eventStream.listen((event) {
  print('缓冲进度: ${(event.bufferPercentage * 100).toStringAsFixed(1)}%');
  print('已缓冲位置: ${event.bufferedPosition}');
  
  if (event.isBuffering) {
    showBufferingIndicator();
  } else {
    hideBufferingIndicator();
  }
});
```

### 网络带宽检测

```dart
// 通过性能指标获取网络信息
controller.performanceStream?.listen((metrics) {
  print('当前比特率: ${metrics.currentBitrate}');
  print('下载速度: ${metrics.downloadSpeed}');
  print('缓冲健康度: ${metrics.bufferHealth}');
});
```

---

## 常见问题

### Q: HLS 直播延迟很高怎么办？

A: 可以通过减少缓冲区大小来降低延迟：
```dart
final config = PlayerConfig(
  hlsMinBufferDuration: Duration(seconds: 2),
  hlsMaxBufferDuration: Duration(seconds: 5),
);
```

### Q: RTSP 流无法播放？

A: 常见原因和解决方案：
1. **防火墙问题**: 尝试使用 TCP 传输模式
2. **认证失败**: 检查用户名密码
3. **编码不支持**: 确认 H.264/H.265 编码

### Q: 如何处理网络切换（WiFi ↔ 移动数据）？

A: 启用自动重连并监听网络状态：
```dart
final config = PlayerConfig(
  enableAutoReconnect: true,
  maxReconnectAttempts: 10,
);

// 可选：监听系统网络状态变化并主动重连
connectivity.onConnectivityChanged.listen((result) {
  if (result != ConnectivityResult.none) {
    controller.reconnect();
  }
});
```

---

## 性能建议

### 直播流优化

1. **使用 HLS 低延迟模式** (如果服务端支持)
2. **减小缓冲区** 以降低延迟
3. **禁用自适应比特率** 如果网络稳定

### 点播流优化

1. **增大缓冲区** 以获得更流畅的体验
2. **启用预加载** 下一个视频片段
3. **使用 CDN** 加速分发
