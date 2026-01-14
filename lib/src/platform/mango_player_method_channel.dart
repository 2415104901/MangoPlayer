import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/media_source.dart';
import '../core/playback_event.dart';
import '../core/player_state.dart';
import 'mango_player_platform_interface.dart';

class MethodChannelMangoPlayer extends MangoPlayerPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('com.mangoplayer/player');

  @visibleForTesting
  final eventChannel = const EventChannel('com.mangoplayer/events');

  @visibleForTesting
  final textureChannel = const MethodChannel('com.mangoplayer/texture');

  Stream<PlaybackEvent>? _eventStream;

  @override
  Future<Duration?> initialize(MediaSource source, {int? textureId}) async {
    debugPrint('🎬 [Dart] MethodChannelMangoPlayer.initialize called');
    debugPrint('   URI: ${source.uri}');
    debugPrint('   Type: ${source.type.name}');
    debugPrint('   TextureId: $textureId');
    
    final Map<String, dynamic> args = {
      'uri': source.uri.toString(),
      'type': source.type.name,
    };
    if (source.headers != null) {
      args['headers'] = source.headers;
    }
    if (source.mimeType != null) {
      args['mimeType'] = source.mimeType;
    }
    if (textureId != null) {
      args['textureId'] = textureId;
    }

    debugPrint('📤 [Dart] Invoking method channel with args: $args');
    final result = await methodChannel.invokeMethod<Map>('initialize', args);
    debugPrint('📥 [Dart] Method channel result: $result');
    
    if (result != null) {
      final durationMs = result['duration'] as int?;
      final width = result['width'] as int?;
      final height = result['height'] as int?;
      debugPrint('✅ [Dart] Duration: ${durationMs}ms, Size: ${width}x$height');
      
      // Store video dimensions for later retrieval
      _videoWidth = width?.toDouble() ?? 0;
      _videoHeight = height?.toDouble() ?? 0;
      
      if (durationMs != null) {
        return Duration(milliseconds: durationMs);
      }
    }
    debugPrint('⚠️ [Dart] No duration in result');
    return null;
  }
  
  // Video dimensions from last initialize call
  double _videoWidth = 0;
  double _videoHeight = 0;
  double get videoWidth => _videoWidth;
  double get videoHeight => _videoHeight;

  @override
  Future<void> play() async {
    await methodChannel.invokeMethod<void>('play');
  }

  @override
  Future<void> pause() async {
    await methodChannel.invokeMethod<void>('pause');
  }

  @override
  Future<void> stop() async {
    await methodChannel.invokeMethod<void>('stop');
  }

  @override
  Future<Duration?> seekTo(Duration position) async {
    final result = await methodChannel.invokeMethod<Map>('seekTo', {
      'position': position.inMilliseconds,
    });
    if (result != null && result['actualPosition'] != null) {
      return Duration(milliseconds: result['actualPosition'] as int);
    }
    return null;
  }

  @override
  Future<void> setVolume(double volume) async {
    await methodChannel.invokeMethod<void>('setVolume', {'volume': volume});
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    await methodChannel.invokeMethod<void>('setPlaybackSpeed', {'speed': speed});
  }

  @override
  Future<Duration?> getPosition() async {
    final result = await methodChannel.invokeMethod<Map>('getPosition');
    if (result != null && result['position'] != null) {
      return Duration(milliseconds: result['position'] as int);
    }
    return null;
  }

  @override
  Future<Duration?> getDuration() async {
    final result = await methodChannel.invokeMethod<Map>('getDuration');
    if (result != null && result['duration'] != null) {
      return Duration(milliseconds: result['duration'] as int);
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    await methodChannel.invokeMethod<void>('dispose');
  }

  @override
  Future<int?> registerTexture() async {
    final result = await textureChannel.invokeMethod<Map>('registerTexture');
    if (result != null && result['textureId'] != null) {
      return result['textureId'] as int;
    }
    return null;
  }

  @override
  Future<void> unregisterTexture(int textureId) async {
    await textureChannel.invokeMethod<void>('unregisterTexture', {'textureId': textureId});
  }

  @override
  Future<Map<String, dynamic>?> getPerformanceMetrics() async {
    final result = await methodChannel.invokeMethod<Map>('getPerformanceMetrics');
    if (result != null) {
      return Map<String, dynamic>.from(result);
    }
    return null;
  }

  @override
  Stream<PlaybackEvent> get eventStream {
    _eventStream ??= eventChannel.receiveBroadcastStream().map((dynamic event) {
      final map = Map<String, dynamic>.from(event as Map);
      final type = map['type'] as String;

      if (kDebugMode) {
        debugPrint('🟢 [Dart] Event from native: $map');
      }
      
      // Default values
      var position = Duration.zero;
      var duration = Duration.zero;
      var bufferedPosition = Duration.zero;
      var bufferPercentage = 0.0;
      var state = PlayerState.idle;

      if (type == 'progress') {
        position = Duration(milliseconds: map['position'] as int);
        duration = Duration(milliseconds: map['duration'] as int);
        bufferedPosition = Duration(milliseconds: map['bufferedPosition'] as int);
        bufferPercentage = (map['bufferPercentage'] as num).toDouble();
      } else if (type == 'state') {
        final stateStr = map['state'] as String;
        state = PlayerState.values.firstWhere((e) => e.name == stateStr, orElse: () => PlayerState.error);
      }
      if (kDebugMode && type == 'progress') {
        debugPrint('🟢 [Dart] Mapped progress -> pos: ${position.inMilliseconds}ms, dur: ${duration.inMilliseconds}ms');
      }
      
      return PlaybackEvent(
        position: position,
        duration: duration,
        bufferedPosition: bufferedPosition,
        bufferPercentage: bufferPercentage,
        state: state,
      );
    });
    return _eventStream!;
  }
}
