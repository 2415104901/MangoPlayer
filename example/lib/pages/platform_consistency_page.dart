import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:mango_player/mango_player.dart';

/// Platform Consistency Demo Page
/// Demonstrates that MangoPlayer API behaves consistently across all platforms
class PlatformConsistencyPage extends StatefulWidget {
  const PlatformConsistencyPage({super.key});

  @override
  State<PlatformConsistencyPage> createState() => _PlatformConsistencyPageState();
}

class _PlatformConsistencyPageState extends State<PlatformConsistencyPage> {
  MangoPlayerController? _controller;
  final List<String> _logs = [];
  bool _isInitialized = false;
  String _platformName = 'Unknown';

  @override
  void initState() {
    super.initState();
    _detectPlatform();
    _initializePlayer();
  }

  void _detectPlatform() {
    if (Platform.isWindows) {
      _platformName = 'Windows';
    } else if (Platform.isMacOS) {
      _platformName = 'macOS';
    } else if (Platform.isIOS) {
      _platformName = 'iOS';
    } else if (Platform.isAndroid) {
      _platformName = 'Android';
    } else if (Platform.isLinux) {
      _platformName = 'Linux';
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _initializePlayer() async {
    _log('Creating MangoPlayerController...');
    _controller = MangoPlayerController();

    // Listen to state changes
    _controller!.stateStream.listen((state) {
      _log('State changed: ${state.name}');
    });

    // Listen to playback events
    _controller!.eventStream.listen((event) {
      if (event.position.inSeconds % 5 == 0) {
        _log('Progress: ${event.position.inSeconds}s / ${event.duration.inSeconds}s');
      }
    });

    // Listen to errors
    _controller!.errorStream.listen((error) {
      _log('Error: ${error.code.name} - ${error.message}');
    });

    _log('Controller created successfully');
  }

  Future<void> _testInitialize() async {
    _log('Testing initialize()...');
    try {
      await _controller!.initialize(
        MediaSource.network(
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        ),
      );
      _log('Initialize SUCCESS - Duration: ${_controller!.duration.inSeconds}s');
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      _log('Initialize FAILED: $e');
    }
  }

  Future<void> _testPlay() async {
    if (!_isInitialized) {
      _log('Not initialized - call initialize first');
      return;
    }
    _log('Testing play()...');
    try {
      await _controller!.play();
      _log('Play SUCCESS');
    } catch (e) {
      _log('Play FAILED: $e');
    }
  }

  Future<void> _testPause() async {
    if (!_isInitialized) {
      _log('Not initialized - call initialize first');
      return;
    }
    _log('Testing pause()...');
    try {
      await _controller!.pause();
      _log('Pause SUCCESS');
    } catch (e) {
      _log('Pause FAILED: $e');
    }
  }

  Future<void> _testSeek() async {
    if (!_isInitialized) {
      _log('Not initialized - call initialize first');
      return;
    }
    _log('Testing seekTo(30s)...');
    try {
      await _controller!.seekTo(const Duration(seconds: 30));
      _log('Seek SUCCESS - Position: ${_controller!.position.inSeconds}s');
    } catch (e) {
      _log('Seek FAILED: $e');
    }
  }

  Future<void> _testVolume() async {
    if (!_isInitialized) {
      _log('Not initialized - call initialize first');
      return;
    }
    _log('Testing setVolume(0.5)...');
    try {
      await _controller!.setVolume(0.5);
      _log('SetVolume SUCCESS - Volume: ${_controller!.volume}');
    } catch (e) {
      _log('SetVolume FAILED: $e');
    }
  }

  Future<void> _testSpeed() async {
    if (!_isInitialized) {
      _log('Not initialized - call initialize first');
      return;
    }
    _log('Testing setPlaybackSpeed(1.5)...');
    try {
      await _controller!.setPlaybackSpeed(1.5);
      _log('SetPlaybackSpeed SUCCESS - Speed: ${_controller!.playbackSpeed}');
    } catch (e) {
      _log('SetPlaybackSpeed FAILED: $e');
    }
  }

  Future<void> _testStop() async {
    if (!_isInitialized) {
      _log('Not initialized - call initialize first');
      return;
    }
    _log('Testing stop()...');
    try {
      await _controller!.stop();
      _log('Stop SUCCESS');
      setState(() {
        _isInitialized = false;
      });
    } catch (e) {
      _log('Stop FAILED: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Platform Consistency Test - $_platformName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Video preview area
          Container(
            height: 200,
            color: Colors.black,
            child: _isInitialized && _controller != null
                ? MangoPlayerView(controller: _controller!)
                : const Center(
                    child: Text(
                      'Video Preview',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
          ),
          
          // Test buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _testInitialize,
                  child: const Text('Initialize'),
                ),
                ElevatedButton(
                  onPressed: _testPlay,
                  child: const Text('Play'),
                ),
                ElevatedButton(
                  onPressed: _testPause,
                  child: const Text('Pause'),
                ),
                ElevatedButton(
                  onPressed: _testSeek,
                  child: const Text('Seek 30s'),
                ),
                ElevatedButton(
                  onPressed: _testVolume,
                  child: const Text('Volume 50%'),
                ),
                ElevatedButton(
                  onPressed: _testSpeed,
                  child: const Text('Speed 1.5x'),
                ),
                ElevatedButton(
                  onPressed: _testStop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Stop'),
                ),
              ],
            ),
          ),
          
          // Status info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Platform: $_platformName'),
                Text('Initialized: $_isInitialized'),
                if (_controller != null)
                  Text('State: ${_controller!.state.name}'),
              ],
            ),
          ),
          
          const Divider(),
          
          // Logs
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                Color textColor = Colors.black87;
                if (log.contains('SUCCESS')) {
                  textColor = Colors.green;
                } else if (log.contains('FAILED') || log.contains('Error')) {
                  textColor = Colors.red;
                } else if (log.contains('State changed')) {
                  textColor = Colors.blue;
                }
                return Text(
                  log,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: textColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
