import 'dart:typed_data';

abstract class DataSourceProvider {
  Future<void> open(Uri uri, {Map<String, String>? headers});
  Future<Uint8List> read(int size);
  Future<void> seek(int position);
  Future<int?> getSize();
  Future<void> close();
  bool get isSeekable;
}
