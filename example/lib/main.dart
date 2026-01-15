import 'package:flutter/material.dart';
import 'package:mango_player/mango_player.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late MangoPlayerController _controller;
  VideoSource _currentSource = VideoSource.local;
  String _localFilePath = '';
  String _onlineVideoUrl = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  bool _isMuted = false;
  bool _isInitialized = false;
  bool _isSeeking = false;
  double _seekValue = 0.0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = MangoPlayerController(
      config: const PlayerConfig(autoPlay: false),
    );
    _findLocalVideo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _findLocalVideo() async {
    // Try to find common local video locations
    final paths = [
      '/Users/a123/Movies/sample.mp4',
      '/Users/a123/Downloads/sample.mp4',
      '/Users/a123/Desktop/sample.mp4',
      '${Directory.current.path}/test.mp4',
    ];

    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        setState(() {
          _localFilePath = path;
        });
        break;
      }
    }
  }

  Future<void> _selectLocalFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null && path.isNotEmpty) {
          setState(() {
            _localFilePath = path;
          });
          // 自动加载选中的文件
          await _initializePlayer();
        }
      }
    } catch (e) {
      _updateStatus('选择文件失败: $e');
    }
  }

  Future<void> _editOnlineUrl() async {
    final controller = TextEditingController(text: _onlineVideoUrl);

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入在线视频URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/video.mp4',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      setState(() {
        _onlineVideoUrl = url;
      });
      // 自动加载
      await _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final MediaSource source;

      if (_currentSource == VideoSource.online) {
        source = MediaSource.network(_onlineVideoUrl);
        _updateStatus('正在加载在线视频...');
      } else {
        if (_localFilePath.isEmpty) {
          _updateStatus('请先选择视频文件');
          return;
        }
        source = MediaSource.file(_localFilePath);
        _updateStatus('正在加载视频...');
      }

      await _controller.initialize(source);
      setState(() {
        _isInitialized = true;
      });
      _updateStatus('加载成功');
      // 自动开始播放
      await _controller.play();
    } catch (e) {
      _updateStatus('错误: $e');
    }
  }

  void _updateStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
    // 3秒后清除状态消息
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _statusMessage == message) {
        setState(() {
          _statusMessage = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MangoPlayer Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Column(
          children: [
            // Video player - 增大高度比例
            Expanded(
              flex: 3, // 增大视频区域比例
              child: Container(
                color: Colors.black,
                child: Center(
                  child: _localFilePath.isEmpty && _currentSource == VideoSource.local
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library, size: 64, color: Colors.white54),
                            SizedBox(height: 16),
                            Text(
                              '未选择视频',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        )
                      : MangoPlayerView(controller: _controller),
                ),
              ),
            ),

            // Controls - 紧凑布局，无滚动条
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Source selection
                  SegmentedButton<VideoSource>(
                        segments: const [
                          ButtonSegment(
                            value: VideoSource.local,
                            label: Text('本地文件'),
                            icon: Icon(Icons.folder),
                          ),
                          ButtonSegment(
                            value: VideoSource.online,
                            label: Text('在线视频'),
                            icon: Icon(Icons.cloud),
                          ),
                        ],
                        selected: {_currentSource},
                        onSelectionChanged: (Set<VideoSource> newSelection) {
                          setState(() {
                            _currentSource = newSelection.first;
                          });
                        },
                      ),

                      const SizedBox(height: 8),

                      // File selection or URL display - 紧凑布局
                      if (_currentSource == VideoSource.local)
                        Row(
                          children: [
                            const Icon(Icons.movie, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _localFilePath.isEmpty
                                    ? '未选择文件'
                                    : _localFilePath.split('/').last,
                                style: Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.folder_open, size: 18),
                              label: const Text('选择文件'),
                              onPressed: _selectLocalFile,
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.link, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _onlineVideoUrl,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: _editOnlineUrl,
                              tooltip: '编辑URL',
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.play_circle, size: 18),
                              onPressed: _initializePlayer,
                              tooltip: '加载并播放',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),

                      const SizedBox(height: 4),

                      // Playback controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filled(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () async {
                              if (!_isInitialized && _localFilePath.isNotEmpty) {
                                // 如果未初始化但有文件，先初始化
                                await _initializePlayer();
                              } else {
                                await _controller.play();
                                _updateStatus('播放中');
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.pause),
                            onPressed: () {
                              _controller.pause();
                              _updateStatus('已暂停');
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.stop),
                            onPressed: () {
                              _controller.stop();
                              _updateStatus('已停止');
                            },
                          ),
                          const SizedBox(width: 16),
                          // Mute button
                          IconButton.filled(
                            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                            onPressed: () {
                              setState(() {
                                _isMuted = !_isMuted;
                              });
                              _controller.setMuted(_isMuted);
                              _updateStatus(_isMuted ? '已静音' : '取消静音');
                            },
                            tooltip: _isMuted ? '取消静音' : '静音',
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Progress bar with seek support
                      StreamBuilder<PlaybackEvent>(
                        stream: _controller.eventStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data?.position ?? Duration.zero;
                          final duration = snapshot.data?.duration ?? Duration.zero;
                          final state = snapshot.data?.state ?? PlayerState.idle;

                          // Calculate slider value as a ratio (0.0 to 1.0)
                          final durationMs = duration.inMilliseconds.toDouble();
                          final positionMs = position.inMilliseconds.toDouble();
                          
                          // 使用seek时的值，否则使用实际位置
                          final displayValue = _isSeeking 
                              ? _seekValue 
                              : (durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0);

                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                ),
                                child: Slider(
                                  value: displayValue,
                                  onChangeStart: (value) {
                                    setState(() {
                                      _isSeeking = true;
                                      _seekValue = value;
                                    });
                                  },
                                  onChanged: (value) {
                                    setState(() {
                                      _seekValue = value;
                                    });
                                  },
                                  onChangeEnd: (value) {
                                    // 执行seek操作
                                    if (durationMs > 0) {
                                      final seekPosition = Duration(
                                        milliseconds: (value * durationMs).toInt(),
                                      );
                                      _controller.seekTo(seekPosition);
                                    }
                                    setState(() {
                                      _isSeeking = false;
                                    });
                                  },
                                ),
                              ),
                              // 状态和时间显示
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_isSeeking 
                                        ? Duration(milliseconds: (_seekValue * durationMs).toInt())
                                        : position),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  // 状态消息显示在中间
                                  if (_statusMessage.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _statusMessage,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      state.name,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  Text(
                                    _formatDuration(duration),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

enum VideoSource {
  local,
  online,
}
