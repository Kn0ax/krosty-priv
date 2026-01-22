import 'dart:async';
import 'dart:io';

import 'package:aws_ivs_player/aws_ivs_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/models/kick_video.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/services/audio_handler.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
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

  /// The media_kit player for VOD playback.
  late final Player _vodPlayer;

  /// The media_kit video controller for the VodPlayer widget.
  late final VideoController _vodController;

  /// Get the VOD video controller for the VodPlayer widget.
  VideoController get vodController => _vodController;

  /// Stream subscriptions for media_kit player state.
  final List<StreamSubscription> _vodStreamSubscriptions = [];

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

  /// The last available VOD when streamer is offline.
  @readonly
  KickVideo? _lastVod;

  /// Whether we are currently playing a VOD instead of live stream.
  @readonly
  bool _isPlayingVod = false;

  // ============================================================
  // VOD Playback Controls (media_kit handles position/duration via streams)
  // ============================================================

  /// User-selectable VOD quality presets (shown in quality picker).
  static const vodQualityPresets = [
    '1080p60',
    '720p60',
    '480p30',
    '360p30',
    '160p30',
  ];

  /// Internal fallback order including hidden qualities (1080p30 as silent fallback).
  static const _vodQualityFallbackOrder = [
    '1080p60',
    '1080p30', // Silent fallback, not shown in picker
    '720p60',
    '480p30',
    '360p30',
    '160p30',
  ];

  /// Available VOD qualities for selection (user-facing).
  @readonly
  List<String> _availableVodQualities = List.from(vodQualityPresets);

  /// Internal list of qualities to try (includes silent fallbacks).
  List<String> _vodQualitiesToTry = List.from(_vodQualityFallbackOrder);

  /// Current VOD quality index in [_availableVodQualities].
  @readonly
  int _vodQualityIndex = 0;

  /// The actual quality currently playing (may differ from selected if using fallback).
  @readonly
  String _currentVodQuality = '1080p60';

  /// Get the current VOD quality string for display.
  String get currentVodQualityDisplay {
    // Show "1080p" if playing 1080p30 (hidden fallback)
    if (_currentVodQuality == '1080p30') return '1080p60';
    return _currentVodQuality;
  }

  /// Current playback position in milliseconds.
  @readonly
  int _positionMs = 0;

  /// Total duration in milliseconds (0 for live streams).
  @readonly
  int _durationMs = 0;

  /// Current playback rate (1.0 = normal speed).
  @readonly
  double _playbackRate = 1.0;

  /// Whether user is currently seeking (dragging the seek bar).
  @readonly
  bool _isSeeking = false;

  VideoStoreBase({
    required this.userLogin,
    required this.userId,
    required this.kickApi,
    required this.authStore,
    required this.settingsStore,
    required this.audioHandler,
  }) {
    // Initialize the AWS IVS player controller (for live streams)
    _ivsController = IvsPlayerController();

    // Setup player state listener
    _ivsController.addListener(_onPlayerStateChanged);

    // Initialize media_kit player (for VOD playback)
    _vodPlayer = Player();
    _vodController = VideoController(_vodPlayer);

    // Setup media_kit stream listeners for VOD state
    _setupVodStreamListeners();

    // Setup audio handler callbacks
    audioHandler.onPlayCallback = () async {
      if (_isPlayingVod) {
        _vodPlayer.play();
      } else {
        _ivsController.play(_playbackUrl!);
      }
    };
    audioHandler.onPauseCallback = () async {
      if (_isPlayingVod) {
        _vodPlayer.pause();
      } else {
        _ivsController.pause();
      }
    };
    audioHandler.onStopCallback = () async {
      if (_isPlayingVod) {
        _vodPlayer.pause();
      } else {
        _ivsController.pause(); // Just pause, don't stop stream to allow resume
      }
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

  /// Sets up stream listeners for media_kit player state (VOD playback).
  ///
  /// media_kit uses Dart streams to push state updates automatically,
  /// eliminating the need for polling timers used with IVS.
  void _setupVodStreamListeners() {
    // Listen to position updates
    _vodStreamSubscriptions.add(
      _vodPlayer.stream.position.listen((position) {
        if (!_isSeeking && _isPlayingVod) {
          runInAction(() {
            _positionMs = position.inMilliseconds;
          });
        }
      }),
    );

    // Listen to duration updates
    _vodStreamSubscriptions.add(
      _vodPlayer.stream.duration.listen((duration) {
        if (_isPlayingVod) {
          runInAction(() {
            _durationMs = duration.inMilliseconds;
          });
        }
      }),
    );

    // Listen to playing state
    _vodStreamSubscriptions.add(
      _vodPlayer.stream.playing.listen((playing) {
        if (_isPlayingVod) {
          runInAction(() {
            _paused = !playing;
            // Update Android PiP play state
            if (Platform.isAndroid) {
              pip.setIsPlaying(playing);
            }
            // Update audio handler state
            audioHandler.updatePlaybackState(
              isPlaying: playing,
              isBuffering: _isBuffering,
            );
          });
        }
      }),
    );

    // Listen to buffering state
    _vodStreamSubscriptions.add(
      _vodPlayer.stream.buffering.listen((buffering) {
        if (_isPlayingVod) {
          runInAction(() {
            _isBuffering = buffering;
            audioHandler.updatePlaybackState(
              isPlaying: !_paused,
              isBuffering: buffering,
            );
          });
        }
      }),
    );

    // Listen for playback completion
    _vodStreamSubscriptions.add(
      _vodPlayer.stream.completed.listen((completed) {
        if (completed && _isPlayingVod) {
          runInAction(() {
            _paused = true;
            _overlayVisible = true;
          });
        }
      }),
    );

    // Listen for errors - try lower quality on failure
    _vodStreamSubscriptions.add(
      _vodPlayer.stream.error.listen((error) {
        if (_isPlayingVod && error.isNotEmpty) {
          debugPrint('VOD playback error: $error');
          _tryNextVodQuality();
        }
      }),
    );
  }

  /// Try the next lower VOD quality when current quality fails.
  void _tryNextVodQuality() {
    if (_lastVod?.source == null) return;

    // Remove the failed quality from internal try list
    if (_vodQualitiesToTry.isNotEmpty) {
      final failedQuality = _vodQualitiesToTry.first;
      debugPrint('VOD quality $failedQuality failed, trying next...');

      _vodQualitiesToTry = List.from(_vodQualitiesToTry)..removeAt(0);

      // Also remove from user-facing list if it's there (not hidden fallback)
      if (_availableVodQualities.contains(failedQuality)) {
        runInAction(() {
          _availableVodQualities = List.from(_availableVodQualities)
            ..remove(failedQuality);
          // Adjust index if needed
          if (_vodQualityIndex >= _availableVodQualities.length &&
              _availableVodQualities.isNotEmpty) {
            _vodQualityIndex = _availableVodQualities.length - 1;
          }
        });
      }

      // Try next quality if available
      if (_vodQualitiesToTry.isNotEmpty) {
        final nextQuality = _vodQualitiesToTry.first;
        debugPrint('Trying VOD quality: $nextQuality');
        runInAction(() {
          _currentVodQuality = nextQuality;
        });
        final vodUrl = _getDirectQualityUrl(_lastVod!.source!, nextQuality);
        _vodPlayer.open(Media(vodUrl));
      } else {
        debugPrint('All VOD qualities failed');
        runInAction(() {
          _isPlayingVod = false;
          _paused = true;
        });
      }
    }
  }

  /// Handle IVS player state changes.
  void _onPlayerStateChanged() {
    final state = _ivsController.state;
    runInAction(() {
      switch (state) {
        case PlayerState.idle:
          _paused = true;
          _isBuffering = false;
          _overlayVisible = true;
          // Disable Auto PiP when idle
          if (Platform.isAndroid) {
            pip.setAutoPipMode(autoEnter: false);
          }
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
            pip.setAutoPipMode();
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
          _isPlayingVod = false;
        });

        // Try to fetch last playable VOD for offline viewing
        // Check subscription status to include subscriber-only VODs
        try {
          final videos = await kickApi.getChannelVideos(channelSlug: userLogin);

          // Check if user is subscribed to this channel
          bool isSubscriber = false;
          try {
            final meResponse = await kickApi.getChannelMe(
              channelSlug: userLogin,
            );
            isSubscriber = meResponse?.isSubscribed ?? false;
          } catch (e) {
            debugPrint('Could not check subscription status: $e');
          }

          // Find first playable VOD (public or subscriber-only for subscribers)
          final playableVod = videos.firstWhere(
            (v) => v.isPlayable(isSubscriber: isSubscriber),
            orElse: () => throw StateError('No playable videos'),
          );
          runInAction(() {
            _lastVod = playableVod;
          });
        } catch (e) {
          debugPrint('No VODs available: $e');
          runInAction(() {
            _lastVod = null;
          });
        }
      }

      // Only set playback URL when the channel is live
      // When offline, playbackUrl should be null so the offline UI shows
      if (channel.isLive) {
        final playbackUrl = channel.playbackUrl;
        runInAction(() {
          _playbackUrl = playbackUrl;
        });
      } else {
        runInAction(() {
          _playbackUrl = null;
        });
      }

      _initialLoadComplete = true;
    } catch (e) {
      debugPrint('Failed to initialize stream: $e');
    } finally {
      _isInitializing = false;
    }
  }

  @action
  Future<void> updateStreamQualities() async {
    // Skip when playing VOD - we use fixed quality with media_kit
    if (_isPlayingVod) return;

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
    // Skip during VOD playback - no live data to update
    if (_isPlayingVod) return;
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
    // Skip during VOD playback - no live data to update
    if (_isPlayingVod && !forceUpdate) return;

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

    // Stop VOD playback if active
    if (_isPlayingVod) {
      await _vodPlayer.stop();
      _isPlayingVod = false;
      _positionMs = 0;
      _durationMs = 0;
    }

    // Reset playback error retry state on manual refresh
    _playbackErrorRetryCount = 0;
    _lastPlaybackErrorTime = null;

    // Reset initialization flags to allow refresh
    _isInitializing = false;
    _initialLoadComplete = false;

    // Stop IVS playback
    await _ivsController.stop();

    // Re-fetch channel data and playback URL
    // This also updates stream info, no need to call updateStreamInfo separately
    await _initializeStream();

    // Explicitly resume playback if we have a URL and not offline
    if (_playbackUrl != null && _streamInfo != null) {
      await _ivsController.play(_playbackUrl!);
    }
  }

  /// Converts a master.m3u8 URL to a direct quality variant URL.
  ///
  /// Example:
  /// Input:  https://cdn.kick.com/hls/abc123/master.m3u8
  /// Output: https://cdn.kick.com/hls/abc123/1080p60/playlist.m3u8
  String _getDirectQualityUrl(String masterUrl, String quality) {
    // Replace master.m3u8 with {quality}/playlist.m3u8
    return masterUrl.replaceAll('master.m3u8', '$quality/playlist.m3u8');
  }

  /// Start playing the last available VOD using media_kit.
  ///
  /// Opens the VOD URL in the media_kit player which provides native seeking,
  /// accurate position tracking via streams, and playback rate control.
  /// Uses direct quality URL to bypass slow HLS master playlist parsing.
  @action
  void playLastVod([String? preferredQuality]) {
    if (_lastVod == null || _lastVod!.source == null) return;

    HapticFeedback.lightImpact();
    _isPlayingVod = true;
    _paused = false;

    // Stop all periodic API timers during VOD playback - no live data to update
    _stopViewerCountTimer();
    _stopStreamInfoTimer();

    // Reset playback rate and position for new VOD
    _playbackRate = 1.0;
    _positionMs = 0;
    _durationMs = 0;

    // Reset quality lists for new VOD
    _availableVodQualities = List.from(vodQualityPresets);
    _vodQualitiesToTry = List.from(_vodQualityFallbackOrder);
    _vodQualityIndex = 0;

    // Update audio handler metadata for VOD
    final title = _lastVod!.title.isNotEmpty ? _lastVod!.title : 'Last VOD';
    final artist =
        _offlineChannelInfo?.displayName ??
        _offlineChannelInfo?.slug ??
        'Kick Streamer';
    final artUri =
        _offlineChannelInfo?.bannerImage?.url ??
        _offlineChannelInfo?.user.profilePic ??
        _lastVod!.thumbnailUrl;

    audioHandler.updateMetadata(title: title, artist: artist, artUri: artUri);

    // Start with preferred quality if specified, otherwise highest available
    final startQuality = preferredQuality ?? _vodQualitiesToTry.first;
    debugPrint('Starting VOD playback with quality: $startQuality');

    runInAction(() {
      _currentVodQuality = startQuality;
    });

    final vodUrl = _getDirectQualityUrl(_lastVod!.source!, startQuality);
    debugPrint('VOD playback URL: $vodUrl');

    // Open VOD in media_kit player (auto-plays by default)
    _vodPlayer.open(Media(vodUrl));
  }

  /// Start playing a specific VOD using media_kit.
  ///
  /// This allows playing any VOD from a list, not just the last available one.
  /// Stores the VOD and starts playback with the highest available quality.
  @action
  void playVod(KickVideo video, [String? preferredQuality]) {
    if (video.source == null) return;

    // Store the video as lastVod so quality switching works
    _lastVod = video;

    HapticFeedback.lightImpact();
    _isPlayingVod = true;
    _paused = false;

    // Stop all periodic API timers during VOD playback - no live data to update
    _stopViewerCountTimer();
    _stopStreamInfoTimer();

    // Reset playback rate and position for new VOD
    _playbackRate = 1.0;
    _positionMs = 0;
    _durationMs = 0;

    // Reset quality lists for new VOD
    _availableVodQualities = List.from(vodQualityPresets);
    _vodQualitiesToTry = List.from(_vodQualityFallbackOrder);
    _vodQualityIndex = 0;

    // Update audio handler metadata for VOD
    final title = video.title.isNotEmpty ? video.title : 'VOD';
    final artist =
        _offlineChannelInfo?.displayName ??
        _offlineChannelInfo?.slug ??
        'Kick Streamer';
    final artUri =
        _offlineChannelInfo?.bannerImage?.url ??
        _offlineChannelInfo?.user.profilePic ??
        video.thumbnailUrl;

    audioHandler.updateMetadata(title: title, artist: artist, artUri: artUri);

    // Start with preferred quality if specified, otherwise highest available
    final startQuality = preferredQuality ?? _vodQualitiesToTry.first;
    debugPrint('Starting VOD playback with quality: $startQuality');

    runInAction(() {
      _currentVodQuality = startQuality;
    });

    final vodUrl = _getDirectQualityUrl(video.source!, startQuality);
    debugPrint('VOD playback URL: $vodUrl');

    // Open VOD in media_kit player (auto-plays by default)
    _vodPlayer.open(Media(vodUrl));
  }

  /// Change VOD quality manually by user.
  @action
  void setVodQuality(String quality) {
    if (!_isPlayingVod || _lastVod?.source == null) return;

    // Find the quality in the internal list
    final qualityIndex = _vodQualitiesToTry.indexOf(quality);
    if (qualityIndex == -1) return;

    HapticFeedback.lightImpact();

    // Move selected quality to front of the list
    runInAction(() {
      _vodQualitiesToTry = List.from(_vodQualitiesToTry)
        ..removeAt(qualityIndex)
        ..insert(0, quality);
      _currentVodQuality = quality;
    });

    debugPrint('Changing VOD quality to: $quality');
    final vodUrl = _getDirectQualityUrl(_lastVod!.source!, quality);
    _vodPlayer.open(Media(vodUrl));
  }

  /// Play or pause the video depending on the current state of [_paused].
  void handlePausePlay() {
    if (_isPlayingVod) {
      // Use media_kit for VOD playback
      if (_paused) {
        _vodPlayer.play();
      } else {
        _vodPlayer.pause();
      }
    } else {
      // Use IVS for live streams
      if (_paused) {
        if (_playbackUrl != null) {
          _ivsController.resume();
        }
      } else {
        _ivsController.pause();
      }
    }
  }

  // ============================================================
  // VOD Playback Control Methods (media_kit)
  // ============================================================

  /// Called when user starts dragging the seek bar.
  @action
  void onSeekStart() {
    _isSeeking = true;
  }

  /// Called while user is dragging the seek bar.
  @action
  void onSeekUpdate(int positionMs) {
    _positionMs = positionMs.clamp(
      0,
      _durationMs > 0 ? _durationMs : positionMs,
    );
  }

  /// Called when user finishes dragging the seek bar.
  @action
  Future<void> onSeekEnd(int positionMs) async {
    _isSeeking = false;
    await _vodPlayer.seek(Duration(milliseconds: positionMs));
  }

  /// Skip forward by the specified duration.
  Future<void> skipForward([
    Duration duration = const Duration(seconds: 10),
  ]) async {
    final newPosition = _positionMs + duration.inMilliseconds;
    final clampedPosition = newPosition.clamp(0, _durationMs);
    await _vodPlayer.seek(Duration(milliseconds: clampedPosition));
    runInAction(() {
      _positionMs = clampedPosition;
    });
  }

  /// Skip backward by the specified duration.
  Future<void> skipBackward([
    Duration duration = const Duration(seconds: 10),
  ]) async {
    final newPosition = _positionMs - duration.inMilliseconds;
    final clampedPosition = newPosition.clamp(0, _durationMs);
    await _vodPlayer.seek(Duration(milliseconds: clampedPosition));
    runInAction(() {
      _positionMs = clampedPosition;
    });
  }

  /// Set the playback rate (speed).
  @action
  Future<void> setPlaybackRate(double rate) async {
    await _vodPlayer.setRate(rate);
    _playbackRate = rate;
  }

  /// Cycle through common playback rates: 1.0 → 1.25 → 1.5 → 2.0 → 0.5 → 0.75 → 1.0
  @action
  Future<void> cyclePlaybackRate() async {
    const rates = [1.0, 1.25, 1.5, 2.0, 0.5, 0.75];
    final currentIndex = rates.indexOf(_playbackRate);
    final nextIndex = (currentIndex + 1) % rates.length;
    await setPlaybackRate(rates[nextIndex]);
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

    // Cancel media_kit stream subscriptions and dispose player
    for (final subscription in _vodStreamSubscriptions) {
      subscription.cancel();
    }
    _vodStreamSubscriptions.clear();
    _vodPlayer.dispose();

    // Clear audio handler callbacks
    audioHandler.onPlayCallback = null;
    audioHandler.onPauseCallback = null;
    audioHandler.onStopCallback = null;
    audioHandler.stop();
  }
}
