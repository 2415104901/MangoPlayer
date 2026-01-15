import 'package:flutter/material.dart';
import '../../core/mango_player_controller.dart';

/// 音量控制滑块
/// 
/// 提供音量调节功能，包括静音切换按钮和音量滑块。
class VolumeControl extends StatefulWidget {
  /// 播放器控制器
  final MangoPlayerController controller;
  
  /// 初始音量值 (0.0-1.0)
  final double initialVolume;
  
  /// 图标大小
  final double iconSize;
  
  /// 滑块宽度 (仅在展开模式下使用)
  final double sliderWidth;
  
  /// 图标颜色
  final Color? iconColor;
  
  /// 滑块激活颜色
  final Color? activeColor;
  
  /// 滑块非激活颜色
  final Color? inactiveColor;
  
  /// 是否显示滑块 (否则仅显示静音切换按钮)
  final bool showSlider;
  
  /// 布局方向
  final Axis direction;

  const VolumeControl({
    Key? key,
    required this.controller,
    this.initialVolume = 1.0,
    this.iconSize = 24.0,
    this.sliderWidth = 100.0,
    this.iconColor,
    this.activeColor,
    this.inactiveColor,
    this.showSlider = true,
    this.direction = Axis.horizontal,
  }) : super(key: key);

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  late double _volume;
  double _previousVolume = 1.0;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _volume = widget.initialVolume.clamp(0.0, 1.0);
  }

  IconData _getVolumeIcon() {
    if (_isMuted || _volume == 0) {
      return Icons.volume_off;
    } else if (_volume < 0.3) {
      return Icons.volume_mute;
    } else if (_volume < 0.7) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
    }
  }

  void _toggleMute() {
    setState(() {
      if (_isMuted || _volume == 0) {
        _isMuted = false;
        _volume = _previousVolume > 0 ? _previousVolume : 1.0;
      } else {
        _previousVolume = _volume;
        _isMuted = true;
      }
    });
    widget.controller.setMuted(_isMuted);
    if (!_isMuted) {
      widget.controller.setVolume(_volume);
    }
  }

  void _onVolumeChanged(double value) {
    setState(() {
      _volume = value.clamp(0.0, 1.0);
      _isMuted = _volume == 0;
    });
    widget.controller.setMuted(_isMuted);
    widget.controller.setVolume(_volume);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = widget.iconColor ?? theme.colorScheme.onSurface;
    final effectiveActiveColor = widget.activeColor ?? theme.colorScheme.primary;
    final effectiveInactiveColor = widget.inactiveColor ?? 
        theme.colorScheme.onSurface.withOpacity(0.3);

    final muteButton = IconButton(
      icon: Icon(
        _getVolumeIcon(),
        size: widget.iconSize,
        color: effectiveIconColor,
      ),
      onPressed: _toggleMute,
      tooltip: _isMuted ? '取消静音' : '静音',
    );

    if (!widget.showSlider) {
      return muteButton;
    }

    final slider = SliderTheme(
      data: SliderThemeData(
        activeTrackColor: effectiveActiveColor,
        inactiveTrackColor: effectiveInactiveColor,
        thumbColor: effectiveActiveColor,
        overlayColor: effectiveActiveColor.withOpacity(0.2),
        trackHeight: 3.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
      ),
      child: SizedBox(
        width: widget.direction == Axis.horizontal ? widget.sliderWidth : null,
        height: widget.direction == Axis.vertical ? widget.sliderWidth : null,
        child: widget.direction == Axis.horizontal
            ? Slider(
                value: _isMuted ? 0 : _volume,
                onChanged: _onVolumeChanged,
              )
            : RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: _isMuted ? 0 : _volume,
                  onChanged: _onVolumeChanged,
                ),
              ),
      ),
    );

    if (widget.direction == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          muteButton,
          slider,
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          slider,
          muteButton,
        ],
      );
    }
  }
}
