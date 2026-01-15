/// 性能指标数据类
///
/// 提供视频播放过程中的实时性能指标，包括帧率、解码耗时、
/// 缓冲状态等关键性能数据。
library;

/// 性能指标快照
///
/// 包含某一时刻的所有性能相关数据。
class PerformanceMetrics {
  /// 视频帧率 (fps)
  final double frameRate;

  /// 丢帧数
  final int droppedFrames;

  /// 解码帧总数
  final int decodedFrames;

  /// 视频解码耗时 (毫秒)
  final double videoDecodeTimeMs;

  /// 音频解码耗时 (毫秒)
  final double audioDecodeTimeMs;

  /// 渲染耗时 (毫秒)
  final double renderTimeMs;

  /// 缓冲区长度 (毫秒)
  final int bufferLengthMs;

  /// 带宽估计值 (bps)
  final int? bandwidthBps;

  /// 是否使用硬件解码
  final bool isHardwareDecoding;

  /// 当前视频码率 (bps)
  final int? videoBitrate;

  /// 当前音频码率 (bps)
  final int? audioBitrate;

  /// 分辨率宽度
  final int? width;

  /// 分辨率高度
  final int? height;

  /// 采样时间戳
  final DateTime timestamp;

  /// 构造函数
  const PerformanceMetrics({
    required this.frameRate,
    required this.droppedFrames,
    required this.decodedFrames,
    required this.videoDecodeTimeMs,
    required this.audioDecodeTimeMs,
    required this.renderTimeMs,
    required this.bufferLengthMs,
    this.bandwidthBps,
    required this.isHardwareDecoding,
    this.videoBitrate,
    this.audioBitrate,
    this.width,
    this.height,
    required this.timestamp,
  });

  /// 空指标（初始状态）
  factory PerformanceMetrics.empty() {
    return PerformanceMetrics(
      frameRate: 0.0,
      droppedFrames: 0,
      decodedFrames: 0,
      videoDecodeTimeMs: 0.0,
      audioDecodeTimeMs: 0.0,
      renderTimeMs: 0.0,
      bufferLengthMs: 0,
      isHardwareDecoding: false,
      timestamp: DateTime.now(),
    );
  }

