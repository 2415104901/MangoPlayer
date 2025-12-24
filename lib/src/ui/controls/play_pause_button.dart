import 'package:flutter/material.dart';
import '../../core/mango_player_controller.dart';
import '../../core/player_state.dart';

/// 播放/暂停按钮组件
/// 
/// 根据当前播放状态自动切换播放和暂停图标，点击时执行相应的操作。
class PlayPauseButton extends StatelessWidget {
  /// 播放器控制器
  final MangoPlayerController controller;
  
  /// 按钮大小
  final double size;
  
  /// 图标颜色
  final Color? iconColor;
  
  /// 背景颜色
  final Color? backgroundColor;
  
  /// 缓冲时显示加载指示器
  final bool showBufferingIndicator;

  const PlayPauseButton({
    Key? key,
    required this.controller,
    this.size = 48.0,
    this.iconColor,
    this.backgroundColor,
    this.showBufferingIndicator = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: controller.stateStream,
      initialData: controller.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? PlayerState.idle;
        
        // 缓冲状态显示加载指示器
        if (showBufferingIndicator && state == PlayerState.buffering) {
          return SizedBox(
            width: size,
            height: size,
            child: Padding(
              padding: EdgeInsets.all(size * 0.2),
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(
                  iconColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }
        
        final isPlaying = state == PlayerState.playing;
        final isEnabled = state != PlayerState.idle && 
                          state != PlayerState.initializing &&
                          state != PlayerState.error;
        
        return Material(
          color: backgroundColor ?? Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isEnabled ? () => _onTap(isPlaying) : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: size * 0.6,
                color: isEnabled 
                    ? (iconColor ?? Theme.of(context).colorScheme.onSurface)
                    : (iconColor ?? Theme.of(context).colorScheme.onSurface).withOpacity(0.5),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onTap(bool isPlaying) {
    if (isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }
}
