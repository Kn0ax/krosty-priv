import 'dart:async';
import 'dart:io';

import 'package:aws_ivs_player/aws_ivs_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/services/audio_handler.dart';
import 'package:mobx/mobx.dart';
import 'package:simple_pip_mode/simple_pip.dart';

part 'video_store.g.dart';

class VideoStore = VideoStoreBase with _$VideoStore;

abstract class VideoStoreBase with Store {
  final KickApi kickApi;

  /// The userlogin of the current channel.
  final String userLogin;

  /// The user ID of the current channel.
  final String userId;

  final AuthStore authStore;

  final SettingsStore settingsStore;

  final KrostyAudioHandler audioHandler;

  /// The [SimplePip] instance used for initiating PiP on Android.
  final pip = SimplePip();

  /// The AWS IVS player controller.
  late final IvsPlayerController _ivsController;

  /// Get the IVS controller for the Video widget.
  IvsPlayerController get ivsController => _ivsController;

  /// The current playback URL (m3u8 master playlist).
  @readonly
  String? _playbackUrl;

  /// Tracks playback error retry state to prevent infinite loops.
  int _playbackErrorRetryCount = 0;
  DateTime? _lastPlaybackErrorTime;
  static const _maxPlaybackErrorRetries = 3;
  static const _playbackErrorCooldown = Duration(seconds: 10);

  /// Prevents duplicate initialization calls.
  bool _isInitializing = false;

  /// Tracks if initial load is complete to prevent unnecessary refreshes.
  bool _initialLoadComplete = false;

  /// The timer that handles hiding the overlay automatically.
  Timer? _overlayTimer;

  /// Tracks the pre-PiP overlay visibility so we can restore it on exit.
  bool _overlayWasVisibleBeforePip = true;

  /// The timer that handles periodic stream info updates.
  Timer? _streamInfoTimer;

  /// The timer that handles periodic viewer count updates in video mode.
  Timer? _viewerCountTimer;

  /// Tracks the last time stream info was updated to prevent double refresh.
  DateTime? _lastStreamInfoUpdate;

  /// Disposes the overlay reactions.
  late final ReactionDisposer _disposeOverlayReaction;

  /// Disposes the video mode reaction for timer management.
  late final ReactionDisposer _disposeVideoModeReaction;

  ReactionDisposer? _disposeAndroidAutoPipReaction;

  /// If the video is currently paused.
  ///
  /// Does not pause or play the video, only used for rendering state of the overlay.
  @readonly
  var _paused = true;

  /// If the overlay should be visible.
  @readonly
  var _overlayVisible = true;

  /// The current stream info, used for displaying relevant info on the overlay.
  @readonly
  KickLivestreamItem? _streamInfo;

  /// The current livestream ID for fetching viewer count updates.
  /// This is stored separately to avoid needing full channel data for updates.
  int? _currentLivestreamId;

  /// The offline channel info, used for displaying channel details when offline.
  @readonly
  KickChannel? _offlineChannelInfo;

  /// Available stream qualities from the IVS player.
  @readonly
  List<String> _availableStreamQualities = ['Auto'];

  /// The current stream quality index.
  @readonly
  int _streamQualityIndex = 0;

  /// Whether auto quality mode is enabled.
  @readonly
  bool _isAutoQuality = true;

  /// The current stream quality string.
  String get streamQuality =>
      _isAutoQuality ? 'Auto' : _availableStreamQualities[_streamQualityIndex];

  /// Whether the app is currently in picture-in-picture mode.
  @readonly
  var _isInPipMode = false;

  /// Whether the player is currently buffering.
  @readonly
  var _isBuffering = false;

  /// Latency to broadcaster.
  /// IVS doesn't expose latency metrics in the current API version.
  @readonly
  String? _latency;

