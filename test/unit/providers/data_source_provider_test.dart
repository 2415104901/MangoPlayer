import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/src/providers/data_source_provider.dart';

/// 测试用的具体 DataSourceProvider 实现
class TestDataSourceProvider implements DataSourceProvider {
  bool _isOpened = false;
  bool _isSeekable = true;
  int _position = 0;
  Uint8List _data = Uint8List(0);

  void setTestData(Uint8List data) {
    _data = data;
  }

  @override
  Future<void> open(Uri uri, {Map<String, String>? headers}) async {
    _isOpened = true;
    _position = 0;
  }

  @override
  Future<Uint8List> read(int size) async {
    if (!_isOpened) throw StateError('Provider not opened');
    final end = (_position + size).clamp(0, _data.length);
    final result = _data.sublist(_position, end);
    _position = end;
    return result;
  }

  @override
  Future<void> seek(int position) async {
    if (!_isOpened) throw StateError('Provider not opened');
    _position = position.clamp(0, _data.length);
  }

  @override
  Future<int?> getSize() async {
    return _data.length;
  }

  @override
  Future<void> close() async {
    _isOpened = false;
    _position = 0;
  }

  @override
  bool get isSeekable => _isSeekable;

  void setSeekable(bool value) {
    _isSeekable = value;
  }

  bool get isOpened => _isOpened;
  int get position => _position;
}

void main() {
  group('DataSourceProvider', () {
    late TestDataSourceProvider provider;

    setUp(() {
      provider = TestDataSourceProvider();
    });

    group('生命周期', () {
      test('open 打开数据源', () async {
        await provider.open(Uri.parse('https://example.com/video.mp4'));
        expect(provider.isOpened, true);
      });

      test('close 关闭数据源', () async {
        await provider.open(Uri.parse('https://example.com/video.mp4'));
        await provider.close();
        expect(provider.isOpened, false);
      });

      test('open 带 headers', () async {
        await provider.open(
          Uri.parse('https://example.com/video.mp4'),
          headers: {'Authorization': 'Bearer token'},
        );
        expect(provider.isOpened, true);
      });
    });

    group('读取', () {
      test('read 读取数据', () async {
        provider.setTestData(Uint8List.fromList([1, 2, 3, 4, 5]));
        await provider.open(Uri.parse('file:///test.mp4'));
        
        final data = await provider.read(3);
        expect(data.length, 3);
        expect(data, [1, 2, 3]);
      });

      test('read 连续读取', () async {
        provider.setTestData(Uint8List.fromList([1, 2, 3, 4, 5, 6]));
        await provider.open(Uri.parse('file:///test.mp4'));
        
        final first = await provider.read(3);
        final second = await provider.read(3);
        
        expect(first, [1, 2, 3]);
        expect(second, [4, 5, 6]);
      });

      test('read 超出范围返回可用数据', () async {
        provider.setTestData(Uint8List.fromList([1, 2, 3]));
        await provider.open(Uri.parse('file:///test.mp4'));
        
        final data = await provider.read(10);
        expect(data.length, 3);
      });
    });

    group('seek', () {
      test('seek 移动位置', () async {
        provider.setTestData(Uint8List.fromList([1, 2, 3, 4, 5]));
        await provider.open(Uri.parse('file:///test.mp4'));
        
        await provider.seek(2);
        final data = await provider.read(2);
        
        expect(data, [3, 4]);
      });

      test('seek 超出范围被限制', () async {
        provider.setTestData(Uint8List.fromList([1, 2, 3]));
        await provider.open(Uri.parse('file:///test.mp4'));
        
        await provider.seek(100);
        expect(provider.position, 3);
      });
    });

    group('属性', () {
      test('getSize 返回数据大小', () async {
        provider.setTestData(Uint8List.fromList([1, 2, 3, 4, 5]));
        final size = await provider.getSize();
        expect(size, 5);
      });

      test('isSeekable 默认为 true', () {
        expect(provider.isSeekable, true);
      });

      test('isSeekable 可以设置', () {
        provider.setSeekable(false);
        expect(provider.isSeekable, false);
      });
    });

    group('错误处理', () {
      test('未打开时读取抛出异常', () async {
        expect(
          () async => await provider.read(10),
          throwsA(isA<StateError>()),
        );
      });

      test('未打开时 seek 抛出异常', () async {
        expect(
          () async => await provider.seek(0),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
