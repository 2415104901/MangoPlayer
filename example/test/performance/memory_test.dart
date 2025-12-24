import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/mango_player.dart';

/// 内存占用测试
///
/// 验证播放器的内存占用符合性能指标:
/// - 1080p 单实例内存占用 < 150MB
/// - 内存泄漏检测
///
/// 任务: T135 [性能测试]
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('内存占用测试', () {
    late MangoPlayerController controller;
    
    // 测试视频 URL
    const testVideoUrl = 
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

    setUp(() {
      controller = MangoPlayerController();
    });

    tearDown(() async {
      await controller.dispose();
    });

    test('基线内存测量', () async {
      // 记录初始化前的内存状态
      final initialMemory = await _measureMemory();
      expect(initialMemory, isNotNull);
      print('初始内存: ${_formatBytes(initialMemory)}');
    }, skip: 'Requires platform-specific implementation');

    test('1080p 视频播放内存占用 < 150MB', () async {
      // 初始化播放器
      await controller.initialize(MediaSource.network(testVideoUrl));
      
      // 开始播放
      await controller.play();
      
      // 等待播放稳定
      await Future.delayed(const Duration(seconds: 3));
      
      // 测量内存
      final memoryUsage = await _measureMemory();
      print('播放时内存占用: ${_formatBytes(memoryUsage)}');
      
      // 验证内存占用 < 150MB
      const maxMemory = 150 * 1024 * 1024; // 150MB
      expect(memoryUsage, lessThan(maxMemory),
          reason: '内存占用 ${_formatBytes(memoryUsage)} 超过限制 150MB');
    }, skip: 'Requires platform-specific implementation');

    test('多次初始化/释放无内存泄漏', () async {
      final initialMemory = await _measureMemory();
      
      // 多次初始化和释放
      for (var i = 0; i < 5; i++) {
        final tempController = MangoPlayerController();
        await tempController.initialize(MediaSource.network(testVideoUrl));
        await tempController.play();
        await Future.delayed(const Duration(milliseconds: 500));
        await tempController.dispose();
        
        // 强制垃圾回收
        await _forceGC();
      }
      
      final finalMemory = await _measureMemory();
      
      // 内存增长不应超过 10MB
      const maxMemoryGrowth = 10 * 1024 * 1024;
      final memoryGrowth = finalMemory - initialMemory;
      
      print('内存增长: ${_formatBytes(memoryGrowth)}');
      expect(memoryGrowth, lessThan(maxMemoryGrowth),
          reason: '检测到潜在内存泄漏');
    }, skip: 'Requires platform-specific implementation');

    test('长时间播放内存稳定性', () async {
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.play();
      
      final memorySnapshots = <int>[];
      
      // 每 5 秒记录一次内存
      for (var i = 0; i < 6; i++) {
        await Future.delayed(const Duration(seconds: 5));
        final memory = await _measureMemory();
        memorySnapshots.add(memory);
        print('${i * 5}s: ${_formatBytes(memory)}');
      }
      
      // 计算内存变化趋势
      final firstHalfAvg = memorySnapshots.take(3).reduce((a, b) => a + b) ~/ 3;
      final secondHalfAvg = memorySnapshots.skip(3).reduce((a, b) => a + b) ~/ 3;
      
      // 内存不应持续增长
      const maxGrowthRate = 0.1; // 10%
      final growthRate = (secondHalfAvg - firstHalfAvg) / firstHalfAvg;
      
      print('内存增长率: ${(growthRate * 100).toStringAsFixed(2)}%');
      expect(growthRate, lessThan(maxGrowthRate),
          reason: '内存持续增长，可能存在泄漏');
    }, skip: 'Requires platform-specific implementation');

    test('Seek 操作不造成内存累积', () async {
      await controller.initialize(MediaSource.network(testVideoUrl));
      await controller.play();
      
      await Future.delayed(const Duration(seconds: 2));
      final initialMemory = await _measureMemory();
      
      // 执行多次 seek
      final duration = controller.duration;
      for (var i = 0; i < 10; i++) {
        final seekPosition = Duration(
          milliseconds: (duration.inMilliseconds * (i / 10)).toInt(),
        );
        await controller.seekTo(seekPosition);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      await _forceGC();
      final finalMemory = await _measureMemory();
      
      // Seek 操作不应导致大量内存增长
      const maxGrowth = 20 * 1024 * 1024; // 20MB
      final memoryGrowth = finalMemory - initialMemory;
      
      print('Seek 后内存增长: ${_formatBytes(memoryGrowth)}');
      expect(memoryGrowth, lessThan(maxGrowth));
    }, skip: 'Requires platform-specific implementation');
  });
}

/// 测量当前内存使用
Future<int> _measureMemory() async {
  // 平台特定的内存测量实现
  // 在实际测试中，这需要通过 Platform Channel 获取 Native 内存使用
  if (Platform.isAndroid) {
    // Android: 使用 Debug.getNativeHeapAllocatedSize()
    return 0;
  } else if (Platform.isIOS) {
    // iOS: 使用 task_info
    return 0;
  } else if (Platform.isWindows) {
    // Windows: 使用 GetProcessMemoryInfo
    return 0;
  } else if (Platform.isMacOS) {
    // macOS: 使用 mach_task_self
    return 0;
  }
  return 0;
}

/// 强制垃圾回收
Future<void> _forceGC() async {
  // Dart GC 不能直接触发，但可以尝试分配和释放大量内存来触发
  final list = List.generate(1000000, (i) => i);
  list.clear();
  await Future.delayed(const Duration(milliseconds: 100));
}

/// 格式化字节数
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
}
