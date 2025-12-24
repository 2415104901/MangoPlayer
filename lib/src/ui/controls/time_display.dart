import 'package:flutter/material.dart';
import '../../core/mango_player_controller.dart';
import '../../core/playback_event.dart';

/// 时间显示组件
/// 
/// 显示当前播放位置和总时长，格式为 "00:00 / 00:00"。
class TimeDisplay extends StatelessWidget {
  /// 播放器控制器
  final MangoPlayerController controller;
  
  /// 文字样式
  final TextStyle? textStyle;
  
  /// 分隔符 (默认 " / ")
  final String separator;
  
  /// 是否显示总时长
  final bool showDuration;
  
  /// 是否显示毫秒
  final bool showMilliseconds;

  const TimeDisplay({
    Key? key,
    required this.controller,
    this.textStyle,
    this.separator = ' / ',
    this.showDuration = true,
    this.showMilliseconds = false,
  }) : super(key: key);

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final milliseconds = duration.inMilliseconds.remainder(1000);

    if (hours > 0) {
      if (showMilliseconds) {
        return '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}.'
            '${(milliseconds ~/ 10).toString().padLeft(2, '0')}';
      }
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    if (showMilliseconds) {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}.'
          '${(milliseconds ~/ 10).toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextStyle = textStyle ?? 
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return StreamBuilder<PlaybackEvent>(
      stream: controller.eventStream,
      builder: (context, snapshot) {
        final event = snapshot.data;
        final position = event?.position ?? controller.position;
        final duration = event?.duration ?? controller.duration;

        final positionText = _formatDuration(position);
        final durationText = _formatDuration(duration);

        if (!showDuration) {
          return Text(positionText, style: effectiveTextStyle);
        }

        return Text(
          '$positionText$separator$durationText',
          style: effectiveTextStyle,
        );
      },
    );
  }
}
