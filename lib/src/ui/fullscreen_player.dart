import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/mango_player_controller.dart';
import 'mango_player_view.dart';
import 'controls/default_controls.dart';
import 'controls/fullscreen_button.dart';

/// 全屏播放器组件
/// 
/// 提供全屏播放体验，包含视频画面和默认控制栏。
/// 可以通过 Navigator.push 进入全屏页面。
class FullscreenPlayer extends StatefulWidget {
  /// 播放器控制器
  final MangoPlayerController controller;
  
  /// 是否显示控制栏
  final bool showControls;
  
  /// 背景颜色
  final Color backgroundColor;
  
  /// 控制栏设置
  final bool showVolumeControl;
  final bool showFullscreenButton;
  
  /// 退出全屏回调
  final VoidCallback? onExitFullscreen;

  const FullscreenPlayer({
    Key? key,
    required this.controller,
    this.showControls = true,
    this.backgroundColor = Colors.black,
    this.showVolumeControl = true,
    this.showFullscreenButton = true,
    this.onExitFullscreen,
  }) : super(key: key);

  /// 进入全屏播放
  /// 
  /// 使用此方法以动画方式进入全屏播放页面。
  /// 返回值表示是否成功进入全屏。
  static Future<void> enterFullscreen(
    BuildContext context, {
    required MangoPlayerController controller,
    bool showControls = true,
    bool showVolumeControl = true,
  }) async {
    // 设置横屏和隐藏系统UI
    await FullscreenHelper.enterFullscreen();
    
    if (context.mounted) {
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: FullscreenPlayer(
                controller: controller,
                showControls: showControls,
                showVolumeControl: showVolumeControl,
                onExitFullscreen: () {
                  Navigator.of(context).pop();
                },
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        ),
      );
      
      // 退出时恢复屏幕方向
      await FullscreenHelper.exitFullscreen();
    }
  }

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  @override
  void initState() {
    super.initState();
    // 锁定为横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // 隐藏系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // 恢复屏幕方向和系统UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exitFullscreen() {
    widget.onExitFullscreen?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _exitFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 视频画面
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: MangoPlayerView(
                  controller: widget.controller,
                ),
              ),
            ),
            
            // 控制栏
            if (widget.showControls)
              DefaultControls(
                controller: widget.controller,
                showVolumeControl: widget.showVolumeControl,
                showFullscreenButton: widget.showFullscreenButton,
                isFullscreen: true,
                onFullscreenToggle: (isFullscreen) {
                  if (!isFullscreen) {
                    _exitFullscreen();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 支持竖屏全屏的播放器组件
/// 
/// 用于竖屏视频的全屏播放。
class VerticalFullscreenPlayer extends StatefulWidget {
  /// 播放器控制器
  final MangoPlayerController controller;
  
  /// 是否显示控制栏
  final bool showControls;
  
  /// 背景颜色
  final Color backgroundColor;
  
  /// 视频宽高比 (默认 9:16)
  final double aspectRatio;
  
  /// 退出全屏回调
  final VoidCallback? onExitFullscreen;

  const VerticalFullscreenPlayer({
    Key? key,
    required this.controller,
    this.showControls = true,
    this.backgroundColor = Colors.black,
    this.aspectRatio = 9 / 16,
    this.onExitFullscreen,
  }) : super(key: key);

  @override
  State<VerticalFullscreenPlayer> createState() => 
      _VerticalFullscreenPlayerState();
}

class _VerticalFullscreenPlayerState extends State<VerticalFullscreenPlayer> {
  @override
  void initState() {
    super.initState();
    // 隐藏系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exitFullscreen() {
    widget.onExitFullscreen?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _exitFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 视频画面
            Center(
              child: AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: MangoPlayerView(
                  controller: widget.controller,
                ),
              ),
            ),
            
            // 控制栏
            if (widget.showControls)
              DefaultControls(
                controller: widget.controller,
                showFullscreenButton: true,
                isFullscreen: true,
                onFullscreenToggle: (isFullscreen) {
                  if (!isFullscreen) {
                    _exitFullscreen();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
