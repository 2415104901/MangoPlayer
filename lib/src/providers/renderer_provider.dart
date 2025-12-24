import 'decoder_provider.dart';

abstract class RendererProvider {
  Future<void> initialize(int width, int height);
  int get textureId;
  Future<void> render(VideoFrame frame);
  Future<void> resize(int width, int height);
  Future<void> release();
}
