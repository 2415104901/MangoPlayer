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
  }

  @override
  Future<int?> registerTexture() async {
    return 1;
  }

  @override
  Future<void> unregisterTexture(int textureId) async {}

  @override
  Stream<PlaybackEvent> get eventStream => Stream.empty();

  // Test helpers
  bool get isInitialized => _initialized;
  bool get isPlaying => _playing;
  double get volume => _volume;
  double get speed => _speed;
}

void main() {
  group('MangoPlayerPlatform', () {
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

    test('instance 可以设置和获取', () {
      expect(MangoPlayerPlatform.instance, same(mockPlatform));
    });

    test('initialize 返回 duration', () async {
      final duration = await mockPlatform.initialize(
        MediaSource.network('https://example.com/video.mp4'),
      );

      expect(duration?.inSeconds, 60);
      expect(mockPlatform.isInitialized, true);
    });

    test('play 开始播放', () async {
      await mockPlatform.play();
      expect(mockPlatform.isPlaying, true);
    });

    test('pause 暂停播放', () async {
      await mockPlatform.play();
      await mockPlatform.pause();
      expect(mockPlatform.isPlaying, false);
    });

    test('stop 停止播放', () async {
      await mockPlatform.play();
      await mockPlatform.stop();
      expect(mockPlatform.isPlaying, false);
    });

    test('seekTo 跳转位置', () async {
      final position = await mockPlatform.seekTo(const Duration(seconds: 30));
      expect(position?.inSeconds, 30);
    });

    test('setVolume 设置音量', () async {
      await mockPlatform.setVolume(0.5);
      expect(mockPlatform.volume, 0.5);
    });

    test('setPlaybackSpeed 设置播放速度', () async {
      await mockPlatform.setPlaybackSpeed(2.0);
      expect(mockPlatform.speed, 2.0);
    });

    test('registerTexture 返回 textureId', () async {
      final textureId = await mockPlatform.registerTexture();
      expect(textureId, isNotNull);
      expect(textureId, greaterThan(0));
    });
  });

  group('MangoPlayerController 与 Platform 集成', () {
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

    test('Controller initialize 调用 platform', () async {
      final controller = MangoPlayerController();
      await controller.initialize(
        MediaSource.network('https://example.com/video.mp4'),
      );

      expect(mockPlatform.isInitialized, true);
      expect(controller.state, PlayerState.ready);
    });

    test('Controller play 调用 platform', () async {
      final controller = MangoPlayerController();
      await controller.initialize(
        MediaSource.network('https://example.com/video.mp4'),
      );
      await controller.play();

      expect(mockPlatform.isPlaying, true);
      expect(controller.state, PlayerState.playing);
    });

    test('Controller pause 调用 platform', () async {
      final controller = MangoPlayerController();
      await controller.initialize(
        MediaSource.network('https://example.com/video.mp4'),
      );
      await controller.play();
      await controller.pause();

      expect(mockPlatform.isPlaying, false);
      expect(controller.state, PlayerState.paused);
    });
  });
}
