import 'package:flutter/material.dart';
import 'package:mango_player/mango_player.dart';
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

  // Store the scaffold context for dialogs
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    final scaffoldContext = _scaffoldKey.currentContext;
    if (scaffoldContext == null) return;

    final controller = TextEditingController(text: _localFilePath);

    final path = await showDialog<String>(
      context: scaffoldContext,
      builder: (context) => AlertDialog(
        title: const Text('Enter local video path'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '/Users/xxx/videos/sample.mp4',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Load'),
          ),
        ],
      ),
    );

    if (path != null && path.isNotEmpty) {
      setState(() {
        _localFilePath = path;
      });
      // Don't auto-initialize, let user click the load button
      _showMessage('File path updated. Click "Load & Play" to play.');
    }
  }

  Future<void> _editOnlineUrl() async {
    final scaffoldContext = _scaffoldKey.currentContext;
    if (scaffoldContext == null) return;

    final controller = TextEditingController(text: _onlineVideoUrl);

    final url = await showDialog<String>(
      context: scaffoldContext,
      builder: (context) => AlertDialog(
        title: const Text('Enter online video URL'),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Set URL'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      setState(() {
        _onlineVideoUrl = url;
      });
      _showMessage('URL updated. Click "Load & Play" to play.');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final MediaSource source;

      if (_currentSource == VideoSource.online) {
        source = MediaSource.network(_onlineVideoUrl);
        _showMessage('Loading online video...');
      } else {
        if (_localFilePath.isEmpty) {
          _showMessage('Please select a local video file first');
          return;
        }
        source = MediaSource.file(_localFilePath);
        _showMessage('Loading local video...');
      }

      await _controller.initialize(source);
      _showMessage('Video initialized successfully');
    } catch (e) {
      _showMessage('Error: $e');
    }
  }

  void _showMessage(String message) {
    final scaffoldContext = _scaffoldKey.currentContext;
    if (scaffoldContext != null && mounted) {
      ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('MangoPlayer Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Column(
          children: [
            // Video player
            Expanded(
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
                              'No video selected',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        )
                      : MangoPlayerView(controller: _controller),
                ),
              ),
            ),

            // Controls
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Source selection
                  SegmentedButton<VideoSource>(
                    segments: const [
                      ButtonSegment(
                        value: VideoSource.local,
                        label: Text('Local File'),
                        icon: Icon(Icons.folder),
                      ),
                      ButtonSegment(
                        value: VideoSource.online,
                        label: Text('Online Video'),
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

                  const SizedBox(height: 16),

                  // File selection or URL display
                  if (_currentSource == VideoSource.local)
                    ListTile(
                      leading: const Icon(Icons.movie),
                      title: Text(
                        _localFilePath.isEmpty
                            ? 'No file selected'
                            : _localFilePath.split('/').last,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      subtitle: Text(
                        _localFilePath.isEmpty
                            ? 'Click to select a video file'
                            : _localFilePath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: _selectLocalFile,
                      ),
                      onTap: _selectLocalFile,
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: const Text('Online Video URL'),
                      subtitle: Text(
                        _onlineVideoUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _editOnlineUrl,
                        tooltip: 'Edit URL',
                      ),
                      onTap: _editOnlineUrl,
                    ),

                  const SizedBox(height: 8),

                  // Initialize button
                  FilledButton.icon(
                    onPressed: _initializePlayer,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Load & Play Video'),
                  ),

                  const SizedBox(height: 16),

                  // Playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          _controller.play();
                          _showMessage('Playing');
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.pause),
                        onPressed: () {
                          _controller.pause();
                          _showMessage('Paused');
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.stop),
                        onPressed: () {
                          _controller.stop();
                          _showMessage('Stopped');
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
                          _showMessage(_isMuted ? 'Muted' : 'Unmuted');
                        },
                        tooltip: _isMuted ? 'Unmute' : 'Mute',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress
                  StreamBuilder<PlaybackEvent>(
                    stream: _controller.eventStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data?.position ?? Duration.zero;
                      final duration = snapshot.data?.duration ?? Duration.zero;
                      final state = snapshot.data?.state ?? PlayerState.idle;

                      // Calculate slider value as a ratio (0.0 to 1.0)
                      final durationMs = duration.inMilliseconds.toDouble();
                      final positionMs = position.inMilliseconds.toDouble();
                      final sliderValue = durationMs > 0
                          ? (positionMs / durationMs).clamp(0.0, 1.0)
                          : 0.0;

                      return Column(
                        children: [
                          Slider(
                            value: sliderValue,
                            onChanged: (value) {
                              final seekPosition = Duration(
                                milliseconds: (value * durationMs).toInt(),
                              );
                              _controller.seekTo(seekPosition);
                            },
                          ),
                          Text(
                            '${_formatDuration(position)} / ${_formatDuration(duration)} | ${state.name}',
                            style: Theme.of(context).textTheme.bodySmall,
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
