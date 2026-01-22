import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/screens/channel/video/stream_info_bar.dart';
import 'package:krosty/screens/channel/video/video_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/theme.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/utils/context_extensions.dart';
import 'package:krosty/utils/modal_bottom_sheet.dart';
import 'package:krosty/widgets/live_indicator.dart';
import 'package:krosty/widgets/section_header.dart';
import 'package:krosty/widgets/uptime.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:provider/provider.dart';

/// Creates a widget containing controls which enable interactions with an underlying [Video] widget.
class VideoOverlay extends StatelessWidget {
  final VideoStore videoStore;
  final ChatStore chatStore;
  final SettingsStore settingsStore;

  const VideoOverlay({
    super.key,
    required this.videoStore,
    required this.chatStore,
    required this.settingsStore,
  });

  static const _iconShadow = [
    Shadow(
      offset: Offset(0, 1),
      blurRadius: 4,
      color: Color.fromRGBO(0, 0, 0, 0.3),
    ),
  ];

  static const _textShadow = [
    Shadow(
      offset: Offset(0, 1),
      blurRadius: 4,
      color: Color.fromRGBO(0, 0, 0, 0.3),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context
        .watch<KrostyThemes>()
        .dark
        .colorScheme
        .onSurface;

    // Check if playing VOD (offline channel with playback)
    final isPlayingVod = videoStore.isPlayingVod;

    final backButton = IconButton(
      tooltip: 'Back',
      icon: Icon(
        Icons.adaptive.arrow_back_rounded,
        color: surfaceColor,
        shadows: _iconShadow,
      ),
      onPressed: Navigator.of(context).pop,
    );

    final chatOverlayButton = Observer(
      builder: (_) => IconButton(
        tooltip: videoStore.settingsStore.fullScreenChatOverlay
            ? 'Hide chat overlay'
            : 'Show chat overlay',
        onPressed: () => videoStore.settingsStore.fullScreenChatOverlay =
            !videoStore.settingsStore.fullScreenChatOverlay,
        icon: videoStore.settingsStore.fullScreenChatOverlay
            ? Icon(Icons.chat_rounded, shadows: _iconShadow)
            : Icon(Icons.chat_outlined, shadows: _iconShadow),
        color: surfaceColor,
      ),
    );

    final videoSettingsButton = IconButton(
      icon: Icon(Icons.settings, shadows: _iconShadow),
      color: surfaceColor,
      onPressed: () {
        videoStore.updateStreamQualities();
        showModalBottomSheetWithProperFocus(
          context: context,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                'Stream quality',
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                isFirst: true,
              ),
              Flexible(
                child: Observer(
                  builder: (context) => ListView(
                    shrinkWrap: true,
                    primary: false,
                    children: videoStore.availableStreamQualities
                        .map(
                          (quality) => ListTile(
                            leading: quality == 'Auto'
                                ? const Icon(Icons.auto_awesome_rounded)
                                : const Icon(Icons.high_quality_rounded),
                            trailing: videoStore.streamQuality == quality
                                ? const Icon(Icons.check_rounded)
                                : null,
                            title: Text(quality),
                            subtitle: quality == 'Auto'
                                ? const Text('Adjusts based on connection')
                                : null,
                            onTap: () {
                              videoStore.setStreamQuality(quality);
                              Navigator.pop(context);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    final refreshButton = Tooltip(
      message: 'Refresh',
      preferBelow: false,
      child: IconButton(
        icon: Icon(
          Icons.refresh_rounded,
          color: surfaceColor,
          shadows: _iconShadow,
        ),
        onPressed: videoStore.handleRefresh,
      ),
    );

    final fullScreenButton = Tooltip(
      message: videoStore.settingsStore.fullScreen
          ? 'Exit fullscreen mode'
          : 'Enter fullscreen mode',
      preferBelow: false,
      child: IconButton(
        icon: Icon(
          videoStore.settingsStore.fullScreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          color: surfaceColor,
          shadows: _iconShadow,
        ),
        onPressed: () => videoStore.settingsStore.fullScreen =
            !videoStore.settingsStore.fullScreen,
      ),
    );

    final rotateButton = Tooltip(
      message: context.isPortrait
          ? 'Enter landscape mode'
          : 'Exit landscape mode',
      preferBelow: false,
      child: IconButton(
        icon: Icon(
          Icons.screen_rotation_rounded,
          color: surfaceColor,
          shadows: _iconShadow,
        ),
        onPressed: () async {
          if (context.isPortrait) {
            // Detect physical device tilt to rotate to optimal orientation
            final physicalOrientation =
                await NativeDeviceOrientationCommunicator().orientation(
                  useSensor: true,
                );

            // Map native orientation to Flutter's DeviceOrientation
            // iOS: native landscapeLeft = notch left, needs swap to Flutter's landscapeRight
            // Android: direct mapping works correctly
            final needsSwap = Platform.isIOS;

            if (physicalOrientation == NativeDeviceOrientation.landscapeLeft) {
              SystemChrome.setPreferredOrientations([
                needsSwap
                    ? DeviceOrientation.landscapeRight
                    : DeviceOrientation.landscapeLeft,
              ]);
            } else if (physicalOrientation ==
                NativeDeviceOrientation.landscapeRight) {
              SystemChrome.setPreferredOrientations([
                needsSwap
                    ? DeviceOrientation.landscapeLeft
                    : DeviceOrientation.landscapeRight,
              ]);
            } else {
              // Not tilted to landscape yet, allow both
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
            }
          } else {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
            SystemChrome.setPreferredOrientations([]);
          }
        },
      ),
    );

    return Observer(
      builder: (context) {
        final streamInfo = videoStore.streamInfo;
        final offlineChannelInfo = videoStore.offlineChannelInfo;

        // Top gradient - fades from top to bottom, covers top cluster area
        final topGradient = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black, // Solid black for controls
              Colors.black.withValues(alpha: 0.95), // Strong coverage
              Colors.black.withValues(alpha: 0.88), // Still very strong
              Colors.black.withValues(alpha: 0.78), // Strong transition
              Colors.black.withValues(alpha: 0.65), // Begin smooth fade
              Colors.black.withValues(alpha: 0.48), // Faster fade
              Colors.black.withValues(alpha: 0.32), // Quick transition
              Colors.black.withValues(alpha: 0.18), // Rapid fade
              Colors.black.withValues(alpha: 0.08), // Very light
              Colors.black.withValues(alpha: 0.02), // Nearly gone
              Colors.transparent, // Transparent end
            ],
            stops: [
              0.0, // Top: Full black - solid area for controls
              0.1, // Maintain strong coverage for readability
              0.2, // Still strong black
              0.3, // Begin gradual fade
              0.42, // Smooth transition
              0.52, // Faster fade point
              0.62, // Quick transition
              0.7, // Rapid fade
              0.8, // Very light
              0.9, // Nearly gone
              1.0, // Bottom: Fully transparent
            ],
          ),
        );

        // Bottom gradient - fades from bottom to top, covers bottom cluster area
        final bottomGradient = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black, // Solid black for controls
              Colors.black.withValues(alpha: 0.95), // Strong coverage
              Colors.black.withValues(alpha: 0.88), // Still very strong
              Colors.black.withValues(alpha: 0.78), // Strong transition
              Colors.black.withValues(alpha: 0.65), // Begin smooth fade
              Colors.black.withValues(alpha: 0.48), // Faster fade
              Colors.black.withValues(alpha: 0.32), // Quick transition
              Colors.black.withValues(alpha: 0.18), // Rapid fade
              Colors.black.withValues(alpha: 0.08), // Very light
              Colors.black.withValues(alpha: 0.02), // Nearly gone
              Colors.transparent, // Transparent end
            ],
            stops: [
              0.0, // Bottom: Full black - solid area for controls
              0.1, // Maintain strong coverage for readability
              0.2, // Still strong black
              0.3, // Begin gradual fade
              0.42, // Smooth transition
              0.52, // Faster fade point
              0.62, // Quick transition
              0.7, // Rapid fade
              0.8, // Very light
              0.9, // Nearly gone
              1.0, // Top: Fully transparent
            ],
          ),
        );

        // Show minimal overlay when offline and not playing VOD
        if (streamInfo == null && !isPlayingVod) {
          final lastVod = videoStore.lastVod;
          final streamerName =
              offlineChannelInfo?.displayName ?? offlineChannelInfo?.slug ?? '';

          return Stack(
            children: [
              // Top gradient behind top cluster
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: Container(decoration: topGradient),
              ),
              // Bottom gradient behind bottom cluster
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(decoration: bottomGradient),
              ),
              // Center content - offline message and VOD button
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tv_off,
                        color: surfaceColor.withValues(alpha: 0.7),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Streamer is offline',
                        style: TextStyle(
                          color: surfaceColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: _textShadow,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        streamerName.isNotEmpty
                            ? '$streamerName is currently offline'
                            : 'This streamer is currently offline',
                        style: TextStyle(
                          color: surfaceColor.withValues(alpha: 0.6),
                          fontSize: 13,
                          shadows: _textShadow,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (lastVod != null) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: videoStore.playLastVod,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Watch Last VOD'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                        if (lastVod.title.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            lastVod.title,
                            style: TextStyle(
                              color: surfaceColor.withValues(alpha: 0.4),
                              fontSize: 11,
                              shadows: _textShadow,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              // Top bar - back button and stream info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          backButton,
                          if (offlineChannelInfo != null)
                            Flexible(
                              child: StreamInfoBar(
                                offlineChannelInfo: offlineChannelInfo,
                                displayName: chatStore.displayName,
                                showUptime: false,
                                showViewerCount: false,
                                showOfflineIndicator: false,
                                textColor: surfaceColor,
                                isOffline: true,
                                overrideStreamTitle: chatStore.streamTitle,
                                overrideCategory: chatStore.streamCategory,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (videoStore.settingsStore.fullScreen &&
                      context.isLandscape)
                    chatOverlayButton,
                ],
              ),
              // Bottom bar - utility buttons
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    refreshButton,
                    if (!isIPad()) rotateButton,
                    if (context.isLandscape) fullScreenButton,
                  ],
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            // Top gradient behind top cluster
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100, // Covers top area around controls (extended)
              child: Container(decoration: topGradient),
            ),
            // Bottom gradient behind bottom cluster
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80, // Covers bottom area around controls
              child: Container(decoration: bottomGradient),
            ),
            // Content
            Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            backButton,
                            Flexible(
                              child: isPlayingVod
                                  ? StreamInfoBar(
                                      offlineChannelInfo: offlineChannelInfo,
                                      displayName: chatStore.displayName,
                                      showUptime: false,
                                      showViewerCount: false,
                                      showOfflineIndicator: false,
                                      textColor: surfaceColor,
                                      isOffline:
                                          true, // Use offlineChannelInfo for profile pic
                                      overrideStreamTitle:
                                          videoStore.lastVod?.title,
                                    )
                                  : StreamInfoBar(
                                      streamInfo: streamInfo,
                                      showUptime: false,
                                      showViewerCount: false,
                                      textColor: surfaceColor,
                                      overrideStreamTitle:
                                          chatStore.streamTitle,
                                      overrideCategory:
                                          chatStore.streamCategory,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (videoStore.settingsStore.fullScreen &&
                        context.isLandscape)
                      chatOverlayButton,
                    // Hide settings when playing VOD (uses fixed quality)
                    if (!isPlayingVod && (!Platform.isIOS || isIPad()))
                      videoSettingsButton,
                  ],
                ),
                Center(
                  child: Tooltip(
                    message: videoStore.paused ? 'Play' : 'Pause',
                    preferBelow: false,
                    child: IconButton(
                      iconSize: 56,
                      icon: Icon(
                        videoStore.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: surfaceColor,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 3),
                            blurRadius: 8,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                      onPressed: videoStore.handlePausePlay,
                    ),
                  ),
                ),
                // VOD controls (seekbar, time, playback rate) or live stats
                if (isPlayingVod)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _VodControls(
                      videoStore: videoStore,
                      surfaceColor: surfaceColor,
                      textShadow: _textShadow,
                      iconShadow: _iconShadow,
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              spacing: 8,
                              children: [
                                Tooltip(
                                  message: 'Stream uptime',
                                  preferBelow: false,
                                  triggerMode: TooltipTriggerMode.tap,
                                  child: Row(
                                    spacing: 6,
                                    children: [
                                      const LiveIndicator(),
                                      Uptime(
                                        startTime:
                                            streamInfo?.uptimeStartTime ?? '',
                                        style: TextStyle(
                                          color: surfaceColor,
                                          fontWeight: FontWeight.w500,
                                          shadows: _textShadow,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Tooltip(
                                  message: 'Viewer count',
                                  preferBelow: false,
                                  child: GestureDetector(
                                    onTap: () =>
                                        showModalBottomSheetWithProperFocus(
                                          isScrollControlled: true,
                                          context: context,
                                          builder: (context) =>
                                              const SizedBox(), // Placeholder/Removed
                                        ),
                                    child: Row(
                                      spacing: 4,
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          size: 14,
                                          shadows: _iconShadow,
                                          color: surfaceColor,
                                        ),
                                        Text(
                                          NumberFormat().format(
                                            videoStore
                                                    .streamInfo
                                                    ?.viewerCount ??
                                                0,
                                          ),
                                          style: TextStyle(
                                            color: surfaceColor,
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                            shadows: _textShadow,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (settingsStore.showLatency)
                                  Tooltip(
                                    message: 'Latency to broadcaster',
                                    preferBelow: false,
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: Row(
                                      spacing: 4,
                                      children: [
                                        Icon(
                                          Icons.speed_rounded,
                                          size: 14,
                                          color: surfaceColor,
                                          shadows: _iconShadow,
                                        ),
                                        Observer(
                                          builder: (context) => Text(
                                            videoStore.latency ?? '—',
                                            style: TextStyle(
                                              color: surfaceColor,
                                              fontWeight: FontWeight.w500,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                              shadows: _textShadow,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Builder(
                          builder: (_) {
                            // On iOS, show toggle behavior. On Android, always show enter PiP.
                            final isIOS = Platform.isIOS;
                            final showExitState =
                                isIOS && videoStore.isInPipMode;

                            return Tooltip(
                              message: showExitState
                                  ? 'Exit picture-in-picture'
                                  : 'Enter picture-in-picture',
                              preferBelow: false,
                              child: IconButton(
                                icon: Icon(
                                  showExitState
                                      ? Icons.picture_in_picture_alt_outlined
                                      : Icons.picture_in_picture_alt_rounded,
                                  color: surfaceColor,
                                  shadows: _iconShadow,
                                ),
                                onPressed: videoStore.togglePictureInPicture,
                              ),
                            );
                          },
                        ),
                        refreshButton,
                        // On iPad, hide the rotate button on the overlay
                        // Flutter doesn't allow programmatic rotation on iPad unless multitasking is disabled.
                        if (!isIPad()) rotateButton,
                        if (context.isLandscape) fullScreenButton,
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// VOD playback controls widget with seekbar, time display, playback rate,
/// and utility buttons (refresh, rotate, fullscreen).
class _VodControls extends StatelessWidget {
  final VideoStore videoStore;
  final Color surfaceColor;
  final List<Shadow> textShadow;
  final List<Shadow> iconShadow;

  const _VodControls({
    required this.videoStore,
    required this.surfaceColor,
    required this.textShadow,
    required this.iconShadow,
  });

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final positionMs = videoStore.positionMs;
        final durationMs = videoStore.durationMs;
        final playbackRate = videoStore.playbackRate;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seekbar
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: surfaceColor,
                  inactiveTrackColor: surfaceColor.withValues(alpha: 0.3),
                  thumbColor: surfaceColor,
                  overlayColor: surfaceColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: positionMs.toDouble().clamp(0, durationMs.toDouble()),
                  max: durationMs > 0 ? durationMs.toDouble() : 1,
                  onChangeStart: (_) => videoStore.onSeekStart(),
                  onChanged: (value) => videoStore.onSeekUpdate(value.toInt()),
                  onChangeEnd: (value) => videoStore.onSeekEnd(value.toInt()),
                ),
              ),
              // Bottom row: time display, playback rate, skip buttons, and utility buttons
              Row(
                children: [
                  // Time display
                  Text(
                    '${_formatDuration(positionMs)} / ${_formatDuration(durationMs)}',
                    style: TextStyle(
                      color: surfaceColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: textShadow,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Playback rate button
                  GestureDetector(
                    onTap: videoStore.cyclePlaybackRate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${playbackRate}x',
                        style: TextStyle(
                          color: surfaceColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: textShadow,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quality button
                  GestureDetector(
                    onTap: () =>
                        _showQualityPicker(context, videoStore, surfaceColor),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        videoStore.currentVodQualityDisplay.toUpperCase(),
                        style: TextStyle(
                          color: surfaceColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: textShadow,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Skip backward button
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.replay_10_rounded,
                      color: surfaceColor,
                      shadows: iconShadow,
                    ),
                    onPressed: videoStore.skipBackward,
                    tooltip: 'Skip back 10s',
                  ),
                  const SizedBox(width: 4),
                  // Skip forward button
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.forward_10_rounded,
                      color: surfaceColor,
                      shadows: iconShadow,
                    ),
                    onPressed: videoStore.skipForward,
                    tooltip: 'Skip forward 10s',
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: surfaceColor,
                      shadows: iconShadow,
                    ),
                    onPressed: videoStore.handleRefresh,
                    tooltip: 'Refresh',
                  ),
                  // Rotate button (hidden on iPad)
                  if (!isIPad())
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.screen_rotation_rounded,
                        color: surfaceColor,
                        shadows: iconShadow,
                      ),
                      onPressed: () async {
                        if (context.isPortrait) {
                          final physicalOrientation =
                              await NativeDeviceOrientationCommunicator()
                                  .orientation(useSensor: true);
                          final needsSwap = Platform.isIOS;

                          if (physicalOrientation ==
                              NativeDeviceOrientation.landscapeLeft) {
                            SystemChrome.setPreferredOrientations([
                              needsSwap
                                  ? DeviceOrientation.landscapeRight
                                  : DeviceOrientation.landscapeLeft,
                            ]);
                          } else if (physicalOrientation ==
                              NativeDeviceOrientation.landscapeRight) {
                            SystemChrome.setPreferredOrientations([
                              needsSwap
                                  ? DeviceOrientation.landscapeLeft
                                  : DeviceOrientation.landscapeRight,
                            ]);
                          } else {
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.landscapeLeft,
                              DeviceOrientation.landscapeRight,
                            ]);
                          }
                        } else {
                          SystemChrome.setPreferredOrientations([
                            DeviceOrientation.portraitUp,
                          ]);
                          SystemChrome.setPreferredOrientations([]);
                        }
                      },
                      tooltip: context.isPortrait
                          ? 'Enter landscape mode'
                          : 'Exit landscape mode',
                    ),
                  // Fullscreen button (landscape only)
                  if (context.isLandscape)
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        videoStore.settingsStore.fullScreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: surfaceColor,
                        shadows: iconShadow,
                      ),
                      onPressed: () => videoStore.settingsStore.fullScreen =
                          !videoStore.settingsStore.fullScreen,
                      tooltip: videoStore.settingsStore.fullScreen
                          ? 'Exit fullscreen mode'
                          : 'Enter fullscreen mode',
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shows a quality picker bottom sheet for VOD playback.
void _showQualityPicker(
  BuildContext context,
  VideoStore videoStore,
  Color surfaceColor,
) {
  showModalBottomSheetWithProperFocus(
    context: context,
    builder: (context) => Observer(
      builder: (_) {
        final qualities = videoStore.availableVodQualities;
        final currentQuality = videoStore.currentVodQualityDisplay;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              'VOD Quality',
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              isFirst: true,
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                primary: false,
                itemCount: qualities.length,
                itemBuilder: (context, index) {
                  final quality = qualities[index];
                  final isSelected = currentQuality == quality;

                  return ListTile(
                    leading: isSelected
                        ? Icon(Icons.check_rounded, color: surfaceColor)
                        : const Icon(Icons.high_quality_rounded),
                    title: Text(quality.toUpperCase()),
                    onTap: () {
                      videoStore.setVodQuality(quality);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
