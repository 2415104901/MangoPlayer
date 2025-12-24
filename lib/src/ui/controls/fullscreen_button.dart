import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全屏切换按钮
/// 
/// 切换播放器的全屏状态，支持自定义进入/退出全屏的回调。
class FullscreenButton extends StatelessWidget {
  /// 当前是否为全屏状态
  final bool isFullscreen;
  
  /// 点击回调，参数为是否进入全屏
  final ValueChanged<bool> onToggle;
  
  /// 图标大小
  final double iconSize;
  
  /// 图标颜色
  final Color? iconColor;
  
  /// 进入全屏时是否自动设置横屏
  final bool autoOrientation;

  const FullscreenButton({
    Key? key,
    required this.isFullscreen,
    required this.onToggle,
    this.iconSize = 24.0,
    this.iconColor,
    this.autoOrientation = true,
  }) : super(key: key);

  Future<void> _handleTap() async {
    final newState = !isFullscreen;
    
    if (autoOrientation) {
      if (newState) {
        // 进入全屏：设置为横屏
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        );
      } else {
        // 退出全屏：恢复竖屏
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
        );
      }
    }
    
    onToggle(newState);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.onSurface;

    return IconButton(
      icon: Icon(
        isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
        size: iconSize,
        color: effectiveIconColor,
      ),
      onPressed: _handleTap,
      tooltip: isFullscreen ? '退出全屏' : '全屏',
    );
  }
}

/// 全屏辅助工具类
class FullscreenHelper {
  /// 进入全屏模式
  static Future<void> enterFullscreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// 退出全屏模式
  static Future<void> exitFullscreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// 切换全屏模式
  static Future<bool> toggleFullscreen(bool isCurrentlyFullscreen) async {
    if (isCurrentlyFullscreen) {
      await exitFullscreen();
      return false;
    } else {
      await enterFullscreen();
      return true;
    }
  }
}
