import 'dart:async';

import '../platform/mango_player_platform_interface.dart';
import '../platform/mango_player_method_channel.dart';
import 'media_source.dart';
import 'performance_metrics.dart';
import 'playback_event.dart';
import 'player_config.dart';
import 'player_error.dart';
import 'player_state.dart';

class MangoPlayerController {
  final PlayerConfig config;
  
  MangoPlayerController({
    this.config = const PlayerConfig(),
  }) {
    // Listen to event stream to update position/duration
    _eventSubscription = eventStream.listen(_handlePlaybackEvent);
  }

  final _stateController = StreamController<PlayerState>.broadcast();
  final _errorController = StreamController<PlayerError>.broadcast();
  final _performanceController = StreamController<PerformanceMetrics>.broadcast();
  
  // Event stream subscription
  StreamSubscription<PlaybackEvent>? _eventSubscription;
  
  PlayerState _state = PlayerState.idle;
  PlayerState get state => _state;
  
  Stream<PlayerState> get stateStream => _stateController.stream;
  Stream<PlayerError> get errorStream => _errorController.stream;
  Stream<PlaybackEvent> get eventStream => MangoPlayerPlatform.instance.eventStream;
  
  /// 性能指标事件流
  /// 
  /// 提供实时性能数据，包括帧率、解码耗时、丢帧数等。
  /// 采样频率由 [PerformanceConfig.sampleIntervalMs] 控制。
  Stream<PerformanceMetrics> get performanceStream => _performanceController.stream;
  
  /// 性能指标聚合器
  final PerformanceAggregator _performanceAggregator = PerformanceAggregator();
  
  /// 性能监控配置
  PerformanceConfig _performanceConfig = PerformanceConfig.defaultConfig;
  
  /// 性能监控定时器
  Timer? _performanceTimer;
  
  /// 是否启用性能监控
  bool _performanceMonitoringEnabled = false;

  Duration _position = Duration.zero;
  Duration get position => _position;
  
  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  int? _textureId;
  int? get textureId => _textureId;

  // Video dimensions
  double _videoWidth = 0;
  double _videoHeight = 0;
  double get videoWidth => _videoWidth;
  double get videoHeight => _videoHeight;

  Future<void> initialize(MediaSource source) async {
    _state = PlayerState.initializing;
    _stateController.add(_state);
    
    try {
      // Register texture first
      _textureId = await MangoPlayerPlatform.instance.registerTexture();
      
      final duration = await MangoPlayerPlatform.instance.initialize(source, textureId: _textureId);
      if (duration != null) {
        _duration = duration;
      }
      
      // Get video dimensions from platform
      final platform = MangoPlayerPlatform.instance;
      if (platform is MethodChannelMangoPlayer) {
        _videoWidth = platform.videoWidth;
        _videoHeight = platform.videoHeight;
      }
      
      _state = PlayerState.ready;
      _stateController.add(_state);
      
      if (config.autoPlay) {
        await play();
      }
    } catch (e, stack) {
      _state = PlayerState.error;
      _stateController.add(_state);
      _errorController.add(PlayerError(
        code: PlayerErrorCode.unknown,
        message: e.toString(),
        stackTrace: stack,
      ));
    }
  }

  Future<void> play() async {
    await MangoPlayerPlatform.instance.play();
    _state = PlayerState.playing;
    _stateController.add(_state);
  }

  Future<void> pause() async {
    await MangoPlayerPlatform.instance.pause();
    _state = PlayerState.paused;
    _stateController.add(_state);
  }

  Future<void> stop() async {
    await MangoPlayerPlatform.instance.stop();
    _state = PlayerState.idle;
    _stateController.add(_state);
  }

  Future<void> seekTo(Duration position) async {
    final actualPosition = await MangoPlayerPlatform.instance.seekTo(position);
    if (actualPosition != null) {
      _position = actualPosition;
    }
  }

  Future<void> setVolume(double volume) async {
    await MangoPlayerPlatform.instance.setVolume(volume);
  }

  Future<void> setMuted(bool muted) async {
    await MangoPlayerPlatform.instance.setMuted(muted);
  }

  Future<bool> getMuted() async {
    return await MangoPlayerPlatform.instance.getMuted();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await MangoPlayerPlatform.instance.setPlaybackSpeed(speed);
  }

  /// Handle playback events from native layer
  void _handlePlaybackEvent(PlaybackEvent event) {
    // Update position and duration from progress events
    // Always update, even if values are zero (valid at start of playback)
    _position = event.position;
    if (event.duration != Duration.zero) {
      _duration = event.duration;
    }

    assert(() {
      // Debug log for tracing position/duration updates
      // (asserts removed in release)
      // ignore: avoid_print
      print('🟢 [Controller] onEvent type=${event.state} pos=${_position.inMilliseconds}ms dur=${_duration.inMilliseconds}ms');
      return true;
    }());
    
    // Update state from state events
    if (event.state != PlayerState.idle || _state == PlayerState.idle) {
      // Only update state if it's meaningful (not default idle)
      if (event.state == PlayerState.completed ||
          event.state == PlayerState.error) {
        _state = event.state;
        _stateController.add(_state);
      }
    }
  }

  /// 启用性能监控
  /// 
  /// [config] 性能监控配置，控制采样频率和收集的指标类型
  void enablePerformanceMonitoring([PerformanceConfig? config]) {
    _performanceConfig = config ?? PerformanceConfig.defaultConfig;
    _performanceMonitoringEnabled = true;
    _startPerformanceTimer();
  }

  /// 禁用性能监控
  void disablePerformanceMonitoring() {
    _performanceMonitoringEnabled = false;
    _stopPerformanceTimer();
    _performanceAggregator.clear();
  }

  /// 获取当前性能指标快照
  Future<PerformanceMetrics> getPerformanceMetrics() async {
    final data = await MangoPlayerPlatform.instance.getPerformanceMetrics();
    if (data != null) {
      return PerformanceMetrics.fromMap(data);
    }
    return PerformanceMetrics.empty();
  }

  /// 获取性能摘要
  PerformanceSummary getPerformanceSummary() {
    return _performanceAggregator.getSummary();
  }

  void _startPerformanceTimer() {
    _stopPerformanceTimer();
    if (!_performanceMonitoringEnabled) return;
    
    _performanceTimer = Timer.periodic(
      Duration(milliseconds: _performanceConfig.sampleIntervalMs),
      (_) => _collectPerformanceMetrics(),
    );
  }

  void _stopPerformanceTimer() {
    _performanceTimer?.cancel();
    _performanceTimer = null;
  }

  Future<void> _collectPerformanceMetrics() async {
    if (!_performanceMonitoringEnabled) return;
    if (_state != PlayerState.playing && _state != PlayerState.paused) return;
    
    try {
      final metrics = await getPerformanceMetrics();
      _performanceAggregator.addSample(metrics);
      _performanceController.add(metrics);
    } catch (e) {
      // 静默忽略性能收集错误
      if (_performanceConfig.enableLogging) {
        // ignore: avoid_print
        print('Performance metrics collection error: $e');
      }
    }
  }

  Future<void> dispose() async {
    _stopPerformanceTimer();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    if (_textureId != null) {
      await MangoPlayerPlatform.instance.unregisterTexture(_textureId!);
      _textureId = null;
    }
    await MangoPlayerPlatform.instance.dispose();
    await _stateController.close();
    await _errorController.close();
    await _performanceController.close();
  }
}
