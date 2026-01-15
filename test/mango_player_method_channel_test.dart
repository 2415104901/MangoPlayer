import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/src/core/media_source.dart';
import 'package:mango_player/src/platform/mango_player_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelMangoPlayer', () {
    late MethodChannelMangoPlayer platform;
    late List<MethodCall> methodCalls;

    setUp(() {
      platform = MethodChannelMangoPlayer();
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          switch (methodCall.method) {
            case 'initialize':
              return {'duration': 60000};
            case 'play':
            case 'pause':
            case 'stop':
            case 'setVolume':
            case 'setPlaybackSpeed':
            case 'dispose':
              return null;
            case 'seekTo':
              return {'actualPosition': methodCall.arguments['position']};
            case 'getPosition':
              return {'position': 30000};
            case 'getDuration':
              return {'duration': 60000};
            default:
              return null;
          }
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.textureChannel,
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          switch (methodCall.method) {
            case 'registerTexture':
              return {'textureId': 1};
            case 'unregisterTexture':
              return null;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.textureChannel, null);
    });

    test('initialize 发送正确的参数', () async {
      final source = MediaSource.network(
        'https://example.com/video.mp4',
        headers: {'Authorization': 'Bearer token'},
      );

      final duration = await platform.initialize(source, textureId: 1);

      expect(duration?.inSeconds, 60);
      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'initialize');
      expect(methodCalls.first.arguments['uri'], 'https://example.com/video.mp4');
      expect(methodCalls.first.arguments['type'], 'network');
      expect(methodCalls.first.arguments['headers'], {'Authorization': 'Bearer token'});
      expect(methodCalls.first.arguments['textureId'], 1);
    });

    test('initialize 处理本地文件', () async {
      final source = MediaSource.file('/path/to/video.mp4');

      await platform.initialize(source);

      expect(methodCalls.first.arguments['type'], 'file');
    });

    test('play 调用正确', () async {
      await platform.play();

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'play');
    });

    test('pause 调用正确', () async {
      await platform.pause();

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'pause');
    });

    test('stop 调用正确', () async {
      await platform.stop();

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'stop');
    });

    test('seekTo 发送位置参数', () async {
      final position = await platform.seekTo(const Duration(seconds: 30));

      expect(position?.inSeconds, 30);
      expect(methodCalls.first.method, 'seekTo');
      expect(methodCalls.first.arguments['position'], 30000);
    });

    test('setVolume 发送音量参数', () async {
      await platform.setVolume(0.5);

      expect(methodCalls.first.method, 'setVolume');
      expect(methodCalls.first.arguments['volume'], 0.5);
    });

    test('setPlaybackSpeed 发送速度参数', () async {
      await platform.setPlaybackSpeed(2.0);

      expect(methodCalls.first.method, 'setPlaybackSpeed');
      expect(methodCalls.first.arguments['speed'], 2.0);
    });

    test('getPosition 返回当前位置', () async {
      final position = await platform.getPosition();

      expect(position?.inSeconds, 30);
      expect(methodCalls.first.method, 'getPosition');
    });

    test('getDuration 返回总时长', () async {
      final duration = await platform.getDuration();

      expect(duration?.inSeconds, 60);
      expect(methodCalls.first.method, 'getDuration');
    });

    test('registerTexture 返回 textureId', () async {
      final textureId = await platform.registerTexture();

      expect(textureId, 1);
      expect(methodCalls.any((c) => c.method == 'registerTexture'), true);
    });

    test('unregisterTexture 调用正确', () async {
      await platform.unregisterTexture(1);

      expect(methodCalls.any((c) => c.method == 'unregisterTexture'), true);
    });
  });

  group('MethodChannelMangoPlayer 错误处理', () {
    late MethodChannelMangoPlayer platform;

    setUp(() {
      platform = MethodChannelMangoPlayer();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        platform.methodChannel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'initialize') {
            throw PlatformException(
              code: 'INIT_ERROR',
              message: 'Failed to initialize',
            );
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    test('initialize 错误时抛出 PlatformException', () async {
      final source = MediaSource.network('https://example.com/video.mp4');

      expect(
        () async => await platform.initialize(source),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
