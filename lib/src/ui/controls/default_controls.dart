import 'package:flutter/material.dart';
import '../../core/mango_player_controller.dart';
import '../../core/player_state.dart';
import 'play_pause_button.dart';
import 'progress_bar.dart';
import 'volume_control.dart';
import 'time_display.dart';
import 'fullscreen_button.dart';

/// 默认播放控制栏
/// 
/// 提供完整的播放控制功能，包括播放/暂停、进度条、音量控制、
/// 时间显示和全屏切换。
class DefaultControls extends StatefulWidget {
  /// 播放器控制器
  final MangoPlayerController controller;
  
  /// 是否显示音量控制
  final bool showVolumeControl;
  
  /// 是否显示全屏按钮
  final bool showFullscreenButton;
  
  /// 当前是否为全屏状态
  final bool isFullscreen;
  
  /// 全屏切换回调
  final ValueChanged<bool>? onFullscreenToggle;
  
  /// 控制栏背景颜色
  final Color? backgroundColor;
  
  /// 控件图标颜色
  final Color? iconColor;
  
  /// 进度条激活颜色
  final Color? progressColor;
  
  /// 自动隐藏延迟 (设置为 null 禁用自动隐藏)
  final Duration? autoHideDelay;
  
  /// 动画时长
  final Duration animationDuration;

  const DefaultControls({
    Key? key,
    required this.controller,
    this.showVolumeControl = true,
    this.showFullscreenButton = true,
    this.isFullscreen = false,
    this.onFullscreenToggle,
    this.backgroundColor,
    this.iconColor,
    this.progressColor,
    this.autoHideDelay = const Duration(seconds: 3),
    this.animationDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<DefaultControls> createState() => _DefaultControlsState();
}

class _DefaultControlsState extends State<DefaultControls> 
    with SingleTickerProviderStateMixin {
  bool _visible = true;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _scheduleAutoHide() {
    if (widget.autoHideDelay != null) {
      Future.delayed(widget.autoHideDelay!, () {
        if (mounted && _visible) {
          _hideControls();
        }
      });
    }
  }

  void _showControls() {
    if (!_visible) {
      setState(() {
        _visible = true;
      });
      _animationController.forward();
      _scheduleAutoHide();
    } else {
      _scheduleAutoHide();
    }
  }

  void _hideControls() {
    if (_visible) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _visible = false;
          });
        }
      });
    }
  }

  void _toggleControls() {
    if (_visible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor = widget.backgroundColor ??
        Colors.black.withOpacity(0.5);
    final effectiveIconColor = widget.iconColor ?? Colors.white;
    final effectiveProgressColor = widget.progressColor ?? 
        theme.colorScheme.primary;

    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 透明层用于捕获点击事件
          Container(color: Colors.transparent),
          
          // 控制栏
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 底部控制栏
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        effectiveBackgroundColor,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 进度条
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ProgressBar(
                          controller: widget.controller,
                          playedColor: effectiveProgressColor,
                          thumbColor: effectiveProgressColor,
                          onSeekStart: () {
                            // 拖动时暂停自动隐藏
                          },
                          onSeekEnd: () {
                            _scheduleAutoHide();
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 8.0),
                      
                      // 控制按钮行
                      Row(
                        children: [
                          // 播放/暂停按钮
                          PlayPauseButton(
                            controller: widget.controller,
                            size: 40.0,
                            iconColor: effectiveIconColor,
                          ),
                          
                          const SizedBox(width: 8.0),
                          
                          // 时间显示
                          TimeDisplay(
                            controller: widget.controller,
                            textStyle: TextStyle(
                              color: effectiveIconColor,
                              fontSize: 12.0,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // 音量控制
                          if (widget.showVolumeControl)
                            VolumeControl(
                              controller: widget.controller,
                              iconColor: effectiveIconColor,
                              activeColor: effectiveProgressColor,
                              iconSize: 20.0,
                              sliderWidth: 80.0,
                            ),
                          
                          // 全屏按钮
                          if (widget.showFullscreenButton)
                            FullscreenButton(
                              isFullscreen: widget.isFullscreen,
                              onToggle: (isFullscreen) {
                                widget.onFullscreenToggle?.call(isFullscreen);
                              },
                              iconSize: 24.0,
                              iconColor: effectiveIconColor,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 中央播放/暂停按钮 (点击显示)
          if (!_visible)
            StreamBuilder<PlayerState>(
              stream: widget.controller.stateStream,
              initialData: widget.controller.state,
              builder: (context, snapshot) {
                final state = snapshot.data ?? PlayerState.idle;
                if (state == PlayerState.buffering) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }
}
