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
        
        // Get video dimensions for aspect ratio
        final videoWidth = widget.controller.videoWidth;
        final videoHeight = widget.controller.videoHeight;
        final aspectRatio = (videoWidth > 0 && videoHeight > 0)
            ? videoWidth / videoHeight
            : 16.0 / 9.0; // Default aspect ratio
        
        return Container(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Texture(textureId: textureId),
            ),
          ),
        );
      },
    );
  }
}
