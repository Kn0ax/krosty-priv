import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

/// A singleton audio handler that manages the system media session and background playback.
///
/// Despite the name "AudioHandler", this is used for both Audio and Video content
/// to provide system-level media controls (notification, lock screen, etc.).
class KrostyAudioHandler extends BaseAudioHandler {
  // Callbacks for UI to listen to
  Future<void> Function()? onPlayCallback;
  Future<void> Function()? onPauseCallback;
  Future<void> Function()? onStopCallback;

  KrostyAudioHandler() {
    _initAudioSession();
    _initInitialState();
  }

  void _initInitialState() {
    mediaItem.add(
      const MediaItem(id: 'krosty_init', title: 'Not Playing', album: 'Krosty'),
    );
    playbackState.add(
      PlaybackState(
        controls: [],
        systemActions: {},
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.moviePlayback,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.movie,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );
  }

  /// Updates the current media item (title, artist, artwork).
  Future<void> updateMetadata({
    required String title,
    required String artist,
    String? artUri,
  }) async {
    mediaItem.add(
      MediaItem(
        id: 'krosty_livestream',
        album: 'Kick Livestream',
        title: title,
        artist: artist,
        artUri: artUri != null ? Uri.parse(artUri) : null,
        duration: null, // Livestreams have no duration
      ),
    );
  }

  /// Updates the specific playback state.
  Future<void> updatePlaybackState({
    required bool isPlaying,
    required bool isBuffering,
  }) async {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1],
        processingState: isBuffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: isPlaying,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
        queueIndex: 0,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (onPlayCallback != null) {
      await onPlayCallback!();
    }
  }

  @override
  Future<void> pause() async {
    if (onPauseCallback != null) {
      await onPauseCallback!();
    }
  }

  @override
  Future<void> stop() async {
    if (onStopCallback != null) {
      await onStopCallback!();
    }
    // Also stop system playback state
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }
}
