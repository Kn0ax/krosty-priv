import 'package:flutter/foundation.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/apis/seventv_api.dart';
import 'package:krosty/models/emotes.dart';
import 'package:mobx/mobx.dart';

part 'global_assets_store.g.dart';

/// Singleton-like store for caching global emotes.
/// Provided at app root level via Provider, shared across all chat tabs.
class GlobalAssetsStore = GlobalAssetsStoreBase with _$GlobalAssetsStore;

abstract class GlobalAssetsStoreBase with Store {
  final KickApi kickApi;
  final SevenTVApi sevenTVApi;

  GlobalAssetsStoreBase({required this.kickApi, required this.sevenTVApi});

  // ============= Loading State =============

  /// Whether global assets have been loaded at least once.
  @readonly
  var _isLoaded = false;

  /// Whether global assets are currently being fetched.
  @readonly
  var _isLoading = false;

  /// Completer to allow multiple callers to await the same load operation.
  Future<void>? _loadingFuture;

  // ============= Global Emotes =============

  /// Global Kick emotes.
  @readonly
  var _kickGlobalEmotes = <Emote>[];

  /// Global 7TV emotes.
  @readonly
  var _sevenTVGlobalEmotes = <Emote>[];

  // ============= Computed Properties =============

  /// All global emotes combined into a single map (name -> Emote).
  @computed
  Map<String, Emote> get globalEmoteMap {
    final result = <String, Emote>{};
    for (final emote in _kickGlobalEmotes) {
      result[emote.name] = emote;
    }
    for (final emote in _sevenTVGlobalEmotes) {
      result[emote.name] = emote;
    }
    return result;
  }

  /// Alias for globalEmoteMap - used by ChatAssetsStore.
  Map<String, Emote> get allEmotes => globalEmoteMap;

  /// Kick emotes as a map (name -> Emote).
  Map<String, Emote> get kickEmotes {
    final result = <String, Emote>{};
    for (final emote in _kickGlobalEmotes) {
      result[emote.name] = emote;
    }
    return result;
  }

  // ============= Methods =============

  /// Ensures global assets are loaded. Safe to call multiple times.
  /// Returns immediately if already loaded, or waits for in-progress load.
  @action
  Future<void> ensureLoaded({
    bool showKickEmotes = true,
    bool show7TVEmotes = true,
  }) async {
    // Already loaded - return immediately
    if (_isLoaded) return;

    // Currently loading - wait for existing operation
    if (_isLoading && _loadingFuture != null) {
      await _loadingFuture;
      return;
    }

    // Start new load operation
    _isLoading = true;
    _loadingFuture = _fetchGlobalAssets(
      showKickEmotes: showKickEmotes,
      show7TVEmotes: show7TVEmotes,
    );

    await _loadingFuture;
    _isLoading = false;
    _isLoaded = true;
    _loadingFuture = null;
  }

  /// Force refresh global assets (e.g., when settings change).
  @action
  Future<void> refresh({
    bool showKickEmotes = true,
    bool show7TVEmotes = true,
  }) async {
    _isLoaded = false;
    await ensureLoaded(
      showKickEmotes: showKickEmotes,
      show7TVEmotes: show7TVEmotes,
    );
  }

  @action
  Future<void> _fetchGlobalAssets({
    required bool showKickEmotes,
    required bool show7TVEmotes,
  }) async {
    // Error handler for emotes
    List<Emote> onEmoteError(dynamic error) {
      debugPrint('GlobalAssetsStore emote error: $error');
      return <Emote>[];
    }

    await Future.wait([
      // Kick global emotes
      if (showKickEmotes)
        kickApi
            .getEmotes(
              channelSlug: 'xqc',
            ) // Use 'xqc' or any valid channel to get globals
            .then((groups) {
              final globals = <Emote>[];
              for (final group in groups) {
                // Global and Emoji groups usually have string IDs or specific names
                if (group.id == 'Global' ||
                    group.id == 'Emoji' ||
                    group.name == 'Global' ||
                    group.name == 'Emojis') {
                  globals.addAll(
                    group.emotes.map(
                      (e) => Emote.fromKick(e, EmoteType.kickGlobal),
                    ),
                  );
                }
              }
              _kickGlobalEmotes = globals;
            })
            .catchError((e) {
              _kickGlobalEmotes = onEmoteError(e);
            }),
      // 7TV global emotes
      if (show7TVEmotes)
        sevenTVApi
            .getEmotesGlobal()
            .then((emotes) => _sevenTVGlobalEmotes = emotes)
            .catchError((e) {
              _sevenTVGlobalEmotes = onEmoteError(e);
              return _sevenTVGlobalEmotes;
            }),
    ]);
  }
}
