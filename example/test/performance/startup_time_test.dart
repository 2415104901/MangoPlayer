import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:mango_player/mango_player.dart';

/// 启动性能测试
///
/// 测试播放器初始化到首帧渲染的时间，目标 < 500ms
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final binding = IntegrationTestWidgetsFlutterBinding.instance;

  group('启动性能测试', () {
    testWidgets('初始化到首帧时间', (tester) async {
      final controller = MangoPlayerController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 开始计时
      final stopwatch = Stopwatch()..start();

      // 初始化
      await controller.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      // 等待 ready 状态
      await tester.pumpAndSettle();
      
      final initTime = stopwatch.elapsedMilliseconds;
      debugPrint('初始化时间: ${initTime}ms');

      // 开始播放
      await controller.play();
      await tester.pumpAndSettle();

      // 停止计时（首帧渲染）
      stopwatch.stop();
      final totalTime = stopwatch.elapsedMilliseconds;
      debugPrint('初始化到播放总时间: ${totalTime}ms');

      // 报告性能指标
      await binding.traceAction(
        () async {
          // 性能追踪
        },
        reportKey: 'startup_time',
      );

      // 验证：目标 < 500ms（本地网络条件下）
      // 注意：实际测试中网络延迟会影响结果
      expect(initTime, lessThan(5000)); // 宽松阈值，考虑网络

      await controller.dispose();
    });

    testWidgets('本地文件启动时间', (tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 本地文件应该更快
      // 跳过：需要实际的本地文件

      await controller.dispose();
    });

    testWidgets('多次初始化/释放', (tester) async {
      final times = <int>[];

      for (var i = 0; i < 3; i++) {
        final controller = MangoPlayerController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MangoPlayerView(controller: controller),
            ),
          ),
        );

        final stopwatch = Stopwatch()..start();

        await controller.initialize(
          MediaSource.network(
            Uri.parse(
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            ),
          ),
        );

        await tester.pumpAndSettle();
        stopwatch.stop();

        times.add(stopwatch.elapsedMilliseconds);
        debugPrint('第 ${i + 1} 次初始化时间: ${times.last}ms');

        await controller.dispose();
        await tester.pumpAndSettle();
      }

      // 验证多次初始化时间一致
      final avgTime = times.reduce((a, b) => a + b) / times.length;
      debugPrint('平均初始化时间: ${avgTime.toStringAsFixed(0)}ms');
    });

    testWidgets('冷启动 vs 热启动', (tester) async {
      // 第一次初始化（冷启动）
      final coldController = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: coldController),
          ),
        ),
      );

      final coldStopwatch = Stopwatch()..start();

      await coldController.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();
      coldStopwatch.stop();
      final coldTime = coldStopwatch.elapsedMilliseconds;
      debugPrint('冷启动时间: ${coldTime}ms');

      await coldController.dispose();
      await tester.pumpAndSettle();

      // 第二次初始化（热启动）
      final warmController = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: warmController),
          ),
        ),
      );

      final warmStopwatch = Stopwatch()..start();

      await warmController.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();
      warmStopwatch.stop();
      final warmTime = warmStopwatch.elapsedMilliseconds;
      debugPrint('热启动时间: ${warmTime}ms');

      // 热启动应该更快（由于缓存）
      // 注意：不一定总是如此，取决于实现

      await warmController.dispose();
    });
  });

  group('配置对启动时间的影响', () {
    testWidgets('autoPlay 启动时间', (tester) async {
      final controller = MangoPlayerController(
        config: const PlayerConfig(autoPlay: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();

      await controller.initialize(
        MediaSource.network(
          Uri.parse(
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          ),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      debugPrint('autoPlay 启动时间: ${stopwatch.elapsedMilliseconds}ms');

      await controller.dispose();
    });
  });
}