  /// 从 Platform Channel 数据创建
  factory PerformanceMetrics.fromMap(Map<String, dynamic> map) {
    return PerformanceMetrics(
      frameRate: (map['frameRate'] as num?)?.toDouble() ?? 0.0,
      droppedFrames: (map['droppedFrames'] as int?) ?? 0,
      decodedFrames: (map['decodedFrames'] as int?) ?? 0,
      videoDecodeTimeMs: (map['videoDecodeTimeMs'] as num?)?.toDouble() ?? 0.0,
      audioDecodeTimeMs: (map['audioDecodeTimeMs'] as num?)?.toDouble() ?? 0.0,
      renderTimeMs: (map['renderTimeMs'] as num?)?.toDouble() ?? 0.0,
      bufferLengthMs: (map['bufferLengthMs'] as int?) ?? 0,
      bandwidthBps: map['bandwidthBps'] as int?,
      isHardwareDecoding: (map['isHardwareDecoding'] as bool?) ?? false,
      videoBitrate: map['videoBitrate'] as int?,
      audioBitrate: map['audioBitrate'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      timestamp: DateTime.now(),
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'frameRate': frameRate,
      'droppedFrames': droppedFrames,
      'decodedFrames': decodedFrames,
      'videoDecodeTimeMs': videoDecodeTimeMs,
      'audioDecodeTimeMs': audioDecodeTimeMs,
      'renderTimeMs': renderTimeMs,
      'bufferLengthMs': bufferLengthMs,
      'bandwidthBps': bandwidthBps,
      'isHardwareDecoding': isHardwareDecoding,
      'videoBitrate': videoBitrate,
      'audioBitrate': audioBitrate,
      'width': width,
      'height': height,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 丢帧率
  double get dropRate {
    if (decodedFrames == 0) return 0.0;
    return droppedFrames / (decodedFrames + droppedFrames);
  }

  /// 总解码耗时 (毫秒)
  double get totalDecodeTimeMs => videoDecodeTimeMs + audioDecodeTimeMs;

  /// 是否性能良好（丢帧率 < 1%）
  bool get isHealthy => dropRate < 0.01;

  /// 是否性能警告（丢帧率 1% - 5%）
  bool get isWarning => dropRate >= 0.01 && dropRate < 0.05;

  /// 是否性能严重（丢帧率 >= 5%）
  bool get isCritical => dropRate >= 0.05;

  /// 性能等级
  PerformanceLevel get level {
    if (isCritical) return PerformanceLevel.critical;
    if (isWarning) return PerformanceLevel.warning;
    return PerformanceLevel.healthy;
  }

  /// 分辨率描述
  String? get resolution {
    if (width != null && height != null) {
      return '${width}x$height';
    }
    return null;
  }

  @override
  String toString() {
    return 'PerformanceMetrics('
        'fps: ${frameRate.toStringAsFixed(1)}, '
        'dropped: $droppedFrames, '
        'decode: ${videoDecodeTimeMs.toStringAsFixed(1)}ms, '
        'render: ${renderTimeMs.toStringAsFixed(1)}ms, '
        'buffer: ${bufferLengthMs}ms, '
        'hw: $isHardwareDecoding)';
  }

  /// 复制并修改部分属性
  PerformanceMetrics copyWith({
    double? frameRate,
    int? droppedFrames,
    int? decodedFrames,
    double? videoDecodeTimeMs,
    double? audioDecodeTimeMs,
    double? renderTimeMs,
    int? bufferLengthMs,
    int? bandwidthBps,
    bool? isHardwareDecoding,
    int? videoBitrate,
    int? audioBitrate,
    int? width,
    int? height,
    DateTime? timestamp,
  }) {
    return PerformanceMetrics(
      frameRate: frameRate ?? this.frameRate,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      decodedFrames: decodedFrames ?? this.decodedFrames,
      videoDecodeTimeMs: videoDecodeTimeMs ?? this.videoDecodeTimeMs,
      audioDecodeTimeMs: audioDecodeTimeMs ?? this.audioDecodeTimeMs,
      renderTimeMs: renderTimeMs ?? this.renderTimeMs,
      bufferLengthMs: bufferLengthMs ?? this.bufferLengthMs,
      bandwidthBps: bandwidthBps ?? this.bandwidthBps,
      isHardwareDecoding: isHardwareDecoding ?? this.isHardwareDecoding,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      width: width ?? this.width,
      height: height ?? this.height,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// 性能等级
enum PerformanceLevel {
  /// 健康：丢帧率 < 1%
  healthy,

  /// 警告：丢帧率 1% - 5%
  warning,

  /// 严重：丢帧率 >= 5%
  critical,
}

/// 性能指标收集器配置
class PerformanceConfig {
  /// 采样间隔（毫秒）
  final int sampleIntervalMs;

  /// 是否收集带宽数据
  final bool collectBandwidth;

  /// 是否收集码率数据
  final bool collectBitrate;

  /// 是否收集分辨率数据
  final bool collectResolution;

  /// 是否启用详细日志
  final bool enableLogging;

  /// 构造函数
  const PerformanceConfig({
    this.sampleIntervalMs = 1000,
    this.collectBandwidth = true,
    this.collectBitrate = true,
    this.collectResolution = true,
    this.enableLogging = false,
  });

  /// 默认配置
  static const PerformanceConfig defaultConfig = PerformanceConfig();

  /// 最小采样间隔配置（用于调试）
  static const PerformanceConfig debug = PerformanceConfig(
    sampleIntervalMs: 100,
    enableLogging: true,
  );

  /// 低开销配置
  static const PerformanceConfig lowOverhead = PerformanceConfig(
    sampleIntervalMs: 5000,
    collectBandwidth: false,
    collectBitrate: false,
  );

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'sampleIntervalMs': sampleIntervalMs,
      'collectBandwidth': collectBandwidth,
      'collectBitrate': collectBitrate,
      'collectResolution': collectResolution,
      'enableLogging': enableLogging,
    };
  }
}

/// 性能指标聚合器
///
/// 用于计算一段时间内的性能统计数据。
class PerformanceAggregator {
  final List<PerformanceMetrics> _samples = [];
  final int maxSamples;

  /// 构造函数
  PerformanceAggregator({this.maxSamples = 60});

  /// 添加样本
  void addSample(PerformanceMetrics metrics) {
    _samples.add(metrics);
    while (_samples.length > maxSamples) {
      _samples.removeAt(0);
    }
  }

  /// 清空样本
  void clear() => _samples.clear();

  /// 样本数量
  int get sampleCount => _samples.length;

  /// 平均帧率
  double get averageFrameRate {
    if (_samples.isEmpty) return 0.0;
    return _samples.map((s) => s.frameRate).reduce((a, b) => a + b) /
        _samples.length;
  }

  /// 总丢帧数
  int get totalDroppedFrames {
    if (_samples.isEmpty) return 0;
    return _samples.last.droppedFrames;
  }

  /// 平均解码耗时
  double get averageDecodeTime {
    if (_samples.isEmpty) return 0.0;
    return _samples.map((s) => s.videoDecodeTimeMs).reduce((a, b) => a + b) /
        _samples.length;
  }

  /// 平均渲染耗时
  double get averageRenderTime {
    if (_samples.isEmpty) return 0.0;
    return _samples.map((s) => s.renderTimeMs).reduce((a, b) => a + b) /
        _samples.length;
  }

  /// 最大解码耗时
  double get maxDecodeTime {
    if (_samples.isEmpty) return 0.0;
    return _samples.map((s) => s.videoDecodeTimeMs).reduce((a, b) => a > b ? a : b);
  }

  /// 最大渲染耗时
  double get maxRenderTime {
    if (_samples.isEmpty) return 0.0;
    return _samples.map((s) => s.renderTimeMs).reduce((a, b) => a > b ? a : b);
  }

  /// 获取摘要
  PerformanceSummary getSummary() {
    return PerformanceSummary(
      sampleCount: sampleCount,
      averageFrameRate: averageFrameRate,
      totalDroppedFrames: totalDroppedFrames,
      averageDecodeTimeMs: averageDecodeTime,
      maxDecodeTimeMs: maxDecodeTime,
      averageRenderTimeMs: averageRenderTime,
      maxRenderTimeMs: maxRenderTime,
    );
  }
}

/// 性能摘要
class PerformanceSummary {
  final int sampleCount;
  final double averageFrameRate;
  final int totalDroppedFrames;
  final double averageDecodeTimeMs;
  final double maxDecodeTimeMs;
  final double averageRenderTimeMs;
  final double maxRenderTimeMs;

  const PerformanceSummary({
    required this.sampleCount,
    required this.averageFrameRate,
    required this.totalDroppedFrames,
    required this.averageDecodeTimeMs,
    required this.maxDecodeTimeMs,
    required this.averageRenderTimeMs,
    required this.maxRenderTimeMs,
  });

  @override
  String toString() {
    return 'PerformanceSummary('
        'samples: $sampleCount, '
        'avgFps: ${averageFrameRate.toStringAsFixed(1)}, '
        'dropped: $totalDroppedFrames, '
        'avgDecode: ${averageDecodeTimeMs.toStringAsFixed(1)}ms, '
        'avgRender: ${averageRenderTimeMs.toStringAsFixed(1)}ms)';
  }
}
