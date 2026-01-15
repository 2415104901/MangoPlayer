import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/src/providers/decoder_provider.dart';

/// 测试用的具体 DecoderProvider 实现
class TestDecoderProvider implements DecoderProvider {
  bool _configured = false;
  bool _hardwareEnabled = true;
  VideoConfig? _config;
  final StreamController<DecoderEvent> _eventController = 
      StreamController<DecoderEvent>.broadcast();
  int _decodeCallCount = 0;

  @override
  Future<void> configure(VideoConfig config) async {
    _config = config;
    _configured = true;
  }

  @override
  Future<VideoFrame?> decode(Uint8List data) async {
    if (!_configured) {
      throw StateError('Decoder not configured');
    }
    _decodeCallCount++;
    
    // 返回模拟帧
    return VideoFrame(
      data: data,
      width: _config?.width ?? 1920,
      height: _config?.height ?? 1080,
      format: 0,
      timestamp: Duration(milliseconds: _decodeCallCount * 33),
    );
  }

  @override
  Future<void> flush() async {
    _decodeCallCount = 0;
  }

  @override
  Future<void> release() async {
    _configured = false;
    _config = null;
    await _eventController.close();
  }

  @override
  Future<void> enableHardwareDecode(bool enable) async {
    _hardwareEnabled = enable;
  }

  @override
  bool get supportsHardwareDecoding => true;

  @override
  String get codecType => 'h264';

  @override
  Stream<DecoderEvent> get events => _eventController.stream;

  // Test helpers
  bool get isConfigured => _configured;
  bool get isHardwareEnabled => _hardwareEnabled;
  VideoConfig? get config => _config;
  int get decodeCallCount => _decodeCallCount;
}

/// 测试用的自定义 DecoderEvent
class TestDecoderEvent implements DecoderEvent {
  final String message;
  TestDecoderEvent(this.message);
}

void main() {
  group('DecoderProvider', () {
    late TestDecoderProvider provider;

    setUp(() {
      provider = TestDecoderProvider();
    });

    tearDown(() async {
      try {
        await provider.release();
      } catch (_) {}
    });

    group('配置', () {
      test('configure 设置解码器配置', () async {
        final config = VideoConfig(
          width: 1920,
          height: 1080,
          codec: 'h264',
          bitrate: 5000000,
        );

        await provider.configure(config);

        expect(provider.isConfigured, true);
        expect(provider.config?.width, 1920);
        expect(provider.config?.height, 1080);
        expect(provider.config?.codec, 'h264');
      });

      test('configure 支持不同分辨率', () async {
        final config = VideoConfig(
          width: 3840,
          height: 2160,
          codec: 'hevc',
        );

        await provider.configure(config);

        expect(provider.config?.width, 3840);
        expect(provider.config?.height, 2160);
      });
    });

    group('解码', () {
      test('decode 解码数据返回帧', () async {
        await provider.configure(VideoConfig(
          width: 1280,
          height: 720,
          codec: 'h264',
        ));

        final frame = await provider.decode(Uint8List.fromList([0, 1, 2, 3]));

        expect(frame, isNotNull);
        expect(frame?.width, 1280);
        expect(frame?.height, 720);
      });

      test('decode 未配置时抛出异常', () async {
        expect(
          () async => await provider.decode(Uint8List(10)),
          throwsA(isA<StateError>()),
        );
      });

      test('decode 多次调用更新时间戳', () async {
        await provider.configure(VideoConfig(
          width: 1920,
          height: 1080,
          codec: 'h264',
        ));

        final frame1 = await provider.decode(Uint8List(10));
        final frame2 = await provider.decode(Uint8List(10));

        expect(frame1?.timestamp.inMilliseconds, 33);
        expect(frame2?.timestamp.inMilliseconds, 66);
      });
    });

    group('硬件解码', () {
      test('supportsHardwareDecoding 返回支持状态', () {
        expect(provider.supportsHardwareDecoding, true);
      });

      test('enableHardwareDecode 启用硬件解码', () async {
        await provider.enableHardwareDecode(true);
        expect(provider.isHardwareEnabled, true);
      });

      test('enableHardwareDecode 禁用硬件解码', () async {
        await provider.enableHardwareDecode(false);
        expect(provider.isHardwareEnabled, false);
      });
    });

    group('生命周期', () {
      test('flush 清空解码器状态', () async {
        await provider.configure(VideoConfig(
          width: 1920,
          height: 1080,
          codec: 'h264',
        ));
        await provider.decode(Uint8List(10));
        await provider.decode(Uint8List(10));

        expect(provider.decodeCallCount, 2);

        await provider.flush();

        expect(provider.decodeCallCount, 0);
      });

      test('release 释放解码器资源', () async {
        await provider.configure(VideoConfig(
          width: 1920,
          height: 1080,
          codec: 'h264',
        ));

        await provider.release();

        expect(provider.isConfigured, false);
        expect(provider.config, isNull);
      });
    });

    group('属性', () {
      test('codecType 返回编解码器类型', () {
        expect(provider.codecType, 'h264');
      });

      test('events 返回事件流', () {
        expect(provider.events, isA<Stream<DecoderEvent>>());
      });
    });
  });

  group('VideoConfig', () {
    test('创建基本配置', () {
      final config = VideoConfig(
        width: 1920,
        height: 1080,
        codec: 'h264',
      );

      expect(config.width, 1920);
      expect(config.height, 1080);
      expect(config.codec, 'h264');
      expect(config.bitrate, isNull);
    });

    test('创建带 bitrate 的配置', () {
      final config = VideoConfig(
        width: 1920,
        height: 1080,
        codec: 'h264',
        bitrate: 8000000,
      );

      expect(config.bitrate, 8000000);
    });
  });

  group('VideoFrame', () {
    test('创建视频帧', () {
      final frame = VideoFrame(
        data: Uint8List.fromList([1, 2, 3]),
        width: 1920,
        height: 1080,
        format: 0,
        timestamp: const Duration(milliseconds: 100),
      );

      expect(frame.width, 1920);
      expect(frame.height, 1080);
      expect(frame.format, 0);
      expect(frame.timestamp.inMilliseconds, 100);
    });

    test('创建无数据的视频帧', () {
      final frame = VideoFrame(
        width: 1280,
        height: 720,
        format: 1,
        timestamp: Duration.zero,
      );

      expect(frame.data, isNull);
      expect(frame.width, 1280);
    });
  });
}
