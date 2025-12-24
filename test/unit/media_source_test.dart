import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/src/core/media_source.dart';

void main() {
  group('MediaSource', () {
    group('network', () {
      test('创建网络源', () {
        final source = MediaSource.network('https://example.com/video.mp4');

        expect(source.type, MediaSourceType.network);
        expect(source.uri.toString(), 'https://example.com/video.mp4');
        expect(source.headers, isNull);
        expect(source.mimeType, isNull);
      });

      test('创建带 headers 的网络源', () {
        final source = MediaSource.network(
          'https://example.com/video.mp4',
          headers: {'Authorization': 'Bearer token123'},
        );

        expect(source.headers, {'Authorization': 'Bearer token123'});
      });

      test('从字符串 URL 创建', () {
        final source = MediaSource.network('https://example.com/video.mp4');

        expect(source.uri.toString(), 'https://example.com/video.mp4');
      });
    });

    group('file', () {
      test('创建本地文件源', () {
        final source = MediaSource.file('/path/to/video.mp4');

        expect(source.type, MediaSourceType.file);
        expect(source.uri.path, contains('video.mp4'));
      });
    });

    group('asset', () {
      test('创建 asset 源', () {
        final source = MediaSource.asset('assets/video.mp4');

        expect(source.type, MediaSourceType.asset);
        expect(source.uri.toString(), contains('assets/video.mp4'));
      });
    });

    group('类型检测', () {
      test('network 类型正确识别', () {
        final network = MediaSource.network('https://example.com/video.mp4');
        expect(network.type, MediaSourceType.network);
      });

      test('file 类型正确识别', () {
        final file = MediaSource.file('/path/to/video.mp4');
        expect(file.type, MediaSourceType.file);
      });

      test('asset 类型正确识别', () {
        final asset = MediaSource.asset('assets/video.mp4');
        expect(asset.type, MediaSourceType.asset);
      });
    });

    group('构造函数', () {
      test('直接构造函数创建 MediaSource', () {
        final source = MediaSource(
          uri: Uri.parse('https://example.com/video.mp4'),
          type: MediaSourceType.network,
        );

        expect(source.uri.toString(), 'https://example.com/video.mp4');
        expect(source.type, MediaSourceType.network);
      });

      test('带完整参数的构造函数', () {
        final source = MediaSource(
          uri: Uri.parse('https://example.com/video.mp4'),
          type: MediaSourceType.network,
          headers: {'X-Custom': 'value'},
          mimeType: 'video/mp4',
        );

        expect(source.headers, {'X-Custom': 'value'});
        expect(source.mimeType, 'video/mp4');
      });
    });
  });

  group('MediaSourceType', () {
    test('包含所有类型', () {
      expect(MediaSourceType.values, contains(MediaSourceType.network));
      expect(MediaSourceType.values, contains(MediaSourceType.file));
      expect(MediaSourceType.values, contains(MediaSourceType.asset));
    });

    test('枚举值数量正确', () {
      expect(MediaSourceType.values.length, 3);
    });
  });
}
