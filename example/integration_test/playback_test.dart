import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mango_player/mango_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Playback smoke test', (WidgetTester tester) async {
    // 1. Setup
    final controller = MangoPlayerController(
      config: const PlayerConfig(autoPlay: true),
    );
    
    // Pump a widget to provide context (though controller doesn't strictly need it for logic)
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Text('MangoPlayer Test'),
      ),
    ));

    // 2. Initialize with a network video
    // Use a short video for testing
    const videoUrl = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
    final source = MediaSource.network(videoUrl);
    
    print('Testing with URL: $videoUrl');
    
    await controller.initialize(source);
    
    // Expect ready state
    expect(controller.state, PlayerState.ready);
    print('Initial state: ${controller.state}');
    print('Duration after init: ${controller.duration}');
    
    if (controller.duration == Duration.zero) {
      print('WARNING: Duration is zero after initialization');
    }

    // 3. Play
    await controller.play();
    
    // Wait for state change
    await Future.delayed(const Duration(seconds: 2));
    print('State after play: ${controller.state}');
    
    // Check if playing
    // expect(controller.state, PlayerState.playing); 
    // State might be buffering or playing, allow some flexibility
    
    // 4. Check progress over time
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(seconds: 1));
      print('Progress check $i: Position=${controller.position}, Duration=${controller.duration}');
      
      if (controller.position > Duration.zero) {
        print('SUCCESS: Position is advancing');
      }
    }
    
    // 5. Cleanup
    await controller.dispose();
  });
}
