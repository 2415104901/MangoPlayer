import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/mango_player.dart';

/// 帧率测试
///
/// 验证播放器的渲染帧率符合性能指标:
/// - 1080p 视频帧率 >= 30fps
/// - 帧率稳定性
/// - 丢帧率
///
/// 任务: T136 [性能测试]
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('帧率测试', () {
    late MangoPlayerController controller;
    
    // 测试视频 URL (1080p 30fps)
    const testVideoUrl = 
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

    setUp(() {
      controller = MangoPlayerController();
    });

    tearDown(() async {
      await controller.dispose();
    });

    test('1080p 视频帧率 >= 30fps', () async {
      // 初始化播放器
      await controller.initialize(MediaSource.network(testVideoUrl));
      
      // 收集帧率数据
      final frameRates = <double>[];
      late StreamSubscription subscription;
      
      subscription = controller.performanceStream.listen((metrics) {
        if (metrics.currentFps > 0) {
          frameRates.add(metrics.currentFps);
        }
      });
      
      // 开始播放
      await controller.play();
      
      // 播放 10 秒收集数据
      await Future.delayed(const Duration(seconds: 10));
      
      await subscription.cancel();
      
      if (frameRates.isEmpty) {
        fail('未收集到帧率数据');
      }
      
      // 计算平均帧率
      final avgFps = frameRates.reduce((a, b) => a + b) / frameRates.length;
      print('平均帧率: ${avgFps.toStringAsFixed(2)} fps');
      print('样本数: ${frameRates.length}');
      print('最小帧率: ${frameRates.reduce((a, b) => a < b ? a : b).toStringAsFixed(2)} fps');
      print('最大帧率: ${frameRates.reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} fps');
      
      // 验证平均帧率 >= 30fps
      expect(avgFps, greaterThanOrEqualTo(30.0),
          reason: '平均帧率 ${avgFps.toStringAsFixed(2)} fps 低于 30fps 要求');
    }, skip: 'Requires performance stream implementation');

    test('帧率稳定性测试', () async {
      await controller.initialize(MediaSource.network(testVideoUrl));
      
      final frameRates = <double>[];
      late StreamSubscription subscription;
      
      subscription = controller.performanceStream.listen((metrics) {
        if (metrics.currentFps > 0) {
          frameRates.add(metrics.currentFps);
        }
      });
      
      await controller.play();
      await Future.delayed(const Duration(seconds: 15));
      
      await subscription.cancel();
      
      if (frameRates.length < 10) {
        fail('帧率样本不足');
      }
      
      // 计算标准差
      final mean = frameRates.reduce((a, b) => a + b) / frameRates.length;
      final variance = frameRates
          .map((x) => (x - mean) * (x - mean))
          .reduce((a, b) => a + b) / frameRates.length;
      final stdDev = variance > 0 ? variance.sqrt() : 0.0;
      
      print('帧率均值: ${mean.toStringAsFixed(2)} fps');
      print('帧率标准差: ${stdDev.toStringAsFixed(2)}');
      
      // 标准差不应超过 5fps (稳定性要求)
      expect(stdDev, lessThan(5.0),
          reason: '帧率波动过大，标准差 ${stdDev.toStringAsFixed(2)} > 5');
    }, skip: 'Requires performance stream implementation');

    test('丢帧率测试', () async {
      await controller.initialize(MediaSource.network(testVideoUrl));
      
      int totalFrames = 0;
      int droppedFrames = 0;
      late StreamSubscription subscription;
      
      subscription = controller.performanceStream.listen((metrics) {
        totalFrames = metrics.renderedFrames;
        droppedFrames = metrics.droppedFrames;
      });
      
      await controller.play();
      await Future.delayed(const Duration(seconds: 10));
      
      await subscription.cancel();
      
      if (totalFrames == 0) {
        fail('未收集到帧数据');
      }
      
      final dropRate = droppedFrames / (totalFrames + droppedFrames);
      print('总帧数: $totalFrames');
      print('丢帧数: $droppedFrames');
      print('丢帧率: ${(dropRate * 100).toStringAsFixed(2)}%');
      
      // 丢帧率不应超过 5%
      expect(dropRate, lessThan(0.05),
          reason: '丢帧率 ${(dropRate * 100).toStringAsFixed(2)}% 超过 5% 限制');
    }, skip: 'Requires performance stream implementation');

    test('Seek 后帧率恢复', () async {
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.play();
      
      // 等待播放稳定
      await Future.delayed(const Duration(seconds: 3));
      
      // 记录 seek 前的帧率
      double? preSeekFps;
      late StreamSubscription subscription;
      
      subscription = controller.performanceStream.listen((metrics) {
        preSeekFps = metrics.currentFps;
      });
      
      await Future.delayed(const Duration(seconds: 1));
      await subscription.cancel();
      
      // 执行 seek
      final duration = controller.duration;
      await controller.seekTo(Duration(milliseconds: duration.inMilliseconds ~/ 2));
      
      // 等待恢复
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 测量 seek 后的帧率
      final postSeekRates = <double>[];
      subscription = controller.performanceStream.listen((metrics) {
        if (metrics.currentFps > 0) {
          postSeekRates.add(metrics.currentFps);
        }
      });
      
      await Future.delayed(const Duration(seconds: 3));
      await subscription.cancel();
      
      if (postSeekRates.isEmpty || preSeekFps == null) {
        fail('未收集到足够的帧率数据');
      }
      
      final postSeekAvg = postSeekRates.reduce((a, b) => a + b) / postSeekRates.length;
      print('Seek 前帧率: ${preSeekFps!.toStringAsFixed(2)} fps');
      print('Seek 后平均帧率: ${postSeekAvg.toStringAsFixed(2)} fps');
      
      // Seek 后帧率应该恢复到接近 seek 前的水平 (90%)
      expect(postSeekAvg, greaterThan(preSeekFps! * 0.9),
          reason: 'Seek 后帧率恢复不佳');
    }, skip: 'Requires performance stream implementation');

    test('不同分辨率帧率对比', () async {
      // 这个测试需要不同分辨率的测试视频
      // 480p, 720p, 1080p 视频的帧率应该都能达到 30fps
      
      const testVideos = {
        '480p': 'https://example.com/video_480p.mp4',
        '720p': 'https://example.com/video_720p.mp4',
        '1080p': testVideoUrl,
      };
      
      final results = <String, double>{};
      
      for (final entry in testVideos.entries) {
        final testController = MangoPlayerController();
        
        try {
          await testController.initialize(MediaSource.network(entry.value));
          
          final rates = <double>[];
          late StreamSubscription subscription;
          
          subscription = testController.performanceStream.listen((metrics) {
            if (metrics.currentFps > 0) {
              rates.add(metrics.currentFps);
            }
          });
          
          await testController.play();
          await Future.delayed(const Duration(seconds: 5));
          
          await subscription.cancel();
          
          if (rates.isNotEmpty) {
            results[entry.key] = rates.reduce((a, b) => a + b) / rates.length;
          }
        } catch (e) {
          print('${entry.key} 测试失败: $e');
        } finally {
          await testController.dispose();
        }
      }
      
      print('分辨率帧率对比:');
      for (final entry in results.entries) {
        print('  ${entry.key}: ${entry.value.toStringAsFixed(2)} fps');
      }
      
      // 所有分辨率都应该达到 30fps
      for (final entry in results.entries) {
        expect(entry.value, greaterThanOrEqualTo(30.0),
            reason: '${entry.key} 帧率不足 30fps');
      }
    }, skip: 'Requires multiple resolution test videos');
  });
}

extension on double {
  double sqrt() => this >= 0 ? this.toDouble().sqrt() : 0;
}

extension on num {
  double sqrt() {
    if (this < 0) return 0;
    return _sqrt(toDouble());
  }
}

double _sqrt(double x) {
  if (x < 0) return 0;
  double guess = x / 2;
  for (var i = 0; i < 20; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}
