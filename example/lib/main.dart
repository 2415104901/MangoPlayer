import 'package:flutter/material.dart';
import 'package:mango_player/mango_player.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = MangoPlayerController(
      config: const PlayerConfig(autoPlay: true),
    );
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _controller.initialize(
        MediaSource.network('https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
      );
    } catch (e) {
      print('Error initializing player: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MangoPlayer Example'),
        ),
        body: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: MangoPlayerView(controller: _controller),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _controller.play(),
                ),
                IconButton(
                  icon: const Icon(Icons.pause),
                  onPressed: () => _controller.pause(),
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () => _controller.stop(),
                ),
              ],
            ),
            StreamBuilder<PlaybackEvent>(
              stream: _controller.eventStream,
              builder: (context, snapshot) {
                final position = snapshot.data?.position ?? Duration.zero;
                final duration = snapshot.data?.duration ?? Duration.zero;
                return Text('${position.inSeconds} / ${duration.inSeconds} s');
              },
            ),
          ],
        ),
      ),
    );
  }
}
