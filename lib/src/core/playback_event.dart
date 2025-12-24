import 'player_state.dart';

class PlaybackEvent {
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final double bufferPercentage;
  final PlayerState state;

  const PlaybackEvent({
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    required this.bufferPercentage,
    required this.state,
  });

  bool get isPlaying => state == PlayerState.playing;
  bool get isBuffering => state == PlayerState.buffering;
}
