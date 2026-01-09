import 'dart:io';

import 'package:flutter/material.dart';
import 'package:krosty/screens/channel/video/video_store.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit;
import 'package:simple_pip_mode/simple_pip.dart';

/// Creates a native video player widget that shows a channel's video stream.
class Video extends StatefulWidget {
  final VideoStore videoStore;

  const Video({super.key, required this.videoStore});

  @override
  State<Video> createState() => _VideoState();
}

class _VideoState extends State<Video> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> didChangeAppLifecycleState(
    AppLifecycleState lifecycleState,
  ) async {
    if (Platform.isAndroid &&
        !await SimplePip.isAutoPipAvailable &&
        lifecycleState == AppLifecycleState.inactive &&
        widget.videoStore.settingsStore.showVideo) {
      widget.videoStore.requestPictureInPicture();
    }
  }

  @override
  Widget build(BuildContext context) {
    return media_kit.MaterialVideoControlsTheme(
      normal: const media_kit.MaterialVideoControlsThemeData(
        // Hide default controls - we use custom overlay
        bottomButtonBar: [],
        topButtonBar: [],
        displaySeekBar: false,
        volumeGesture: false,
        brightnessGesture: false,
        seekGesture: false,
      ),
      fullscreen: const media_kit.MaterialVideoControlsThemeData(
        // Hide default controls in fullscreen too
        bottomButtonBar: [],
        topButtonBar: [],
        displaySeekBar: false,
        volumeGesture: false,
        brightnessGesture: false,
        seekGesture: false,
      ),
      child: media_kit.Video(
        controller: widget.videoStore.videoController,
        // Fill the available space while maintaining aspect ratio
        fit: BoxFit.contain,
        // Black background for letterboxing
        fill: Colors.black,
        // Disable default controls - we have custom overlay
        controls: media_kit.NoVideoControls,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
