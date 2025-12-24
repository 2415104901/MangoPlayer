import 'dart:async';

import '../platform/mango_player_platform_interface.dart';
import 'media_source.dart';
import 'playback_event.dart';
import 'player_config.dart';
import 'player_error.dart';
import 'player_state.dart';

class MangoPlayerController {
  final PlayerConfig config;
  
  MangoPlayerController({
    this.config = const PlayerConfig(),
  });

  final _stateController = StreamController<PlayerState>.broadcast();
  final _errorController = StreamController<PlayerError>.broadcast();
  
  PlayerState _state = PlayerState.idle;
  PlayerState get state => _state;
  
  Stream<PlayerState> get stateStream => _stateController.stream;
  Stream<PlayerError> get errorStream => _errorController.stream;
  Stream<PlaybackEvent> get eventStream => MangoPlayerPlatform.instance.eventStream;

  Duration _position = Duration.zero;
  Duration get position => _position;
  
  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  int? _textureId;
  int? get textureId => _textureId;

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

  Future<void> setPlaybackSpeed(double speed) async {
    await MangoPlayerPlatform.instance.setPlaybackSpeed(speed);
  }

  Future<void> dispose() async {
    if (_textureId != null) {
      await MangoPlayerPlatform.instance.unregisterTexture(_textureId!);
      _textureId = null;
    }
    await MangoPlayerPlatform.instance.dispose();
    await _stateController.close();
    await _errorController.close();
  }
}
