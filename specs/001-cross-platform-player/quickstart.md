# MangoPlayer 快速开始

**目标**: 在 10 分钟内集成 MangoPlayer 并播放第一个视频

---

## 1. 安装

### 添加依赖

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  mango_player: ^1.0.0
```

运行安装命令：

```bash
flutter pub get
```

---

## 2. 平台配置

### Android

在 `android/app/build.gradle` 中设置最低 SDK 版本：

```gradle
android {
    defaultConfig {
        minSdkVersion 24  // Android 7.0+
    }
}
```

### iOS

在 `ios/Podfile` 中设置部署目标：

```ruby
platform :ios, '14.0'
```

### Windows

确保安装了 Visual Studio 2019+ 和 Windows 10 SDK (1809+)。

### macOS

在 `macos/Runner/Info.plist` 中添加网络权限（如果播放网络视频）：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## 3. 基础播放 (3 步集成)

### 步骤 1: 创建 Controller

```dart
import 'package:flutter/material.dart';
import 'package:mango_player/mango_player.dart';

class VideoPlayerPage extends StatefulWidget {
  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late MangoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    
    // 创建播放器 Controller
    _controller = MangoPlayerController();
    
    // 初始化并加载视频
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _controller.initialize(
        MediaSource.network('https://example.com/video.mp4'),
      );
      
      // 自动播放
      await _controller.play();
    } catch (e) {
      print('初始化失败: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 见步骤 2
  }
}
```

### 步骤 2: 添加视频 Widget

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('MangoPlayer Demo')),
    body: Center(
      child: _controller.state == PlayerState.idle
          ? CircularProgressIndicator()
          : AspectRatio(
              aspectRatio: 16 / 9,
              child: MangoPlayerView(controller: _controller),
            ),
    ),
  );
}
```

### 步骤 3: 添加播放控制 (可选)

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('MangoPlayer Demo')),
    body: Column(
      children: [
        // 视频画面
        Expanded(
          child: MangoPlayerView(controller: _controller),
        ),
        
        // 播放控制
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_controller.state == PlayerState.playing
                  ? Icons.pause
                  : Icons.play_arrow),
              onPressed: () {
                if (_controller.state == PlayerState.playing) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              },
            ),
            
            // 进度条
            Expanded(
              child: StreamBuilder<PlaybackEvent>(
                stream: _controller.eventStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Slider(value: 0);
                  
                  final event = snapshot.data!;
                  final position = event.position.inMilliseconds.toDouble();
                  final duration = event.duration.inMilliseconds.toDouble();
                  
                  return Slider(
                    value: position,
                    max: duration,
                    onChanged: (value) {
                      _controller.seekTo(Duration(milliseconds: value.toInt()));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

**完成！** 现在运行应用，视频应该开始播放。

---

## 4. 更多示例

### 播放本地文件

```dart
await _controller.initialize(
  MediaSource.file('/path/to/video.mp4'),
);
```

### 播放 HLS 流

```dart
await _controller.initialize(
  MediaSource.network('https://example.com/stream.m3u8'),
);
```

### 播放 RTMP 直播

```dart
await _controller.initialize(
  MediaSource.network('rtmp://live.example.com/stream'),
);
```

### 自定义配置

```dart
_controller = MangoPlayerController(
  config: PlayerConfig(
    autoPlay: true,              // 自动播放
    looping: true,               // 循环播放
    preferHardwareDecoding: true, // 优先硬件解码
  ),
);
```

### 监听播放事件

```dart
_controller.eventStream.listen((event) {
  print('Position: ${event.position}');
  print('Duration: ${event.duration}');
  print('Buffer: ${event.bufferPercentage}');
});

_controller.stateStream.listen((state) {
  print('State changed: $state');
});

_controller.errorStream.listen((error) {
  print('Error: ${error.code} - ${error.message}');
});
```

### 控制音量和速度

```dart
// 设置音量 (0.0 ~ 1.0)
await _controller.setVolume(0.5);

// 设置播放速度 (0.5x ~ 2.0x)
await _controller.setPlaybackSpeed(1.5);
```

---

## 5. 使用默认播放控制 UI

如果不想自己实现控制 UI，可以使用内置的默认控制：

```dart
MangoPlayerView(
  controller: _controller,
  showControls: true,  // 显示默认控制 UI
)
```

默认控制 UI 包含：
- 播放/暂停按钮
- 进度条
- 时间显示
- 音量控制
- 全屏按钮

---

## 6. 完整示例代码

```dart
import 'package:flutter/material.dart';
import 'package:mango_player/mango_player.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VideoPlayerPage(),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late MangoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MangoPlayerController(
      config: PlayerConfig(autoPlay: true),
    );
    
    _controller.initialize(
      MediaSource.network('https://example.com/video.mp4'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MangoPlayer')),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: MangoPlayerView(
            controller: _controller,
            showControls: true,  // 使用默认控制 UI
          ),
        ),
      ),
    );
  }
}
```

---

## 7. 常见问题

### Q: 视频无法播放，显示 "source_not_found" 错误？
**A**: 检查 URL 是否正确，网络权限是否配置。Android 需要在 `AndroidManifest.xml` 添加 `INTERNET` 权限。

### Q: 如何启用硬件解码？
**A**: 硬件解码默认启用。可通过 `PlayerConfig.preferHardwareDecoding` 控制。

### Q: 支持哪些视频格式？
**A**: 支持 MP4, MKV, AVI, MOV, WebM 等常见格式，编码支持 H.264, H.265, VP8, VP9。

### Q: 如何处理播放错误？
**A**: 监听 `controller.errorStream`，根据 `PlayerErrorCode` 进行相应处理。

### Q: 可以同时播放多个视频吗？
**A**: 可以，但建议同时运行 2-3 个实例，更多实例可能影响性能。

---

## 8. 下一步

- 查看 [API 文档](https://pub.dev/documentation/mango_player) 了解完整 API
- 浏览 [示例应用](../example) 学习高级用法
- 阅读 [架构文档](architecture.md) 了解扩展机制

---

**祝您使用愉快！** 🎉

如有问题，请访问 [GitHub Issues](https://github.com/your-repo/mango_player/issues)。
