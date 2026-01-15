import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mango_player/mango_player.dart';

/// Cross-Platform API Consistency Tests
/// These tests verify that MangoPlayer API behaves identically across all platforms
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Platform API Consistency Tests', () {
    late MangoPlayerController controller;

    setUp(() {
      controller = MangoPlayerController();
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets('Initial state is idle', (tester) async {
      expect(controller.state, equals(PlayerState.idle));
      expect(controller.position, equals(Duration.zero));
      expect(controller.duration, equals(Duration.zero));
      expect(controller.volume, equals(1.0));
      expect(controller.playbackSpeed, equals(1.0));
    });

    testWidgets('Initialize changes state to ready', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      
      expect(controller.state, equals(PlayerState.ready));
      expect(controller.duration.inSeconds, greaterThan(0));
    });

    testWidgets('Play changes state to playing', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.play();
      
      expect(controller.state, equals(PlayerState.playing));
    });

    testWidgets('Pause changes state to paused', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.play();
      await controller.pause();
      
      expect(controller.state, equals(PlayerState.paused));
    });

    testWidgets('SeekTo updates position', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.seekTo(const Duration(seconds: 30));
      
      // Allow some tolerance for seek accuracy
      expect(controller.position.inSeconds, closeTo(30, 2));
    });

    testWidgets('SetVolume updates volume', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.setVolume(0.5);
      
      expect(controller.volume, equals(0.5));
    });

    testWidgets('SetPlaybackSpeed updates playback speed', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.setPlaybackSpeed(1.5);
      
      expect(controller.playbackSpeed, equals(1.5));
    });

    testWidgets('Stop resets to idle state', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.play();
      await controller.stop();
      
      expect(controller.state, equals(PlayerState.idle));
    });

    testWidgets('MediaSource.network creates correct source', (tester) async {
      final source = MediaSource.network(
        'https://example.com/video.mp4',
        headers: {'Authorization': 'Bearer token'},
      );
      
      expect(source.type, equals(MediaSourceType.network));
      expect(source.uri.toString(), equals('https://example.com/video.mp4'));
      expect(source.headers?['Authorization'], equals('Bearer token'));
    });

    testWidgets('MediaSource.file creates correct source', (tester) async {
      final source = MediaSource.file('/path/to/video.mp4');
      
      expect(source.type, equals(MediaSourceType.file));
      expect(source.uri.path, contains('video.mp4'));
    });

    testWidgets('MediaSource.asset creates correct source', (tester) async {
      final source = MediaSource.asset('assets/video.mp4');
      
      expect(source.type, equals(MediaSourceType.asset));
    });

    testWidgets('Volume is clamped to 0.0-1.0 range', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      
      await controller.setVolume(-0.5);
      expect(controller.volume, equals(0.0));
      
      await controller.setVolume(1.5);
      expect(controller.volume, equals(1.0));
    });

    testWidgets('Playback speed is clamped to 0.5-2.0 range', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      
      await controller.setPlaybackSpeed(0.1);
      expect(controller.playbackSpeed, equals(0.5));
      
      await controller.setPlaybackSpeed(3.0);
      expect(controller.playbackSpeed, equals(2.0));
    });

    testWidgets('State stream emits correct states', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      final states = <PlayerState>[];
      
      controller.stateStream.listen((state) {
        states.add(state);
      });
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.play();
      await controller.pause();
      await controller.stop();
      
      // Wait for async events
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(states, contains(PlayerState.initializing));
      expect(states, contains(PlayerState.ready));
      expect(states, contains(PlayerState.playing));
      expect(states, contains(PlayerState.paused));
      expect(states, contains(PlayerState.idle));
    });

    testWidgets('Event stream provides playback progress', (tester) async {
      final testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      PlaybackEvent? lastEvent;
      
      controller.eventStream.listen((event) {
        lastEvent = event;
      });
      
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.play();
      
      // Wait for progress event
      await Future.delayed(const Duration(seconds: 1));
      
      expect(lastEvent, isNotNull);
      expect(lastEvent!.duration.inSeconds, greaterThan(0));
    });
  });
}
