/// HarmonyOS 平台占位实现
///
/// 当前版本不支持 HarmonyOS 平台，此文件为未来 HarmonyOS 支持预留接口。
/// HarmonyOS 平台实现计划使用 AVPlayer 或 FFmpeg。
library;

import 'dart:async';

import '../core/media_source.dart';
import '../core/playback_event.dart';
import 'mango_player_platform_interface.dart';

/// HarmonyOS 平台 MangoPlayer 实现
///
/// 这是一个占位实现，所有方法都会抛出 [UnsupportedError]。
/// 未来 HarmonyOS 支持将在此类中实现。
class MangoPlayerHarmony extends MangoPlayerPlatform {
  /// 平台不支持错误消息
  static const String _unsupportedMessage = 
      'MangoPlayer HarmonyOS 平台暂不支持。预计在未来版本中添加 HarmonyOS 支持。';

  /// 检查是否为 HarmonyOS 平台
  static bool get isSupported => false;

  /// 获取平台信息
  static Map<String, String> get platformInfo => {
    'platform': 'harmony',
    'supported': 'false',
    'plannedVersion': '2.0.0',
    'notes': '计划使用 HarmonyOS AVPlayer 或 FFmpeg 实现',
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

/// HarmonyOS 平台特定配置（预留）
///
/// 未来 HarmonyOS 实现可能需要的配置选项。
class HarmonyPlayerConfig {
  /// 是否使用 AVPlayer（HarmonyOS 原生播放器）
  final bool useAVPlayer;

  /// 是否使用 FFmpeg
  final bool useFFmpeg;

  /// 是否启用硬件解码
  final bool enableHardwareDecoding;

  /// 音频输出设备
  final HarmonyAudioDevice audioDevice;

  /// 构造函数
  const HarmonyPlayerConfig({
    this.useAVPlayer = true,
    this.useFFmpeg = false,
    this.enableHardwareDecoding = true,
    this.audioDevice = HarmonyAudioDevice.speaker,
  });

  /// 默认配置
  static const HarmonyPlayerConfig defaultConfig = HarmonyPlayerConfig();

  /// FFmpeg 配置
  static const HarmonyPlayerConfig ffmpegConfig = HarmonyPlayerConfig(
    useAVPlayer: false,
    useFFmpeg: true,
  );
}

/// HarmonyOS 音频输出设备
enum HarmonyAudioDevice {
  /// 扬声器
  speaker,
  
  /// 耳机
  headphone,
  
  /// 蓝牙设备
  bluetooth,
  
  /// USB 音频
  usb,
}

/// HarmonyOS 平台功能检测（预留）
class HarmonyCapabilities {
  /// 检测设备是否支持硬件解码
  static Future<bool> supportsHardwareDecoding() async {
    // 未来实现：调用 HarmonyOS API
    return false;
  }

  /// 检测设备是否支持 HDR
  static Future<bool> supportsHdr() async {
    return false;
  }

  /// 获取设备支持的视频解码器
  static Future<List<String>> getSupportedDecoders() async {
    // 未来实现：查询系统解码器
    return [];
  }

  /// 获取设备支持的音频解码器
  static Future<List<String>> getSupportedAudioDecoders() async {
    return [];
  }

  /// 获取最大支持的分辨率
  static Future<HarmonyResolution?> getMaxSupportedResolution() async {
    return null;
  }
}

/// HarmonyOS 分辨率
class HarmonyResolution {
  final int width;
  final int height;
  final int refreshRate;

  const HarmonyResolution({
    required this.width,
    required this.height,
    this.refreshRate = 60,
  });

  /// 4K 分辨率
  static const HarmonyResolution uhd4k = HarmonyResolution(
    width: 3840,
    height: 2160,
  );

  /// 1080p 分辨率
  static const HarmonyResolution fullHd = HarmonyResolution(
    width: 1920,
    height: 1080,
  );

  /// 720p 分辨率
  static const HarmonyResolution hd = HarmonyResolution(
    width: 1280,
    height: 720,
  );

  @override
  String toString() => '${width}x$height@${refreshRate}Hz';
}

/// HarmonyOS 设备信息（预留）
class HarmonyDeviceInfo {
  /// 设备型号
  final String model;

  /// HarmonyOS 版本
  final String osVersion;

  /// API 级别
  final int apiLevel;

  /// 是否为平板
  final bool isTablet;

  /// 是否为智慧屏
  final bool isSmartScreen;

  const HarmonyDeviceInfo({
    required this.model,
    required this.osVersion,
    required this.apiLevel,
    this.isTablet = false,
    this.isSmartScreen = false,
  });

  /// 获取当前设备信息
  static Future<HarmonyDeviceInfo?> getCurrent() async {
    // 未来实现：调用 HarmonyOS API
    return null;
  }
}
