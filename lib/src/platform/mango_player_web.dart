/// Web 平台占位实现
///
/// 当前版本不支持 Web 平台，此文件为未来 Web 支持预留接口。
/// Web 平台实现计划使用 video.js 或原生 HTML5 Video API。
library;

import 'dart:async';

import '../core/media_source.dart';
import '../core/playback_event.dart';
import 'mango_player_platform_interface.dart';

/// Web 平台 MangoPlayer 实现
///
/// 这是一个占位实现，所有方法都会抛出 [UnsupportedError]。
/// 未来 Web 支持将在此类中实现。
class MangoPlayerWeb extends MangoPlayerPlatform {
  /// 平台不支持错误消息
  static const String _unsupportedMessage = 
      'MangoPlayer Web 平台暂不支持。预计在未来版本中添加 Web 支持。';

  /// 检查是否为 Web 平台
  static bool get isSupported => false;

  /// 获取平台信息
  static Map<String, String> get platformInfo => {
    'platform': 'web',
    'supported': 'false',
    'plannedVersion': '2.0.0',
    'notes': '计划使用 video.js 或 HTML5 Video API 实现',
  };

  @override
  Future<Duration?> initialize(MediaSource source, {int? textureId}) {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> play() {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> pause() {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> stop() {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<Duration?> seekTo(Duration position) {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> setVolume(double volume) {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<Duration?> getPosition() {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<Duration?> getDuration() {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> dispose() {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<int?> registerTexture() {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<void> unregisterTexture(int textureId) {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Future<Map<String, dynamic>?> getPerformanceMetrics() {
    throw UnsupportedError(_unsupportedMessage);
  }

  @override
  Stream<PlaybackEvent> get eventStream {
    throw UnsupportedError(_unsupportedMessage);
  }
}

/// Web 平台特定配置（预留）
///
/// 未来 Web 实现可能需要的配置选项。
class WebPlayerConfig {
  /// 是否使用 video.js
  final bool useVideoJs;

  /// video.js CDN URL（如果使用）
  final String? videoJsCdnUrl;

  /// 是否启用 HLS.js（用于 HLS 播放）
  final bool enableHlsJs;

  /// 是否启用 dash.js（用于 DASH 播放）
  final bool enableDashJs;

  /// 自定义播放器样式
  final String? customStyles;

  /// 构造函数
  const WebPlayerConfig({
    this.useVideoJs = false,
    this.videoJsCdnUrl,
    this.enableHlsJs = true,
    this.enableDashJs = false,
    this.customStyles,
  });

  /// 默认配置
  static const WebPlayerConfig defaultConfig = WebPlayerConfig();

  /// 使用 video.js 的配置
  static const WebPlayerConfig withVideoJs = WebPlayerConfig(
    useVideoJs: true,
    videoJsCdnUrl: 'https://vjs.zencdn.net/8.3.0/video.min.js',
  );
}

/// Web 平台功能检测（预留）
class WebCapabilities {
  /// 检测浏览器是否支持 MSE (Media Source Extensions)
  static Future<bool> supportsMse() async {
    // 未来实现：使用 dart:js_interop 检测
    return false;
  }

  /// 检测浏览器是否原生支持 HLS
  static Future<bool> supportsNativeHls() async {
    // Safari 支持原生 HLS
    return false;
  }

  /// 检测浏览器是否支持 WebCodecs API
  static Future<bool> supportsWebCodecs() async {
    // 现代浏览器的新 API
    return false;
  }

  /// 获取支持的视频格式
  static Future<List<String>> getSupportedFormats() async {
    // 未来实现：检测 video.canPlayType()
    return [];
  }
}
