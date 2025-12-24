import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/src/providers/decoder_provider.dart';
import 'package:mango_player/src/providers/renderer_provider.dart';

/// 测试用的具体 RendererProvider 实现
class TestRendererProvider implements RendererProvider {
  bool _initialized = false;
  int _textureId = -1;
  int _width = 0;
  int _height = 0;
  int _renderCount = 0;
  VideoFrame? _lastFrame;

  @override
  Future<void> initialize(int width, int height) async {
    _width = width;
    _height = height;
    _textureId = 1;
    _initialized = true;
  }

  @override
  int get textureId => _textureId;

  @override
  Future<void> render(VideoFrame frame) async {
    if (!_initialized) {
      throw StateError('Renderer not initialized');
    }
    _lastFrame = frame;
    _renderCount++;
  }

  @override
  Future<void> resize(int width, int height) async {
    if (!_initialized) {
      throw StateError('Renderer not initialized');
    }
    _width = width;
    _height = height;
  }

  @override
  Future<void> release() async {
    _initialized = false;
    _textureId = -1;
    _width = 0;
    _height = 0;
    _renderCount = 0;
    _lastFrame = null;
  }

  // Test helpers
  bool get isInitialized => _initialized;
  int get width => _width;
  int get height => _height;
  int get renderCount => _renderCount;
  VideoFrame? get lastFrame => _lastFrame;
}

void main() {
  group('RendererProvider', () {
    late TestRendererProvider provider;

    setUp(() {
      provider = TestRendererProvider();
    });

    tearDown(() async {
      try {
        await provider.release();
      } catch (_) {}
    });

    group('初始化', () {
      test('initialize 初始化渲染器', () async {
        await provider.initialize(1920, 1080);

        expect(provider.isInitialized, true);
        expect(provider.width, 1920);
        expect(provider.height, 1080);
      });

      test('initialize 设置 textureId', () async {
        expect(provider.textureId, -1);

        await provider.initialize(1280, 720);

        expect(provider.textureId, greaterThan(0));
      });

      test('initialize 支持不同分辨率', () async {
        await provider.initialize(3840, 2160);

        expect(provider.width, 3840);
        expect(provider.height, 2160);
      });
    });

    group('渲染', () {
      test('render 渲染视频帧', () async {
        await provider.initialize(1920, 1080);

        final frame = VideoFrame(
          data: Uint8List.fromList([1, 2, 3]),
          width: 1920,
          height: 1080,
          format: 0,
          timestamp: const Duration(milliseconds: 33),
        );

        await provider.render(frame);

        expect(provider.renderCount, 1);
        expect(provider.lastFrame, isNotNull);
      });

      test('render 未初始化时抛出异常', () async {
        final frame = VideoFrame(
          width: 1920,
          height: 1080,
          format: 0,
          timestamp: Duration.zero,
        );

        expect(
          () async => await provider.render(frame),
          throwsA(isA<StateError>()),
        );
      });

      test('render 多次调用累计计数', () async {
        await provider.initialize(1920, 1080);

        final frame = VideoFrame(
          width: 1920,
          height: 1080,
          format: 0,
          timestamp: Duration.zero,
        );

        await provider.render(frame);
        await provider.render(frame);
        await provider.render(frame);

        expect(provider.renderCount, 3);
      });
    });

    group('resize', () {
      test('resize 调整渲染尺寸', () async {
        await provider.initialize(1920, 1080);

        await provider.resize(1280, 720);

        expect(provider.width, 1280);
        expect(provider.height, 720);
      });

      test('resize 未初始化时抛出异常', () async {
        expect(
          () async => await provider.resize(1280, 720),
          throwsA(isA<StateError>()),
        );
      });

      test('resize 支持放大', () async {
        await provider.initialize(1280, 720);

        await provider.resize(3840, 2160);

        expect(provider.width, 3840);
        expect(provider.height, 2160);
      });
    });

    group('生命周期', () {
      test('release 释放渲染器资源', () async {
        await provider.initialize(1920, 1080);
        final frame = VideoFrame(
          width: 1920,
          height: 1080,
          format: 0,
          timestamp: Duration.zero,
        );
        await provider.render(frame);

        await provider.release();

        expect(provider.isInitialized, false);
        expect(provider.textureId, -1);
        expect(provider.renderCount, 0);
      });

      test('release 后可以重新初始化', () async {
        await provider.initialize(1920, 1080);
        await provider.release();

        await provider.initialize(1280, 720);

        expect(provider.isInitialized, true);
        expect(provider.width, 1280);
      });
    });

    group('属性', () {
      test('textureId 初始值为 -1', () {
        expect(provider.textureId, -1);
      });

      test('textureId 初始化后有效', () async {
        await provider.initialize(1920, 1080);
        expect(provider.textureId, isNot(-1));
      });
    });
  });

  group('RendererProvider 与 VideoFrame 集成', () {
    late TestRendererProvider provider;

    setUp(() async {
      provider = TestRendererProvider();
      await provider.initialize(1920, 1080);
    });

    tearDown(() async {
      await provider.release();
    });

    test('渲染不同格式的帧', () async {
      final frames = [
        VideoFrame(width: 1920, height: 1080, format: 0, timestamp: const Duration(milliseconds: 0)),
        VideoFrame(width: 1920, height: 1080, format: 1, timestamp: const Duration(milliseconds: 33)),
        VideoFrame(width: 1920, height: 1080, format: 2, timestamp: const Duration(milliseconds: 66)),
      ];

      for (final frame in frames) {
        await provider.render(frame);
      }

      expect(provider.renderCount, 3);
      expect(provider.lastFrame?.format, 2);
    });

    test('渲染带数据和无数据的帧', () async {
      final withData = VideoFrame(
        data: Uint8List.fromList([1, 2, 3, 4]),
        width: 1920,
        height: 1080,
        format: 0,
        timestamp: Duration.zero,
      );

      final withoutData = VideoFrame(
        width: 1920,
        height: 1080,
        format: 0,
        timestamp: Duration.zero,
      );

      await provider.render(withData);
      expect(provider.lastFrame?.data, isNotNull);

      await provider.render(withoutData);
      expect(provider.lastFrame?.data, isNull);
    });
  });
}
