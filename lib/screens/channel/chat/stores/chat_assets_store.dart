import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/apis/seventv_api.dart';
import 'package:krosty/models/emotes.dart';
import 'package:krosty/stores/global_assets_store.dart';
import 'package:mobx/mobx.dart';

part 'chat_assets_store.g.dart';

class ChatAssetsStore = ChatAssetsStoreBase with _$ChatAssetsStore;

/// Store for managing chat emotes for a specific channel.
/// Supports Kick channel emotes and 7TV emotes.
abstract class ChatAssetsStoreBase with Store {
  final KickApi kickApi;
  final SevenTVApi sevenTVApi;
  final GlobalAssetsStore globalAssetsStore;

  /// The current channel slug.
  final String channelSlug;

  ChatAssetsStoreBase({
    required this.kickApi,
    required this.sevenTVApi,
    required this.globalAssetsStore,
    required this.channelSlug,
  });

  /// Emotes specific to the current channel.
  @readonly
  ObservableMap<String, Emote> _channelEmotes = ObservableMap();

  /// Combined emotes (channel + global) for quick lookup.
  @computed
  Map<String, Emote> get emotes {
    final allEmotes = <String, Emote>{};

    // Add global emotes first
    allEmotes.addAll(globalAssetsStore.allEmotes);

    // Add channel emotes (override global if same name)
    allEmotes.addAll(_channelEmotes);

    return allEmotes;
  }

  /// Alias for emotes getter for compatibility.
  Map<String, Emote> get emoteToObject => emotes;

  /// User emotes - currently using global kick emotes.
  Map<String, Emote> get userEmoteToObject => globalAssetsStore.kickEmotes;

  /// Recent emotes used by the user.
  final recentEmotes = ObservableList<Emote>();

  /// Whether assets are currently loading.
  @readonly
  bool _isLoading = false;

  /// Any error that occurred during loading.
  @readonly
  String? _error;

  /// Whether to show the emote menu.
  @observable
  bool showEmoteMenu = false;

  /// Get all emotes as a list (for emote menu).
  List<Emote> get emotesList => emotes.values.toList();

  /// Check if emote is from Kick.
  bool isKick(Emote emote) =>
      emote.type == EmoteType.kickGlobal || emote.type == EmoteType.kickChannel;

  /// Check if emote is from 7TV.
  bool is7TV(Emote emote) =>
      emote.type == EmoteType.sevenTVGlobal ||
      emote.type == EmoteType.sevenTVChannel;

  /// Initialize the store.
  void init() {
    // Nothing special to initialize
  }

  /// Fetch all assets for the channel.
  @action
  Future<void> fetchAssets({
    bool showKickEmotes = true,
    bool show7TVEmotes = true,
  }) async {
    _isLoading = true;
    _error = null;

    try {
      final futures = <Future>[];

      // Ensure global assets are loaded
      futures.add(
        globalAssetsStore.ensureLoaded(
          showKickEmotes: showKickEmotes,
          show7TVEmotes: show7TVEmotes,
        ),
      );

      // Kick channel emotes
      if (showKickEmotes) {
        futures.add(_fetchKickChannelEmotes());
      }

      // 7TV channel emotes
      if (show7TVEmotes) {
        futures.add(_fetch7TVChannelEmotes());
      }

      await Future.wait(futures);
    } catch (e) {
      _error = 'Failed to load chat assets: $e';
    }

    _isLoading = false;
  }

  /// Fetch Kick channel emotes.
  Future<void> _fetchKickChannelEmotes() async {
    try {
      final groups = await kickApi.getEmotes(channelSlug: channelSlug);

      // Find the group for this channel
      // The API returns groups for Global, Emojis, and the Channel itself.
      // The channel group usually has the slug matching the requested channel.
      final channelGroup = groups.firstWhereOrNull(
        (g) =>
            g.slug == channelSlug ||
            (g.slug?.toLowerCase() == channelSlug.toLowerCase()),
      );

      if (channelGroup != null) {
        for (final emote in channelGroup.emotes) {
          final converted = Emote.fromKick(emote, EmoteType.kickChannel);
          _channelEmotes[converted.name] = converted;
        }
      }
    } catch (e) {
      // Silently fail - channel may not have emotes
      debugPrint('Error fetching Kick channel emotes: $e');
    }
  }

  /// Fetch 7TV channel emotes.
  Future<void> _fetch7TVChannelEmotes() async {
    try {
      // First, get the channel to retrieve user_id from v2 channels endpoint
      final channel = await kickApi.getChannel(channelSlug: channelSlug);
      final userId = channel.user.id;

      // Use user_id (not slug) for 7TV API
      final (_, emotes) = await sevenTVApi.getEmotesChannel(userId: userId);

      for (final emote in emotes) {
        _channelEmotes[emote.name] = emote;
      }
    } catch (e) {
      // Silently fail - 7TV may not be connected or channel may not exist
    }
  }

  /// Clear all channel-specific assets.
  void dispose() {
    _channelEmotes.clear();
  }
}