  VideoStoreBase({
    required this.userLogin,
    required this.userId,
    required this.kickApi,
    required this.authStore,
    required this.settingsStore,
    required this.audioHandler,
  }) {
    // Initialize the AWS IVS player controller
    _ivsController = IvsPlayerController();

    // Setup player state listener
    _ivsController.addListener(_onPlayerStateChanged);

    // Setup audio handler callbacks
    audioHandler.onPlayCallback = () async {
      _ivsController.play(_playbackUrl!);
    };
    audioHandler.onPauseCallback = () async {
      _ivsController.pause();
    };
    audioHandler.onStopCallback = () async {
      _ivsController.pause(); // Just pause, don't stop stream to allow resume
    };

    // Initialize the [_overlayTimer] to auto-hide the overlay after a delay (default 5 seconds).
    _scheduleOverlayHide();

    // Initialize a reaction to manage stream info timer based on video mode
    _disposeVideoModeReaction = reaction((_) => settingsStore.showVideo, (
      showVideo,
    ) {
      if (showVideo) {
        // In video mode, stop the stream info timer and start viewer count timer
        _stopStreamInfoTimer();
        _startViewerCountTimer();
      } else {
        // In chat-only mode, start the stream info timer and stop viewer count timer
        _stopViewerCountTimer();
        _startStreamInfoTimer();
        // Ensure overlay timer is active for clean UI
        _scheduleOverlayHide();
      }
    });

    // Reaction for overlay toggle - reload player if needed
    _disposeOverlayReaction = reaction((_) => settingsStore.showOverlay, (_) {
      // Re-initialize overlay visibility when toggle changes
      if (settingsStore.showOverlay) {
        _overlayVisible = true;
        _scheduleOverlayHide();
      }
    });

    // Check initial state and start appropriate timer
    if (!settingsStore.showVideo) {
      _startStreamInfoTimer();
      _scheduleOverlayHide();
    } else {
      _startViewerCountTimer();
    }

    // On Android, enable auto PiP mode (setAutoEnterEnabled) if the device supports it.
    if (Platform.isAndroid) {
      _disposeAndroidAutoPipReaction = autorun((_) async {
        if (settingsStore.showVideo && await SimplePip.isAutoPipAvailable) {
          pip.setAutoPipMode();
        } else {
          pip.setAutoPipMode(autoEnter: false);
        }
      });
    }

    // Fetch channel data and initialize player
    _initializeStream();
  }

  /// Handle IVS player state changes.
  void _onPlayerStateChanged() {
    final state = _ivsController.state;
    runInAction(() {
      switch (state) {
        case PlayerState.idle:
          _paused = true;
          _isBuffering = false;
          break;
        case PlayerState.loading:
          _isBuffering = true;
          break;
        case PlayerState.ready:
          _isBuffering = false;
          break;
        case PlayerState.playing:
          _paused = false;
          _isBuffering = false;
          _overlayVisible = true;
          _scheduleOverlayHide();
          // Enable Auto PiP (Android 12+)
          if (Platform.isAndroid) {
            pip.setIsPlaying(true);
            pip.setAutoPipMode(autoEnter: true, aspectRatio: (16, 9));
          }
          break;
        case PlayerState.paused:
          _paused = true;
          _isBuffering = false;
          // Update Android PiP play state
          if (Platform.isAndroid) {
            pip.setIsPlaying(false);
          }
          break;
        case PlayerState.stopped:
          _paused = true;
          _isBuffering = false;
          // Update Android PiP play state
          if (Platform.isAndroid) {
            pip.setIsPlaying(false);
            pip.setAutoPipMode(autoEnter: false);
          }
          break;
        case PlayerState.error:
          _paused = true;
          _isBuffering = false;
          _handlePlaybackError(_ivsController.errorMessage ?? 'Unknown error');
          if (Platform.isAndroid) {
            pip.setAutoPipMode(autoEnter: false);
          }
          break;
        case PlayerState.idle:
          _paused = true;
          _isBuffering = false;
          _overlayVisible = true;
          // Disable Auto PiP
          if (Platform.isAndroid) {
            pip.setAutoPipMode(autoEnter: false);
          }
          break;
        case PlayerState.disposed:
          break;
      }

      // Update audio handler state
      audioHandler.updatePlaybackState(
        isPlaying: !_paused,
        isBuffering: _isBuffering,
      );
    });
  }

