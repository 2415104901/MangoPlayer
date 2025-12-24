/// RTSP 传输模式
enum RtspTransport {
  /// 自动选择（默认 UDP，失败时回退到 TCP）
  auto,
  /// 强制使用 UDP
  udp,
  /// 强制使用 TCP
  tcp,
}

/// 播放器配置类
/// 
/// 用于配置播放器的各项参数，包括缓冲、网络、硬件解码等。
class PlayerConfig {
  /// 是否自动播放
  final bool autoPlay;
  
  /// 是否循环播放
  final bool looping;
  
  /// 是否优先使用硬件解码
  final bool preferHardwareDecoding;
  
  /// 事件更新间隔
  final Duration eventUpdateInterval;
  
  /// 缓冲区大小（秒）
  final int bufferSize;
  
  /// 是否启用日志
  final bool enableLogging;
  
  // === 流媒体相关配置 ===
  
  /// HLS 最小缓冲时长
  final Duration hlsMinBufferDuration;
  
  /// HLS 最大缓冲时长
  final Duration hlsMaxBufferDuration;
  
  /// 首选比特率（bps），0 表示自动
  final int preferredBitrate;
  
  /// RTSP 传输模式
  final RtspTransport rtspTransport;
  
  /// 是否启用低延迟模式
  final bool enableLowLatency;
  
  /// 最大缓冲时长（用于低延迟模式）
  final Duration maxBufferDuration;
  
  // === 自动重连配置 ===
  
  /// 是否启用自动重连
  final bool enableAutoReconnect;
  
  /// 最大重连次数
  final int maxReconnectAttempts;
  
  /// 重连延迟（指数退避基础值）
  final Duration reconnectDelay;
  
  /// 最大重连延迟
  final Duration maxReconnectDelay;

  const PlayerConfig({
    this.autoPlay = false,
    this.looping = false,
    this.preferHardwareDecoding = true,
    this.eventUpdateInterval = const Duration(milliseconds: 500),
    this.bufferSize = 10,
    this.enableLogging = false,
    // 流媒体配置
    this.hlsMinBufferDuration = const Duration(seconds: 10),
    this.hlsMaxBufferDuration = const Duration(seconds: 30),
    this.preferredBitrate = 0,
    this.rtspTransport = RtspTransport.auto,
    this.enableLowLatency = false,
    this.maxBufferDuration = const Duration(seconds: 10),
    // 自动重连配置
    this.enableAutoReconnect = true,
    this.maxReconnectAttempts = 5,
    this.reconnectDelay = const Duration(seconds: 2),
    this.maxReconnectDelay = const Duration(seconds: 30),
  });
  
  /// 创建低延迟配置
  factory PlayerConfig.lowLatency() {
    return const PlayerConfig(
      enableLowLatency: true,
      hlsMinBufferDuration: Duration(seconds: 2),
      hlsMaxBufferDuration: Duration(seconds: 5),
      maxBufferDuration: Duration(seconds: 2),
      eventUpdateInterval: Duration(milliseconds: 100),
    );
  }
  
  /// 创建高质量配置（更大缓冲区）
  factory PlayerConfig.highQuality() {
    return const PlayerConfig(
      hlsMinBufferDuration: Duration(seconds: 15),
      hlsMaxBufferDuration: Duration(seconds: 60),
      maxBufferDuration: Duration(seconds: 30),
      preferHardwareDecoding: true,
    );
  }
  
  /// 复制并修改配置
  PlayerConfig copyWith({
    bool? autoPlay,
    bool? looping,
    bool? preferHardwareDecoding,
    Duration? eventUpdateInterval,
    int? bufferSize,
    bool? enableLogging,
    Duration? hlsMinBufferDuration,
    Duration? hlsMaxBufferDuration,
    int? preferredBitrate,
    RtspTransport? rtspTransport,
    bool? enableLowLatency,
    Duration? maxBufferDuration,
    bool? enableAutoReconnect,
    int? maxReconnectAttempts,
    Duration? reconnectDelay,
    Duration? maxReconnectDelay,
  }) {
    return PlayerConfig(
      autoPlay: autoPlay ?? this.autoPlay,
      looping: looping ?? this.looping,
      preferHardwareDecoding: preferHardwareDecoding ?? this.preferHardwareDecoding,
      eventUpdateInterval: eventUpdateInterval ?? this.eventUpdateInterval,
      bufferSize: bufferSize ?? this.bufferSize,
      enableLogging: enableLogging ?? this.enableLogging,
      hlsMinBufferDuration: hlsMinBufferDuration ?? this.hlsMinBufferDuration,
      hlsMaxBufferDuration: hlsMaxBufferDuration ?? this.hlsMaxBufferDuration,
      preferredBitrate: preferredBitrate ?? this.preferredBitrate,
      rtspTransport: rtspTransport ?? this.rtspTransport,
      enableLowLatency: enableLowLatency ?? this.enableLowLatency,
      maxBufferDuration: maxBufferDuration ?? this.maxBufferDuration,
      enableAutoReconnect: enableAutoReconnect ?? this.enableAutoReconnect,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectDelay: maxReconnectDelay ?? this.maxReconnectDelay,
    );
  }
}
