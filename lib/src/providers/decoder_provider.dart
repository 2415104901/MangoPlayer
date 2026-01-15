import 'dart:typed_data';

class VideoConfig {
  final int width;
  final int height;
  final String codec;
  final int? bitrate;

  const VideoConfig({
    required this.width,
    required this.height,
    required this.codec,
    this.bitrate,
  });
}

class VideoFrame {
  final Uint8List? data;
  final int width;
  final int height;
  final int format;
  final Duration timestamp;

  const VideoFrame({
    this.data,
    required this.width,
    required this.height,
    required this.format,
    required this.timestamp,
  });
}

abstract class DecoderEvent {}

abstract class DecoderProvider {
  Future<void> configure(VideoConfig config);
  Future<VideoFrame?> decode(Uint8List data);
  Future<void> flush();
  Future<void> release();
  Future<void> enableHardwareDecode(bool enable);
  bool get supportsHardwareDecoding;
  String get codecType;
  Stream<DecoderEvent> get events;
}
