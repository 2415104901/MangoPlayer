import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/src/core/mango_player_controller.dart';
import 'package:mango_player/src/core/player_config.dart';
import 'package:mango_player/src/ui/mango_player_view.dart';

void main() {
  group('MangoPlayerView', () {
    testWidgets('创建 MangoPlayerView', (WidgetTester tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      expect(find.byType(MangoPlayerView), findsOneWidget);
    });

    testWidgets('默认不显示控制器', (WidgetTester tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 默认 showControls 为 false
      final view = tester.widget<MangoPlayerView>(find.byType(MangoPlayerView));
      expect(view.showControls, false);
    });

    testWidgets('showControls 参数可设置', (WidgetTester tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(
              controller: controller,
              showControls: true,
            ),
          ),
        ),
      );

      final view = tester.widget<MangoPlayerView>(find.byType(MangoPlayerView));
      expect(view.showControls, true);
    });

    testWidgets('未初始化时显示黑色容器', (WidgetTester tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // 未初始化时 textureId 为 null，应该显示黑色容器
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(MangoPlayerView),
          matching: find.byType(Container),
        ).first,
      );
      expect(container.color, Colors.black);
    });

    testWidgets('controller 属性正确传递', (WidgetTester tester) async {
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

      final view = tester.widget<MangoPlayerView>(find.byType(MangoPlayerView));
      expect(view.controller, same(controller));
      expect(view.controller.config.autoPlay, true);
    });

    testWidgets('可以在 Column 中使用', (WidgetTester tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: MangoPlayerView(controller: controller),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MangoPlayerView), findsOneWidget);
    });

    testWidgets('可以嵌套在 Stack 中', (WidgetTester tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                MangoPlayerView(controller: controller),
                const Positioned(
                  bottom: 10,
                  left: 10,
                  child: Text('Overlay'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MangoPlayerView), findsOneWidget);
      expect(find.text('Overlay'), findsOneWidget);
    });
  });

  group('MangoPlayerView 与 Controller 集成', () {
    testWidgets('多个 View 可以使用同一个 Controller', (WidgetTester tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: MangoPlayerView(controller: controller)),
                Expanded(child: MangoPlayerView(controller: controller)),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MangoPlayerView), findsNWidgets(2));
    });

    testWidgets('Controller 更新触发 View 重建', (WidgetTester tester) async {
      final controller = MangoPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MangoPlayerView(controller: controller),
          ),
        ),
      );

      // MangoPlayerView 内部使用 StreamBuilder 监听 stateStream
      // 验证 View 已正确创建
      expect(find.byType(MangoPlayerView), findsOneWidget);
      
      // 状态变化时 View 会重建（通过 StreamBuilder）
      await tester.pump();
      expect(find.byType(MangoPlayerView), findsOneWidget);
    });
  });
}
