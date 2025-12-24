import 'package:flutter/material.dart';
import 'package:mango_player/mango_player.dart';

/// 基础播放器页面
/// 
/// 演示如何使用 MangoPlayer 的基础播放功能和默认 UI 组件。
class BasicPlayerPage extends StatefulWidget {
  /// 测试视频 URL
  final String? videoUrl;

  const BasicPlayerPage({
    Key? key,
    this.videoUrl,
  }) : super(key: key);

  @override
  State<BasicPlayerPage> createState() => _BasicPlayerPageState();
}

class _BasicPlayerPageState extends State<BasicPlayerPage> {
  late MangoPlayerController _controller;
  bool _isFullscreen = false;
  bool _isInitialized = false;

  // 默认测试视频
  static const String _defaultVideoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  void initState() {
    super.initState();
    _controller = MangoPlayerController();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _controller.initialize(
        MediaSource.network(widget.videoUrl ?? _defaultVideoUrl),
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      FullscreenPlayer.enterFullscreen(
        context,
        controller: _controller,
      ).then((_) {
        if (mounted) {
          setState(() {
            _isFullscreen = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('基础播放器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.dispose();
              _controller = MangoPlayerController();
              setState(() {
                _isInitialized = false;
              });
              _initializePlayer();
            },
            tooltip: '重新加载',
          ),
        ],
      ),
      body: Column(
        children: [
          // 视频区域
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _isInitialized
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        MangoPlayerView(controller: _controller),
                        DefaultControls(
                          controller: _controller,
                          isFullscreen: _isFullscreen,
                          onFullscreenToggle: (_) => _toggleFullscreen(),
                        ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          // 视频信息
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '播放器状态',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // 状态流显示
                  StreamBuilder<PlayerState>(
                    stream: _controller.stateStream,
                    initialData: _controller.state,
                    builder: (context, snapshot) {
                      return _buildInfoRow(
                        '状态',
                        _getStateText(snapshot.data ?? PlayerState.idle),
                      );
                    },
                  ),
                  
                  // 播放位置和时长
                  StreamBuilder<PlaybackEvent>(
                    stream: _controller.eventStream,
                    builder: (context, snapshot) {
                      final event = snapshot.data;
                      final position = event?.position ?? _controller.position;
                      final duration = event?.duration ?? _controller.duration;
                      final buffered = event?.bufferedPosition ?? Duration.zero;
                      
                      return Column(
                        children: [
                          _buildInfoRow('播放位置', _formatDuration(position)),
                          _buildInfoRow('总时长', _formatDuration(duration)),
                          _buildInfoRow('已缓冲', _formatDuration(buffered)),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 快捷操作
                  const Text(
                    '快捷操作',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _controller.seekTo(Duration.zero),
                        icon: const Icon(Icons.replay),
                        label: const Text('重头播放'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          final current = _controller.position;
                          _controller.seekTo(current - const Duration(seconds: 10));
                        },
                        icon: const Icon(Icons.replay_10),
                        label: const Text('后退 10 秒'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          final current = _controller.position;
                          _controller.seekTo(current + const Duration(seconds: 10));
                        },
                        icon: const Icon(Icons.forward_10),
                        label: const Text('前进 10 秒'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 播放速度
                  const Text(
                    '播放速度',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                      return ChoiceChip(
                        label: Text('${speed}x'),
                        selected: false,
                        onSelected: (_) {
                          _controller.setPlaybackSpeed(speed);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('播放速度: ${speed}x'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStateText(PlayerState state) {
    switch (state) {
      case PlayerState.idle:
        return '空闲';
      case PlayerState.initializing:
        return '初始化中...';
      case PlayerState.ready:
        return '就绪';
      case PlayerState.playing:
        return '播放中';
      case PlayerState.paused:
        return '已暂停';
      case PlayerState.buffering:
        return '缓冲中...';
      case PlayerState.completed:
        return '播放完成';
      case PlayerState.error:
        return '错误';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
