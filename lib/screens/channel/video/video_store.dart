import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/channel/video/hls_quality_parser.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// The [SimplePip] instance used for initiating PiP on Android.
  final pip = SimplePip();

  /// Flag to track first time quality selection.
  var _firstTimeSettingQuality = true;

  /// The native media_kit player instance.
  late final Player _player;

  /// The video controller for rendering the player.
  late final VideoController _videoController;

  /// Get the video controller for the Video widget.
  VideoController get videoController => _videoController;

  /// Get the player instance for advanced controls.
  Player get player => _player;

  /// The current playback URL (m3u8 master playlist).
  String? _playbackUrl;

  /// Parsed HLS quality variants from the master playlist.
  List<HlsVariant> _hlsVariants = [];

  /// Subscriptions to player streams.
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];

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

  /// The offline channel info, used for displaying channel details when offline.
  @readonly
  KickChannel? _offlineChannelInfo;

  @readonly
  List<String> _availableStreamQualities = [];

  /// The current stream quality index.
  @readonly
  int _streamQualityIndex = 0;

  /// The current stream quality string.
  String get streamQuality =>
      _availableStreamQualities.elementAtOrNull(_streamQualityIndex) ?? 'Auto';

  /// Whether the app is currently in picture-in-picture mode.
  @readonly
  var _isInPipMode = false;

  /// Whether the player is currently buffering.
  @readonly
  var _isBuffering = false;

  /// Latency to broadcaster (not available with native HLS player).
  /// This is kept for UI compatibility but will always return null.
  @readonly
  String? _latency;

  /// Completer to track when low-latency config is done.
  final Completer<void> _lowLatencyConfigured = Completer<void>();

  VideoStoreBase({
    required this.userLogin,
    required this.userId,
    required this.kickApi,
    required this.authStore,
    required this.settingsStore,
  }) {
    // Initialize the media_kit player
    _player = Player();
    _videoController = VideoController(_player);

    // Configure low-latency settings via NativePlayer (targets <5s latency)
    _configureLowLatency().then((_) {
      if (!_lowLatencyConfigured.isCompleted) {
        _lowLatencyConfigured.complete();
      }
    });

    // Setup player event listeners
    _setupPlayerListeners();

    // Initialize the [_overlayTimer] to auto-hide the overlay after a delay (default 5 seconds).
    _scheduleOverlayHide();

    // Initialize a reaction to manage stream info timer based on video mode
    _disposeVideoModeReaction = reaction((_) => settingsStore.showVideo, (
      showVideo,
    ) {
      if (showVideo) {
        // In video mode, stop the timer since overlay taps handle refreshing
        _stopStreamInfoTimer();
      } else {
        // In chat-only mode, start the timer for automatic updates
        _startStreamInfoTimer();
        // Ensure overlay timer is active for clean UI
        _scheduleOverlayHide();
      }
    });

    // Reaction for overlay toggle - reload player if needed
    _disposeOverlayReaction = reaction(
      (_) => settingsStore.showOverlay,
      (_) {
        // Re-initialize overlay visibility when toggle changes
        if (settingsStore.showOverlay) {
          _overlayVisible = true;
          _scheduleOverlayHide();
        }
      },
    );

    // Check initial state and start timer if already in chat-only mode
    if (!settingsStore.showVideo) {
      _startStreamInfoTimer();
      _scheduleOverlayHide();
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

  /// Configure settings for live HLS streaming.
  /// Uses NativePlayer's setProperty to pass mpv options.
  Future<void> _configureLowLatency() async {
    // Only available on native platforms (not web)
    if (_player.platform is NativePlayer) {
      final nativePlayer = _player.platform as NativePlayer;

      // Use a more compatible HLS configuration
      // The low-latency profile can cause codec issues on some devices
      try {
        // Essential HLS settings for live streaming
        await nativePlayer.setProperty('demuxer-max-bytes', '50MiB');
        await nativePlayer.setProperty('demuxer-max-back-bytes', '25MiB');

        // Enable hardware decoding for better performance
        await nativePlayer.setProperty('hwdec', 'auto-safe');

        // Reduce initial buffering for faster start
        await nativePlayer.setProperty('demuxer-readahead-secs', '3');

        // Better error recovery for live streams
        await nativePlayer.setProperty('stream-lavf-o', 'reconnect=1');
      } catch (e) {
        debugPrint('Failed to configure player properties: $e');
      }
    }
  }

  /// Setup listeners for player state changes.
  void _setupPlayerListeners() {
    // Listen for play/pause state changes
    _playerSubscriptions.add(
      _player.stream.playing.listen((playing) {
        runInAction(() {
          _paused = !playing;
        });
        // Update Android PiP play state
        if (Platform.isAndroid) {
          pip.setIsPlaying(playing);
        }
      }),
    );

    // Listen for buffering state
    _playerSubscriptions.add(
      _player.stream.buffering.listen((buffering) {
        runInAction(() {
          _isBuffering = buffering;
        });
      }),
    );

    // Listen for errors
    _playerSubscriptions.add(
      _player.stream.error.listen((error) {
        debugPrint('Player error: $error');
        // On error (possibly token expiry), try to recover
        if (error.isNotEmpty) {
          _handlePlaybackError(error);
        }
      }),
    );

    // Listen for completion (stream ended)
    _playerSubscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed) {
          runInAction(() {
            _paused = true;
          });
          // Don't auto-refresh here - user can manually refresh if needed
          // This prevents unnecessary API calls when stream naturally ends
        }
      }),
    );
  }

  /// Handle playback errors (e.g., token expiry).
  ///
  /// For codec errors, we just retry with the same URL a few times.
  /// Only re-fetches the channel if it seems like a token/URL issue.
  Future<void> _handlePlaybackError(String error) async {
    // Codec errors won't be fixed by refetching - just retry or give up
    final isCodecError = error.toLowerCase().contains('codec');

    if (isCodecError) {
      // For codec errors, just retry with existing URL (no API call)
      if (_playbackErrorRetryCount >= _maxPlaybackErrorRetries) {
        debugPrint(
          'Codec error: Max retries ($_maxPlaybackErrorRetries) exceeded, '
          'waiting for manual refresh',
        );
        return;
      }

      _playbackErrorRetryCount++;
      debugPrint(
        'Codec error recovery attempt $_playbackErrorRetryCount/$_maxPlaybackErrorRetries (no refetch)',
      );

      // Small delay before retry
      await Future.delayed(const Duration(milliseconds: 500));

      // Just retry with existing URL
      if (_playbackUrl != null) {
        try {
          await _player.open(Media(_playbackUrl!));
        } catch (e) {
          debugPrint('Retry failed: $e');
        }
      }
      return;
    }

    // For other errors (possibly token expiry), try refetching once
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
        _playbackUrl = channel.playbackUrl;
        // Try to resume playback with new URL
        await _player.open(Media(_playbackUrl!));
      }
    } catch (e) {
      debugPrint('Failed to recover from playback error: $e');
    }
  }

  /// Initialize the stream by fetching channel data and starting playback.
  /// Optimized to use a single API call for both stream info and playback URL.
  Future<void> _initializeStream() async {
    // Prevent duplicate initialization
    if (_isInitializing) {
      debugPrint('Stream initialization already in progress, skipping');
      return;
    }
    _isInitializing = true;

    try {
      // Start fetching channel data and getting saved quality preference in parallel
      final results = await Future.wait([
        kickApi.getChannel(channelSlug: userLogin),
        SharedPreferences.getInstance(),
      ]);

      final channel = results[0] as KickChannel;
      final prefs = results[1] as SharedPreferences;

      // Update stream info from the same API response
      if (channel.isLive) {
        final livestream = channel.livestream!;
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
        });
      } else {
        runInAction(() {
          _streamInfo = null;
          _offlineChannelInfo = channel;
          _paused = true;
        });
      }

      // Get playback URL from the same response
      _playbackUrl = channel.playbackUrl;

      if (_playbackUrl != null) {
        // Parse qualities in background (don't block playback)
        _parseQualityVariantsInBackground();

        // Determine initial URL to play
        String urlToPlay = _playbackUrl!;

        // Check if user has a preferred quality saved
        final lastStreamQuality = prefs.getString('last_stream_quality');
        if (lastStreamQuality != null && lastStreamQuality != 'Auto') {
          // Try to construct the variant URL directly without fetching playlist
          // Kick streams typically use predictable URL patterns
          final variantUrl = _tryConstructVariantUrl(
            _playbackUrl!,
            lastStreamQuality,
          );
          if (variantUrl != null) {
            urlToPlay = variantUrl;
            // Find and set the quality index
            final qualityIndex = _availableStreamQualities.indexOf(
              lastStreamQuality,
            );
            if (qualityIndex != -1) {
              runInAction(() {
                _streamQualityIndex = qualityIndex;
              });
            }
          }
        } else if (settingsStore.defaultToHighestQuality) {
          // For highest quality, we need to parse the playlist first
          // But start playback immediately with master (auto) for now
          // The quality will be updated once parsing completes
        }

        await _initializePlayer(urlToPlay);
      }

      _initialLoadComplete = true;
    } catch (e) {
      debugPrint('Failed to initialize stream: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Try to construct a variant URL from the master playlist URL and quality.
  /// Returns null if construction isn't possible.
  String? _tryConstructVariantUrl(String masterUrl, String quality) {
    // This is a best-effort optimization - if it fails, we fall back to master
    // Kick uses patterns like: .../master.m3u8 -> .../1080p60/index.m3u8
    try {
      final uri = Uri.parse(masterUrl);
      final pathSegments = uri.pathSegments.toList();

      // Find and replace 'master.m3u8' or similar
      for (var i = 0; i < pathSegments.length; i++) {
        if (pathSegments[i].contains('master') ||
            pathSegments[i].contains('playlist')) {
          // Replace with quality variant
          pathSegments[i] = quality.toLowerCase();
          if (i + 1 < pathSegments.length) {
            pathSegments[i + 1] = 'index.m3u8';
          } else {
            pathSegments.add('index.m3u8');
          }
          return uri.replace(pathSegments: pathSegments).toString();
        }
      }
    } catch (e) {
      debugPrint('Failed to construct variant URL: $e');
    }
    return null;
  }

  /// Parse quality variants in the background without blocking playback.
  Future<void> _parseQualityVariantsInBackground() async {
    // Small delay to prioritize player initialization
    await Future.delayed(const Duration(milliseconds: 100));
    await _parseQualityVariants();
  }

  /// Parse quality variants from the HLS master playlist.
  ///
  /// This runs in the background and updates the available qualities list.
  /// It does NOT change the current playback - that's handled by _initializeStream.
  Future<void> _parseQualityVariants() async {
    if (_playbackUrl == null) return;

    try {
      _hlsVariants = await HlsQualityParser.parsePlaylist(_playbackUrl!);

      runInAction(() {
        _availableStreamQualities = [
          'Auto',
          ..._hlsVariants.map((v) => v.label),
        ];
      });

      // Update the quality index to match what we're currently playing
      // This is just for UI display - don't reopen the player
      if (_firstTimeSettingQuality && _availableStreamQualities.isNotEmpty) {
        _firstTimeSettingQuality = false;

        // Check saved preference
        final prefs = await SharedPreferences.getInstance();
        final lastStreamQuality = prefs.getString('last_stream_quality');

        if (settingsStore.defaultToHighestQuality &&
            _availableStreamQualities.length > 1) {
          // If we want highest quality and we're on Auto, switch to it
          // Only do this if we haven't already started with a specific quality
          if (_streamQualityIndex == 0) {
            await setStreamQuality(_availableStreamQualities[1]);
          }
        } else if (lastStreamQuality != null &&
            _availableStreamQualities.contains(lastStreamQuality)) {
          // Update index to match saved quality (may already be playing it)
          final qualityIndex = _availableStreamQualities.indexOf(
            lastStreamQuality,
          );
          if (qualityIndex != -1 && _streamQualityIndex != qualityIndex) {
            // Only switch if we're not already on this quality
            runInAction(() {
              _streamQualityIndex = qualityIndex;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to parse quality variants: $e');
      runInAction(() {
        _availableStreamQualities = ['Auto'];
      });
    }
  }

  /// Initialize the player with the given URL (or master playlist URL).
  Future<void> _initializePlayer([String? url]) async {
    final playUrl = url ?? _playbackUrl;
    if (playUrl == null) {
      debugPrint('No playback URL available');
      return;
    }

    // Ensure low-latency settings are applied before starting playback
    // This is a quick operation, typically completes before we get here
    await _lowLatencyConfigured.future;

    try {
      await _player.open(Media(playUrl));
      // Start playing automatically
      await _player.play();
    } catch (e) {
      debugPrint('Failed to initialize player: $e');
    }
  }

  @action
  Future<void> updateStreamQualities() async {
    await _parseQualityVariants();
  }

  @action
  Future<void> setStreamQuality(String newStreamQuality) async {
    final indexOfStreamQuality = _availableStreamQualities.indexOf(
      newStreamQuality,
    );
    if (indexOfStreamQuality == -1) return;

    runInAction(() {
      _streamQualityIndex = indexOfStreamQuality;
    });

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_stream_quality', newStreamQuality);

    if (newStreamQuality == 'Auto') {
      // Play the master playlist for auto quality selection
      if (_playbackUrl != null) {
        await _player.open(Media(_playbackUrl!));
        await _player.play();
      }
    } else {
      // Find and play the specific variant
      final variant = _hlsVariants.firstWhere(
        (v) => v.label == newStreamQuality,
        orElse: () => _hlsVariants.first,
      );
      await _player.open(Media(variant.url));
      await _player.play();
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
      updateStreamInfo(forceUpdate: true);

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

    try {
      final channel = await kickApi.getChannel(channelSlug: userLogin);

      if (channel.isLive) {
        // Create a synthetic KickLivestreamItem from the channel data
        final livestream = channel.livestream!;
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
        _streamInfo = null;
        _offlineChannelInfo = channel;
        _paused = true;

        // Stop playback when stream is offline
        await _player.stop();

        // Restart overlay timer in chat-only mode even on error/offline
        if (!settingsStore.showVideo) {
          _scheduleOverlayHide();
        }
      }
    } catch (e) {
      _overlayTimer?.cancel();
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
    _firstTimeSettingQuality = true;
    _isInPipMode = false;

    // Reset playback error retry state on manual refresh
    _playbackErrorRetryCount = 0;
    _lastPlaybackErrorTime = null;

    // Reset initialization flags to allow refresh
    _isInitializing = false;
    _initialLoadComplete = false;

    // Stop current playback
    await _player.stop();

    // Re-fetch channel data and playback URL
    // This also updates stream info, no need to call updateStreamInfo separately
    await _initializeStream();
  }

  /// Play or pause the video depending on the current state of [_paused].
  void handlePausePlay() {
    if (_paused) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  /// Initiate picture in picture if available.
  ///
  /// On Android, this will utilize the native Android PiP API.
  /// On iOS, this will utilize media_kit's PiP support.
  void requestPictureInPicture() {
    try {
      if (Platform.isAndroid) {
        pip.enterPipMode(autoEnter: true);
        runInAction(() {
          _overlayWasVisibleBeforePip = _overlayVisible;
          _isInPipMode = true;
        });
      } else if (Platform.isIOS) {
        // media_kit handles iOS PiP internally via AVKit
        // Request PiP through the video controller if supported
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

    // Dispose reactions
    _disposeOverlayReaction();
    _disposeVideoModeReaction();
    _disposeAndroidAutoPipReaction?.call();

    // Cancel player stream subscriptions
    for (final subscription in _playerSubscriptions) {
      subscription.cancel();
    }
    _playerSubscriptions.clear();

    // Dispose the player
    _player.dispose();
  }
}
