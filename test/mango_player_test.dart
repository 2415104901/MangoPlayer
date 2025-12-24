import 'package:flutter_test/flutter_test.dart';
import 'package:mango_player/mango_player.dart';
import 'package:mango_player/mango_player_platform_interface.dart';
import 'package:mango_player/mango_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMangoPlayerPlatform
    with MockPlatformInterfaceMixin
    implements MangoPlayerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MangoPlayerPlatform initialPlatform = MangoPlayerPlatform.instance;

  test('$MethodChannelMangoPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMangoPlayer>());
  });

  test('getPlatformVersion', () async {
    MangoPlayer mangoPlayerPlugin = MangoPlayer();
    MockMangoPlayerPlatform fakePlatform = MockMangoPlayerPlatform();
    MangoPlayerPlatform.instance = fakePlatform;

    expect(await mangoPlayerPlugin.getPlatformVersion(), '42');
  });
}
