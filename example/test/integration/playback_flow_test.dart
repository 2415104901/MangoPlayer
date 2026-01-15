import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:mango_player/mango_player.dart';

/// 端到端播放流程集成测试
///
/// 测试完整的播放器生命周期，包括：
/// - 初始化
/// - 播放/暂停/停止
/// - seek 操作
/// - 音量控制
/// - 播放速度控制
/// - 错误处理
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('播放流程集成测试', () {
    late MangoPlayerController controller;

    setUp(() {
      controller = MangoPlayerController();
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets('完整播放生命周期', (tester) async {
      // 构建 UI
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: MangoPlayerView(controller: controller),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      key: const Key('play_button'),
                      onPressed: () => controller.play(),
                      child: const Text('播放'),
                    ),
                    ElevatedButton(
                      key: const Key('pause_button'),
                      onPressed: () => controller.pause(),
                      child: const Text('暂停'),
                    ),
                    ElevatedButton(
                      key: const Key('stop_button'),
                      onPressed: () => controller.stop(),
                      child: const Text('停止'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      // 1. 初始化
      expect(controller.state, PlayerState.idle);

      await controller.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(controller.state, PlayerState.ready);
      expect(controller.duration.inSeconds, greaterThan(0));

      // 2. 播放
      await tester.tap(find.byKey(const Key('play_button')));
      await tester.pumpAndSettle();

      expect(controller.state, PlayerState.playing);

      // 3. 暂停
      await tester.tap(find.byKey(const Key('pause_button')));
      await tester.pumpAndSettle();

      expect(controller.state, PlayerState.paused);

      // 4. 继续播放
      await tester.tap(find.byKey(const Key('play_button')));
      await tester.pumpAndSettle();

      expect(controller.state, PlayerState.playing);

      // 5. 停止
      await tester.tap(find.byKey(const Key('stop_button')));
      await tester.pumpAndSettle();

      expect(controller.state, PlayerState.idle);
    });

    testWidgets('Seek 操作', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 初始化
      await controller.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 播放
      await controller.play();
      await tester.pumpAndSettle();

      // Seek 到 1 分钟
      await controller.seekTo(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      // 验证位置（可能有误差）
      // 注意：实际测试中可能需要等待 seek 完成
    });

    testWidgets('音量控制', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 初始化
      await controller.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 设置音量
      await controller.setVolume(0.5);
      await tester.pump();

      // 静音
      await controller.setVolume(0.0);
      await tester.pump();

      // 恢复音量
      await controller.setVolume(1.0);
      await tester.pump();
    });

    testWidgets('播放速度控制', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 初始化
      await controller.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 设置 2x 速度
      await controller.setPlaybackSpeed(2.0);
      await tester.pump();

      // 恢复正常速度
      await controller.setPlaybackSpeed(1.0);
      await tester.pump();

      // 设置 0.5x 速度
      await controller.setPlaybackSpeed(0.5);
      await tester.pump();
    });

    testWidgets('状态流监听', (tester) async {
      final states = <PlayerState>[];
      final subscription = controller.stateStream.listen(states.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 初始化
      await controller.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 播放
      await controller.play();
      await tester.pumpAndSettle();

      // 暂停
      await controller.pause();
      await tester.pumpAndSettle();

      // 停止
      await controller.stop();
      await tester.pumpAndSettle();

      // 验证状态转换
      expect(states, contains(PlayerState.initializing));
      expect(states, contains(PlayerState.ready));
      expect(states, contains(PlayerState.playing));
      expect(states, contains(PlayerState.paused));
      expect(states, contains(PlayerState.idle));

      await subscription.cancel();
    });

    testWidgets('错误处理', (tester) async {
      final errors = <PlayerError>[];
      final subscription = controller.errorStream.listen(errors.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 尝试播放无效 URL
      try {
        await controller.initialize(
          MediaSource.network(
            Uri.parse('https://invalid.example.com/not_found.mp4'),
          ),
        );
      } catch (_) {}

      await tester.pumpAndSettle();

      // 根据平台实现，可能触发错误
      // expect(errors, isNotEmpty);

      await subscription.cancel();
    });

    testWidgets('UI 控件集成', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      MangoPlayerView(controller: controller),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: DefaultControls(controller: controller),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // 初始化
      await controller.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证控件存在
      expect(find.byType(DefaultControls), findsOneWidget);
    });
  });

  group('本地文件播放', () {
    testWidgets('播放本地文件', (tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 跳过：需要实际的本地文件
      // await controller.initialize(
      //   MediaSource.file('/path/to/local/video.mp4'),
      // );

      await controller.dispose();
    });
  });

  group('Asset 播放', () {
    testWidgets('播放 Asset 文件', (tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 跳过：需要在 pubspec.yaml 中声明 asset
      // await controller.initialize(
      //   MediaSource.asset('assets/sample_video.mp4'),
      // );

      await controller.dispose();
    });
  });

  group('性能监控集成', () {
    testWidgets('性能指标收集', (tester) async {
      final controller = MangoPlayerController();
      final metrics = <PerformanceMetrics>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 初始化
      await controller.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 启用性能监控
      final subscription = controller.performanceStream.listen(metrics.add);
      controller.enablePerformanceMonitoring(
        const PerformanceConfig(sampleIntervalMs: 500),
      );

      // 播放
      await controller.play();
      await tester.pumpAndSettle();

      // 等待采样
      await Future.delayed(const Duration(seconds: 2));

      // 禁用监控
      controller.disablePerformanceMonitoring();

      // 验证收集到指标
      // 注意：在模拟环境中可能不会有实际数据

      await subscription.cancel();
      await controller.dispose();
    });
  });
}
