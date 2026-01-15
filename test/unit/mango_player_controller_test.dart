import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/mango_player.dart';
import 'package:mango_player/src/platform/mango_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMangoPlayerPlatform extends MangoPlayerPlatform
    with MockPlatformInterfaceMixin {
  bool _initialized = false;
  bool _playing = false;
  double _volume = 1.0;
  double _speed = 1.0;
  Duration _position = Duration.zero;
  final Duration _duration = const Duration(seconds: 60);
  final StreamController<PlaybackEvent> _eventController = 
      StreamController<PlaybackEvent>.broadcast();

  @override
  Future<Duration?> initialize(MediaSource source, {int? textureId}) async {
    _initialized = true;
    return _duration;
  }

  @override
  Future<void> play() async {
    _playing = true;
  }

  @override
  Future<void> pause() async {
    _playing = false;
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _position = Duration.zero;
  }

  @override
  Future<Duration?> seekTo(Duration position) async {
    _position = position;
    return _position;
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _speed = speed;
  }

  @override
  Future<Duration?> getPosition() async {
    return _position;
  }

  @override
  Future<Duration?> getDuration() async {
    return _duration;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    _playing = false;
    await _eventController.close();
  }

  @override
  Future<int?> registerTexture() async {
    return 1;
  }

  @override
  Future<void> unregisterTexture(int textureId) async {}

  @override
  Stream<PlaybackEvent> get eventStream => _eventController.stream;

  @override
  Future<Map<String, dynamic>?> getPerformanceMetrics() async {
    return {
      'frameRate': 30.0,
      'droppedFrames': 0,
      'decodeTimeMs': 5.0,
      'renderTimeMs': 2.0,
    };
  }

  // Test helpers
  bool get isInitialized => _initialized;
  bool get isPlaying => _playing;
  double get volume => _volume;
  double get speed => _speed;
}

void main() {
  group('MangoPlayerController', () {
    late MockMangoPlayerPlatform mockPlatform;
    late MangoPlayerPlatform originalPlatform;

    setUp(() {
      originalPlatform = MangoPlayerPlatform.instance;
      mockPlatform = MockMangoPlayerPlatform();
      MangoPlayerPlatform.instance = mockPlatform;
    });

    tearDown(() {
      MangoPlayerPlatform.instance = originalPlatform;
    });

    group('初始化', () {
      test('创建带默认配置的 controller', () {
        final controller = MangoPlayerController();
        
        expect(controller.state, PlayerState.idle);
        expect(controller.config, isNotNull);
      });

      test('创建带自定义配置的 controller', () {
        final controller = MangoPlayerController(
          config: const PlayerConfig(autoPlay: true),
        );

        expect(controller.config.autoPlay, true);
      });
    });

    group('生命周期', () {
      test('initialize 设置状态为 ready', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );

        expect(controller.state, PlayerState.ready);
        expect(mockPlatform.isInitialized, true);
      });

      test('play 设置状态为 playing', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );
        await controller.play();

        expect(controller.state, PlayerState.playing);
        expect(mockPlatform.isPlaying, true);
      });

      test('pause 设置状态为 paused', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );
        await controller.play();
        await controller.pause();

        expect(controller.state, PlayerState.paused);
        expect(mockPlatform.isPlaying, false);
      });

      test('stop 设置状态为 idle', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );
        await controller.play();
        await controller.stop();

        expect(controller.state, PlayerState.idle);
      });
    });

    group('控制', () {
      test('seekTo 更新位置', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );
        
        await controller.seekTo(const Duration(seconds: 30));
        
        expect(controller.position.inSeconds, 30);
      });

      test('setVolume 设置音量', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );
        
        await controller.setVolume(0.5);
        
        expect(mockPlatform.volume, 0.5);
      });

      test('setPlaybackSpeed 设置播放速度', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );
        
        await controller.setPlaybackSpeed(2.0);
        
        expect(mockPlatform.speed, 2.0);
      });
    });

    group('事件流', () {
      test('stateStream 发送状态变化', () async {
        final controller = MangoPlayerController();
        final states = <PlayerState>[];
        final subscription = controller.stateStream.listen(states.add);

        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );

        await Future.delayed(const Duration(milliseconds: 100));
        await subscription.cancel();

        expect(states, contains(PlayerState.initializing));
        expect(states, contains(PlayerState.ready));
      });

      test('errorStream 可以监听错误', () {
        final controller = MangoPlayerController();
        expect(controller.errorStream, isA<Stream<PlayerError>>());
      });

      test('eventStream 可以监听播放事件', () {
        final controller = MangoPlayerController();
        expect(controller.eventStream, isA<Stream<PlaybackEvent>>());
      });
    });

    group('属性', () {
      test('position 初始为 zero', () {
        final controller = MangoPlayerController();
        expect(controller.position, Duration.zero);
      });

      test('duration 初始为 zero', () {
        final controller = MangoPlayerController();
        expect(controller.duration, Duration.zero);
      });

      test('textureId 初始为 null', () {
        final controller = MangoPlayerController();
        expect(controller.textureId, isNull);
      });

      test('textureId 初始化后有值', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );

        expect(controller.textureId, isNotNull);
      });
    });

    group('性能监控', () {
      test('enablePerformanceMonitoring 启用监控', () {
        final controller = MangoPlayerController();
        controller.enablePerformanceMonitoring();
        
        expect(controller.performanceStream, isA<Stream<PerformanceMetrics>>());
      });

      test('disablePerformanceMonitoring 禁用监控', () {
        final controller = MangoPlayerController();
        controller.enablePerformanceMonitoring();
        controller.disablePerformanceMonitoring();
        
        // 不应抛出异常
        expect(true, true);
      });

      test('getPerformanceMetrics 返回指标', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );
        
        final metrics = await controller.getPerformanceMetrics();
        
        expect(metrics, isA<PerformanceMetrics>());
      });

      test('getPerformanceSummary 返回摘要', () {
        final controller = MangoPlayerController();
        final summary = controller.getPerformanceSummary();
        
        expect(summary, isA<PerformanceSummary>());
      });
    });

    group('dispose', () {
      test('dispose 清理资源', () async {
        final controller = MangoPlayerController();
        await controller.initialize(
          MediaSource.network('https://example.com/video.mp4'),
        );

        await controller.dispose();
        
        expect(mockPlatform.isInitialized, false);
      });
    });
  });

  group('PlayerConfig', () {
    test('默认配置', () {
      const config = PlayerConfig();
      
      expect(config.autoPlay, false);
      expect(config.looping, false);
    });

    test('自定义配置', () {
      const config = PlayerConfig(
        autoPlay: true,
        looping: true,
      );
      
      expect(config.autoPlay, true);
      expect(config.looping, true);
    });
  });
}