  /// Handle playback errors.
  Future<void> _handlePlaybackError(String error) async {
    debugPrint('IVS Player error: $error');

    final now = DateTime.now();

    // Reset retry count if enough time has passed since last error
    if (_lastPlaybackErrorTime != null &&
        now.difference(_lastPlaybackErrorTime!) > _playbackErrorCooldown) {
      _playbackErrorRetryCount = 0;
    }

    // Check if we've exceeded max retries
    if (_playbackErrorRetryCount >= _maxPlaybackErrorRetries) {
      debugPrint(
        'Playback error: Max retries ($_maxPlaybackErrorRetries) exceeded, '
        'waiting for manual refresh',
      );
      return;
    }

    _lastPlaybackErrorTime = now;
    _playbackErrorRetryCount++;

    debugPrint(
      'Playback error recovery attempt $_playbackErrorRetryCount/$_maxPlaybackErrorRetries',
    );

    try {
      // Re-fetch the channel data to get a fresh playback URL
      final channel = await kickApi.getChannel(channelSlug: userLogin);
      if (channel.playbackUrl != null && channel.isLive) {
        runInAction(() {
          _playbackUrl = channel.playbackUrl;
        });
        // Try to resume playback with new URL
        await _ivsController.play(_playbackUrl!);
      }
    } catch (e) {
      debugPrint('Failed to recover from playback error: $e');
    }
  }

  /// Initialize the stream by fetching channel data and starting playback.
  Future<void> _initializeStream() async {
    // Prevent duplicate initialization
    if (_isInitializing) {
      debugPrint('Stream initialization already in progress, skipping');
      return;
    }
    _isInitializing = true;

    try {
      final channel = await kickApi.getChannel(channelSlug: userLogin);

      // Update stream info from the same API response
      if (channel.isLive) {
        final livestream = channel.livestream!;
        // Store the livestream ID for lightweight viewer count updates
        final livestreamId = livestream.id is int
            ? livestream.id as int
            : int.tryParse(livestream.id.toString());
        _currentLivestreamId = livestreamId;
        runInAction(() {
          _streamInfo = KickLivestreamItem(
            id: livestream.id,
            slug: livestream.slug,
            channelId: channel.id,
            createdAt: livestream.createdAt,
            startTime: livestream.startTime,
            sessionTitle: livestream.sessionTitle,
            isLive: true,
            viewerCount: livestream.viewerCount,
            thumbnail: livestream.thumbnail,
            categories: livestream.categories,
            tags: livestream.tags,
            isMature: livestream.isMature,
            language: livestream.language,
            channel: KickChannelInfo(
              id: channel.id,
              slug: channel.slug,
              user: channel.user,
            ),
          );
          _offlineChannelInfo = null;

          // Update audio handler metadata
          final title = _streamInfo?.sessionTitle ?? 'Kick Stream';
          final artist =
              _streamInfo?.channel?.user?.username ??
              _streamInfo?.channel?.slug ??
              'Kick Streamer';

          // Prioritize banner image or profile pic over stream thumbnail
          // to avoid 403 errors with protected stream thumbnails
          final artUri =
              channel.bannerImage?.url ??
              channel.user.profilePic ??
              _streamInfo?.thumbnail?.imageUrl;

          audioHandler.updateMetadata(
            title: title,
            artist: artist,
            artUri: artUri,
          );
        });
      } else {
        _currentLivestreamId = null;
        runInAction(() {
          _streamInfo = null;
          _offlineChannelInfo = channel;
          _paused = true;
        });
      }

      // Get playback URL from the same response
      final playbackUrl = channel.playbackUrl;
      runInAction(() {
        _playbackUrl = playbackUrl;
      });

      _initialLoadComplete = true;
    } catch (e) {
      debugPrint('Failed to initialize stream: $e');
    } finally {
      _isInitializing = false;
    }
  }

  @action
  Future<void> updateStreamQualities() async {
    try {
      final qualities = await _ivsController.getQualities();
      if (qualities.isNotEmpty) {
        // Build list with 'Auto' first, then quality labels sorted by height (descending)
        final sortedQualities = List<IvsQuality>.from(qualities)
          ..sort((a, b) => b.height.compareTo(a.height));

        _availableStreamQualities = [
          'Auto',
          ...sortedQualities.map((q) => q.label),
        ];
        debugPrint('Available qualities: $_availableStreamQualities');
      } else {
        _availableStreamQualities = ['Auto'];
      }
    } catch (e) {
      debugPrint('Error updating stream qualities: $e');
      _availableStreamQualities = ['Auto'];
    }
  }

