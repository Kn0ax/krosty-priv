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

  /// Global Kick emotes (from "Global" group).
  @readonly
  var _kickGlobalEmotes = <Emote>[];

  /// Kick Emoji emotes (from "Emoji" group).
  @readonly
  var _kickEmojiEmotes = <Emote>[];

  /// User's subscribed channel emotes grouped by channel name.
  /// Key is channel name/slug, value is list of emotes from that channel.
  @readonly
  var _userSubEmotesByChannel = <String, List<Emote>>{};

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
    for (final emote in _kickEmojiEmotes) {
      result[emote.name] = emote;
    }
    for (final channelEmotes in _userSubEmotesByChannel.values) {
      for (final emote in channelEmotes) {
        result[emote.name] = emote;
      }
    }
    for (final emote in _sevenTVGlobalEmotes) {
      result[emote.name] = emote;
    }
    return result;
  }

  /// Alias for globalEmoteMap - used by ChatAssetsStore.
  Map<String, Emote> get allEmotes => globalEmoteMap;

  /// Kick emotes as a map (name -> Emote) - global + emoji + user subs.
  Map<String, Emote> get kickEmotes {
    final result = <String, Emote>{};
    for (final emote in _kickGlobalEmotes) {
      result[emote.name] = emote;
    }
    for (final emote in _kickEmojiEmotes) {
      result[emote.name] = emote;
    }
    for (final channelEmotes in _userSubEmotesByChannel.values) {
      for (final emote in channelEmotes) {
        result[emote.name] = emote;
      }
    }
    return result;
  }

  /// User's subscribed channel emotes grouped by channel name.
  Map<String, List<Emote>> get userSubEmotesByChannel =>
      _userSubEmotesByChannel;

  /// User's subscribed channel emotes as a flat list (for backward compat).
  List<Emote> get userSubEmotesList =>
      _userSubEmotesByChannel.values.expand((e) => e).toList();

  /// Kick global emotes (including emoji) as a list.
  List<Emote> get kickGlobalEmotesList => [
    ..._kickGlobalEmotes,
    ..._kickEmojiEmotes,
  ];

  /// 7TV global emotes as a list.
  List<Emote> get sevenTVGlobalEmotesList => _sevenTVGlobalEmotes;

  // ============= Setters for External Population =============

  /// Set global Kick emotes (called by ChatAssetsStore after parsing response).
  @action
  void setGlobalEmotes(List<Emote> emotes) {
    _kickGlobalEmotes = emotes;
  }

  /// Set Kick emoji emotes (called by ChatAssetsStore after parsing response).
  @action
  void setEmojiEmotes(List<Emote> emotes) {
    _kickEmojiEmotes = emotes;
  }

  /// Add emotes from a subscribed channel to the user sub emotes.
  /// [channelName] is the display name of the channel (e.g., "xQc").
  @action
  void addUserSubEmotes(String channelName, List<Emote> emotes) {
    if (emotes.isEmpty) return;
    // Create new map to trigger MobX reactivity
    _userSubEmotesByChannel = {..._userSubEmotesByChannel, channelName: emotes};
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
      // 7TV global emotes (the only thing we can fetch without a channel context)
      if (show7TVEmotes)
        sevenTVApi
            .getEmotesGlobal()
            .then((emotes) => _sevenTVGlobalEmotes = emotes)
            .catchError((e) {
              _sevenTVGlobalEmotes = onEmoteError(e);
              return _sevenTVGlobalEmotes;
            }),
      // Note: Kick global/emoji emotes are now populated by ChatAssetsStore
      // when it fetches emotes for a channel (first channel fetch populates globals)
    ]);
  }
}
