import 'package:flutter/material.dart';
import '../core/mango_player_controller.dart';
import '../core/player_state.dart';

class MangoPlayerView extends StatefulWidget {
  final MangoPlayerController controller;
  final bool showControls;

  const MangoPlayerView({
    Key? key,
    required this.controller,
    this.showControls = false,
  }) : super(key: key);

  @override
  State<MangoPlayerView> createState() => _MangoPlayerViewState();
}

class _MangoPlayerViewState extends State<MangoPlayerView> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: widget.controller.stateStream,
      builder: (context, snapshot) {
        final textureId = widget.controller.textureId;
        if (textureId == null) {
          return Container(color: Colors.black);
        }
        return Container(
          color: Colors.black,
          child: Texture(textureId: textureId),
        );
      },
    );
  }
}