  @action
  Future<void> setStreamQuality(String newStreamQuality) async {
    try {
      if (newStreamQuality == 'Auto') {
        await _ivsController.setAutoQualityMode(true);
        _isAutoQuality = true;
        _streamQualityIndex = 0;
        debugPrint('Set to Auto quality mode');
      } else {
        // Find the matching quality by label
        final qualities = await _ivsController.getQualities();
        final quality = qualities.firstWhere(
          (q) => q.label == newStreamQuality,
          orElse: () => qualities.first,
        );

        final success = await _ivsController.setQuality(quality.name);
        if (success) {
          _isAutoQuality = false;
          _streamQualityIndex = _availableStreamQualities.indexOf(
            newStreamQuality,
          );
          debugPrint('Set quality to: ${quality.name}');
        }
      }
    } catch (e) {
      debugPrint('Error setting stream quality: $e');
    }
  }

  /// Called whenever the video/overlay is tapped.
  @action
  void handleVideoTap() {
    if (_isInPipMode) {
      _overlayVisible = true;
      return;
    }

    _overlayTimer?.cancel();

    if (_overlayVisible) {
      _overlayVisible = false;
    } else {
      _overlayVisible = true;
      _scheduleOverlayHide();
    }
  }

  /// Starts the periodic stream info timer for chat-only mode.
  void _startStreamInfoTimer() {
    // Only start if not already active
    if (_streamInfoTimer?.isActive != true) {
      _streamInfoTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => updateStreamInfo(),
      );
    }
  }

  /// Stops the periodic stream info timer.
  void _stopStreamInfoTimer() {
    if (_streamInfoTimer?.isActive == true) {
      _streamInfoTimer?.cancel();
      _streamInfoTimer = null;
    }
  }

  /// Starts the periodic viewer count timer for video mode (every 30 seconds).
  void _startViewerCountTimer() {
    // Only start if not already active
    if (_viewerCountTimer?.isActive != true) {
      _viewerCountTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _updateViewerCountOnly(),
      );
    }
  }

  /// Stops the periodic viewer count timer.
  void _stopViewerCountTimer() {
    if (_viewerCountTimer?.isActive == true) {
      _viewerCountTimer?.cancel();
      _viewerCountTimer = null;
    }
  }

  /// Updates only the viewer count using the lightweight endpoint.
  @action
  Future<void> _updateViewerCountOnly() async {
    if (_currentLivestreamId == null || _streamInfo == null) return;

    try {
      final viewerCount = await kickApi.getLivestreamViewerCount(
        livestreamId: _currentLivestreamId!,
      );
      if (viewerCount != null) {
        _streamInfo = KickLivestreamItem(
          id: _streamInfo!.id,
          slug: _streamInfo!.slug,
          channelId: _streamInfo!.channelId,
          createdAt: _streamInfo!.createdAt,
          startTime: _streamInfo!.startTime,
          sessionTitle: _streamInfo!.sessionTitle,
          isLive: _streamInfo!.isLive,
          viewerCount: viewerCount,
          thumbnail: _streamInfo!.thumbnail,
          categories: _streamInfo!.categories,
          tags: _streamInfo!.tags,
          isMature: _streamInfo!.isMature,
          language: _streamInfo!.language,
          channel: _streamInfo!.channel,
        );
      }
    } catch (e) {
      debugPrint('Failed to update viewer count: $e');
    }
  }

  void _scheduleOverlayHide([Duration delay = const Duration(seconds: 5)]) {
    _overlayTimer?.cancel();

    if (_isInPipMode) {
      _overlayVisible = true;
      return;
    }

    _overlayTimer = Timer(delay, () {
      if (_isInPipMode) return;

      runInAction(() {
        _overlayVisible = false;
      });
    });
  }

  /// Handles app resume event for immediate stream info refresh in chat-only mode.
  @action
  void handleAppResume() {
    // Only refresh immediately in chat-only mode
    if (!settingsStore.showVideo) {
      updateStreamInfo(forceUpdate: true);
    }
  }

  /// Updates the stream info from the Kick API.
  ///
  /// If the stream is offline, fetches channel information to show offline details.
  /// Set [forceUpdate] to true to bypass the rate limiting check.
  @action
  Future<void> updateStreamInfo({bool forceUpdate = false}) async {
    // Skip if initial load hasn't completed yet - _initializeStream handles it
    if (!_initialLoadComplete && !forceUpdate) {
      return;
    }

    // Rate limiting: prevent too frequent updates unless forced
    final now = DateTime.now();
    if (!forceUpdate && _lastStreamInfoUpdate != null) {
      final timeSinceLastUpdate = now.difference(_lastStreamInfoUpdate!);
      if (timeSinceLastUpdate.inSeconds < 5) {
        return; // Skip update if less than 5 seconds since last update
      }
    }

    _lastStreamInfoUpdate = now;

    // If we have a livestream ID and stream info, use the lightweight
    // current-viewers endpoint instead of fetching full channel data
    if (_currentLivestreamId != null && _streamInfo != null) {
      try {
        final viewerCount = await kickApi.getLivestreamViewerCount(
          livestreamId: _currentLivestreamId!,
        );
        if (viewerCount != null) {
          // Update the viewer count in the existing stream info
          _streamInfo = KickLivestreamItem(
            id: _streamInfo!.id,
            slug: _streamInfo!.slug,
            channelId: _streamInfo!.channelId,
            createdAt: _streamInfo!.createdAt,
            startTime: _streamInfo!.startTime,
            sessionTitle: _streamInfo!.sessionTitle,
            isLive: _streamInfo!.isLive,
            viewerCount: viewerCount,
            thumbnail: _streamInfo!.thumbnail,
            categories: _streamInfo!.categories,
            tags: _streamInfo!.tags,
            isMature: _streamInfo!.isMature,
            language: _streamInfo!.language,
            channel: _streamInfo!.channel,
          );
        }
        return;
      } catch (e) {
        debugPrint(
          'Failed to update viewer count, falling back to full refresh: $e',
        );
        // Fall through to full channel fetch if lightweight update fails
      }
    }

    // Full channel fetch - used for initial load or when stream state changes
    try {
      final channel = await kickApi.getChannel(channelSlug: userLogin);

      if (channel.isLive) {
        // Create a synthetic KickLivestreamItem from the channel data
        final livestream = channel.livestream!;
        // Store the livestream ID for lightweight updates
        final livestreamId = livestream.id is int
            ? livestream.id as int
            : int.tryParse(livestream.id.toString());
        _currentLivestreamId = livestreamId;
        _streamInfo = KickLivestreamItem(
          id: livestream.id,
          slug: livestream.slug,
          channelId: channel.id,
          createdAt: livestream.createdAt,
          startTime: livestream.startTime,
          sessionTitle: livestream.sessionTitle,
          isLive: true,
          viewerCount: livestream.viewerCount,
          thumbnail: livestream.thumbnail,
          categories: livestream.categories,
          tags: livestream.tags,
          isMature: livestream.isMature,
          language: livestream.language,
          channel: KickChannelInfo(
            id: channel.id,
            slug: channel.slug,
            user: channel.user,
          ),
        );
        _offlineChannelInfo = null;

        // Update playback URL if it changed (e.g., token refresh)
        if (channel.playbackUrl != null &&
            channel.playbackUrl != _playbackUrl) {
          _playbackUrl = channel.playbackUrl;
        }
      } else {
        _currentLivestreamId = null;
        _streamInfo = null;
        _offlineChannelInfo = channel;
        _paused = true;

        // Stop playback when stream is offline
        await _ivsController.stop();

        // Restart overlay timer in chat-only mode even on error/offline
        if (!settingsStore.showVideo) {
          _scheduleOverlayHide();
        }
      }
    } catch (e) {
      _overlayTimer?.cancel();
      _currentLivestreamId = null;
      _streamInfo = null;
      _offlineChannelInfo = null;
      _paused = true;

      // Restart overlay timer in chat-only mode even on error
      if (!settingsStore.showVideo) {
        _scheduleOverlayHide();
      }
    }
  }

  /// Handles the toggle overlay options.
  ///
  /// The toggle overlay option allows switching between the custom and default overlay by long-pressing the overlay.
  @action
  void handleToggleOverlay() {
    if (settingsStore.toggleableOverlay) {
      HapticFeedback.mediumImpact();

      settingsStore.showOverlay = !settingsStore.showOverlay;

      if (settingsStore.showOverlay) {
        _overlayVisible = true;
        _scheduleOverlayHide(const Duration(seconds: 3));
      }
    }

    // Stream info timer is managed automatically by the video mode reaction
  }

  /// Refreshes the stream and updates the stream info.
  @action
  Future<void> handleRefresh() async {
    HapticFeedback.lightImpact();
    _paused = true;
    _isInPipMode = false;

    // Reset playback error retry state on manual refresh
    _playbackErrorRetryCount = 0;
    _lastPlaybackErrorTime = null;

    // Reset initialization flags to allow refresh
    _isInitializing = false;
    _initialLoadComplete = false;

    // Stop current playback
    await _ivsController.stop();

    // Re-fetch channel data and playback URL
    // This also updates stream info, no need to call updateStreamInfo separately
    await _initializeStream();

    // Explicitly resume playback if we have a URL
    if (_playbackUrl != null) {
      await _ivsController.play(_playbackUrl!);
    }
  }

  /// Play or pause the video depending on the current state of [_paused].
  void handlePausePlay() {
    if (_paused) {
      if (_playbackUrl != null) {
        _ivsController.resume();
      }
    } else {
      _ivsController.pause();
    }
  }

  /// Initiate picture in picture if available.
  ///
  /// On Android, this will utilize the native Android PiP API.
  /// On iOS, this will utilize the native AVKit PiP support.
  void requestPictureInPicture() {
    try {
      if (Platform.isAndroid) {
        pip.enterPipMode(autoEnter: true);
        runInAction(() {
          _overlayWasVisibleBeforePip = _overlayVisible;
          _isInPipMode = true;
        });
      } else if (Platform.isIOS) {
        // IVS handles iOS PiP internally via AVKit
        runInAction(() {
          _overlayWasVisibleBeforePip = _overlayVisible;
          _isInPipMode = true;
        });
      }
    } catch (e) {
      debugPrint('PiP error: $e');
    }
  }

  /// Toggle picture-in-picture mode.
  ///
  /// If not in PiP mode, enters PiP mode.
  /// If already in PiP mode, exits PiP mode.
  @action
  void togglePictureInPicture() {
    if (_isInPipMode) {
      // Exit PiP mode
      runInAction(() {
        _isInPipMode = false;
        if (_overlayWasVisibleBeforePip) {
          _scheduleOverlayHide();
        } else {
          _overlayVisible = false;
        }
      });
    } else {
      // Enter PiP mode
      requestPictureInPicture();
    }
  }

  /// Called when Android PiP mode changes.
  @action
  void onPipModeChanged(bool isInPipMode) {
    if (isInPipMode) {
      _overlayWasVisibleBeforePip = _overlayVisible;
      _isInPipMode = true;
      _overlayTimer?.cancel();
      _overlayVisible = true;
    } else {
      _isInPipMode = false;
      if (_overlayWasVisibleBeforePip) {
        _scheduleOverlayHide();
      } else {
        _overlayVisible = false;
      }
    }
  }

  @action
  void dispose() {
    // Disable auto PiP when leaving so that we don't enter PiP on other screens.
    if (Platform.isAndroid) {
      SimplePip.isAutoPipAvailable.then((isAutoPipAvailable) {
        if (isAutoPipAvailable) pip.setAutoPipMode(autoEnter: false);
      });
    }

    // Cancel all timers
    _overlayTimer?.cancel();
    _streamInfoTimer?.cancel();
    _viewerCountTimer?.cancel();

    // Dispose reactions
    _disposeOverlayReaction();
    _disposeVideoModeReaction();
    _disposeAndroidAutoPipReaction?.call();

    // Remove listener and dispose the IVS controller
    _ivsController.removeListener(_onPlayerStateChanged);
    _ivsController.dispose();

    // Clear audio handler callbacks
    audioHandler.onPlayCallback = null;
    audioHandler.onPauseCallback = null;
    audioHandler.onStopCallback = null;
    audioHandler.stop();
  }
}
