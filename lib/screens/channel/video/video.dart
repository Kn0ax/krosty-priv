import 'dart:io';

import 'package:aws_ivs_player/aws_ivs_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/screens/channel/video/video_store.dart';
import 'package:krosty/screens/channel/video/vod_player.dart';
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
    return Observer(
      builder: (_) {
        final playbackUrl = widget.videoStore.playbackUrl;
        final isPlayingVod = widget.videoStore.isPlayingVod;
        final streamInfo = widget.videoStore.streamInfo;

        // Show VOD player when playing VOD (uses media_kit)
        if (isPlayingVod) {
          return VodPlayer(videoStore: widget.videoStore);
        }

        // Show black background when offline (overlay handles the UI)
        if (playbackUrl == null && streamInfo == null) {
          return const ColoredBox(color: Colors.black);
        }

        // Show loading state while waiting for playback URL
        if (playbackUrl == null) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        // Show IVS player for live streams
        return IvsVideoPlayer(
          url: playbackUrl,
          controller: widget.videoStore.ivsController,
          loadingWidget: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 48),
                SizedBox(height: 8),
                Text(
                  'Streamer is offline',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          onError: (error) {
            debugPrint('IVS Player error: $error');
          },
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
