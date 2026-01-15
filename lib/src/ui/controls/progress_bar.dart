import 'package:flutter/material.dart';
import '../../core/mango_player_controller.dart';
import '../../core/playback_event.dart';

/// 进度条控件
/// 
/// 显示当前播放进度和缓冲进度，支持拖动跳转。
class ProgressBar extends StatefulWidget {
  /// 播放器控制器
  final MangoPlayerController controller;
  
  /// 进度条高度
  final double height;
  
  /// 已播放区域颜色
  final Color? playedColor;
  
  /// 缓冲区域颜色
  final Color? bufferedColor;
  
  /// 背景颜色
  final Color? backgroundColor;
  
  /// 滑块颜色
  final Color? thumbColor;
  
  /// 滑块半径
  final double thumbRadius;
  
  /// 拖动时滑块半径
  final double activeThumbRadius;
  
  /// 是否允许拖动
  final bool allowSeeking;
  
  /// 拖动开始回调
  final VoidCallback? onSeekStart;
  
  /// 拖动结束回调
  final VoidCallback? onSeekEnd;

  const ProgressBar({
    Key? key,
    required this.controller,
    this.height = 4.0,
    this.playedColor,
    this.bufferedColor,
    this.backgroundColor,
    this.thumbColor,
    this.thumbRadius = 6.0,
    this.activeThumbRadius = 8.0,
    this.allowSeeking = true,
    this.onSeekStart,
    this.onSeekEnd,
  }) : super(key: key);

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return StreamBuilder<PlaybackEvent>(
      stream: widget.controller.eventStream,
      builder: (context, snapshot) {
        final event = snapshot.data;
        final duration = event?.duration ?? widget.controller.duration;
        final position = event?.position ?? widget.controller.position;
        final bufferedPosition = event?.bufferedPosition ?? Duration.zero;
        
        final durationMs = duration.inMilliseconds.toDouble();
        final progress = durationMs > 0 
            ? (position.inMilliseconds / durationMs).clamp(0.0, 1.0)
            : 0.0;
        final bufferedProgress = durationMs > 0
            ? (bufferedPosition.inMilliseconds / durationMs).clamp(0.0, 1.0)
            : 0.0;
        
        final displayProgress = _isDragging ? _dragValue : progress;
        
        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: widget.allowSeeking 
                  ? (details) => _onDragStart(details, constraints.maxWidth)
                  : null,
              onHorizontalDragUpdate: widget.allowSeeking
                  ? (details) => _onDragUpdate(details, constraints.maxWidth)
                  : null,
              onHorizontalDragEnd: widget.allowSeeking
                  ? (details) => _onDragEnd(duration)
                  : null,
              onTapUp: widget.allowSeeking
                  ? (details) => _onTapUp(details, constraints.maxWidth, duration)
                  : null,
              child: Container(
                height: widget.activeThumbRadius * 2 + 8,
                alignment: Alignment.center,
                child: SizedBox(
                  height: widget.height + widget.activeThumbRadius * 2,
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, widget.height),
                    painter: _ProgressBarPainter(
                      progress: displayProgress,
                      bufferedProgress: bufferedProgress,
                      height: widget.height,
                      playedColor: widget.playedColor ?? theme.colorScheme.primary,
                      bufferedColor: widget.bufferedColor ?? 
                          theme.colorScheme.primary.withOpacity(0.3),
                      backgroundColor: widget.backgroundColor ?? 
                          theme.colorScheme.onSurface.withOpacity(0.2),
                      thumbColor: widget.thumbColor ?? theme.colorScheme.primary,
                      thumbRadius: _isDragging 
                          ? widget.activeThumbRadius 
                          : widget.thumbRadius,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onDragStart(DragStartDetails details, double width) {
    setState(() {
      _isDragging = true;
      _dragValue = (details.localPosition.dx / width).clamp(0.0, 1.0);
    });
    widget.onSeekStart?.call();
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    setState(() {
      _dragValue = (details.localPosition.dx / width).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(Duration duration) {
    final targetPosition = Duration(
      milliseconds: (_dragValue * duration.inMilliseconds).round(),
    );
    widget.controller.seekTo(targetPosition);
    setState(() {
      _isDragging = false;
    });
    widget.onSeekEnd?.call();
  }

  void _onTapUp(TapUpDetails details, double width, Duration duration) {
    final progress = (details.localPosition.dx / width).clamp(0.0, 1.0);
    final targetPosition = Duration(
      milliseconds: (progress * duration.inMilliseconds).round(),
    );
    widget.controller.seekTo(targetPosition);
  }
}

class _ProgressBarPainter extends CustomPainter {
  final double progress;
  final double bufferedProgress;
  final double height;
  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;
  final Color thumbColor;
  final double thumbRadius;

  _ProgressBarPainter({
    required this.progress,
    required this.bufferedProgress,
    required this.height,
    required this.playedColor,
    required this.bufferedColor,
    required this.backgroundColor,
    required this.thumbColor,
    required this.thumbRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barY = size.height / 2;
    final barRadius = height / 2;
    
    // 背景条
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, barY - height / 2, size.width, height),
        Radius.circular(barRadius),
      ),
      backgroundPaint,
    );
    
    // 缓冲条
    if (bufferedProgress > 0) {
      final bufferedPaint = Paint()
        ..color = bufferedColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barY - height / 2, size.width * bufferedProgress, height),
          Radius.circular(barRadius),
        ),
        bufferedPaint,
      );
    }
    
    // 已播放条
    if (progress > 0) {
      final playedPaint = Paint()
        ..color = playedColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barY - height / 2, size.width * progress, height),
          Radius.circular(barRadius),
        ),
        playedPaint,
      );
    }
    
    // 滑块
    final thumbPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * progress, barY),
      thumbRadius,
      thumbPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        bufferedProgress != oldDelegate.bufferedProgress ||
        height != oldDelegate.height ||
        playedColor != oldDelegate.playedColor ||
        bufferedColor != oldDelegate.bufferedColor ||
        backgroundColor != oldDelegate.backgroundColor ||
        thumbColor != oldDelegate.thumbColor ||
        thumbRadius != oldDelegate.thumbRadius;
  }
}
