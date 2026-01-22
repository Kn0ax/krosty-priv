import 'package:flutter/material.dart';
import 'package:krosty/screens/channel/video/video_store.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// A video player widget for VOD (Video on Demand) playback using media_kit.
///
/// This widget renders the video surface from media_kit's VideoController,
/// which is managed by [VideoStore]. The store handles all playback controls
/// (play/pause, seek, playback rate) while this widget just displays the video.
class VodPlayer extends StatelessWidget {
  final VideoStore videoStore;

  const VodPlayer({super.key, required this.videoStore});

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: videoStore.vodController,
      // Don't show default controls - we use our custom overlay
      controls: NoVideoControls,
    );
  }
}
