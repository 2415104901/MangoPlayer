import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../core/media_source.dart';
import '../core/playback_event.dart';
import 'mango_player_method_channel.dart';

abstract class MangoPlayerPlatform extends PlatformInterface {
  MangoPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static MangoPlayerPlatform _instance = MethodChannelMangoPlayer();

  static MangoPlayerPlatform get instance => _instance;

  static set instance(MangoPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Duration?> initialize(MediaSource source, {int? textureId}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> play() {
    throw UnimplementedError('play() has not been implemented.');
  }

  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented.');
  }

  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  Future<Duration?> seekTo(Duration position) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }

  Future<void> setVolume(double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  Future<void> setPlaybackSpeed(double speed) {
    throw UnimplementedError('setPlaybackSpeed() has not been implemented.');
  }

  Future<Duration?> getPosition() {
    throw UnimplementedError('getPosition() has not been implemented.');
  }

  Future<Duration?> getDuration() {
    throw UnimplementedError('getDuration() has not been implemented.');
  }

  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  Future<int?> registerTexture() {
    throw UnimplementedError('registerTexture() has not been implemented.');
  }

  Future<void> unregisterTexture(int textureId) {
    throw UnimplementedError('unregisterTexture() has not been implemented.');
  }

  /// 获取性能指标数据
  /// 
  /// 返回包含帧率、解码耗时、丢帧数等性能数据的 Map。
  Future<Map<String, dynamic>?> getPerformanceMetrics() {
    throw UnimplementedError('getPerformanceMetrics() has not been implemented.');
  }

  Stream<PlaybackEvent> get eventStream {
    throw UnimplementedError('get eventStream has not been implemented.');
  }
}
