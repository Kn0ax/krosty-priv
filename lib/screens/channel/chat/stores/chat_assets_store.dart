import 'package:flutter/foundation.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/apis/seventv_api.dart';
import 'package:krosty/models/emotes.dart';
import 'package:krosty/models/kick_channel.dart';
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

  /// Subscriber badges for the current channel.
  @readonly
  List<KickSubscriberBadge> _subscriberBadges = [];

  /// Whether the user is subscribed to this channel.
  @readonly
  bool _isSubscribedToChannel = false;

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

  /// Get current channel's Kick emotes only.
  List<Emote> get kickChannelEmotesList => _channelEmotes.values
      .where((e) => e.type == EmoteType.kickChannel)
      .toList();

  /// Get current channel's 7TV emotes only.
  List<Emote> get sevenTVChannelEmotesList => _channelEmotes.values
      .where((e) => e.type == EmoteType.sevenTVChannel)
      .toList();

  /// Get user's subscribed channel emotes grouped by channel name.
  Map<String, List<Emote>> get userSubEmotesByChannel =>
      globalAssetsStore.userSubEmotesByChannel;

  /// Get user's subscribed channel emotes (from other channels) - flat list.
  List<Emote> get userSubEmotesList => globalAssetsStore.userSubEmotesList;

  /// Get Kick global emotes (including emoji).
  List<Emote> get kickGlobalEmotesList =>
      globalAssetsStore.kickGlobalEmotesList;

  /// Get 7TV global emotes.
  List<Emote> get sevenTVGlobalEmotesList =>
      globalAssetsStore.sevenTVGlobalEmotesList;

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

      // Ensure global assets are loaded (7TV globals)
      futures.add(
        globalAssetsStore.ensureLoaded(
          showKickEmotes: showKickEmotes,
          show7TVEmotes: show7TVEmotes,
        ),
      );

      // Kick channel emotes (this also populates global/emoji emotes)
      if (showKickEmotes) {
        futures.add(_fetchKickEmotes());
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

  /// Fetch Kick emotes and parse them by group type.
  /// This populates:
  /// - Global emotes -> globalAssetsStore
  /// - Emoji emotes -> globalAssetsStore
  /// - User's subscribed channel emotes -> globalAssetsStore (grouped by channel)
  /// - Current channel emotes -> _channelEmotes (filtered by subscription)
  Future<void> _fetchKickEmotes() async {
    try {
      final groups = await kickApi.getEmotes(channelSlug: channelSlug);

      // Check subscription status for current channel
      final meResponse = await kickApi.getChannelMe(channelSlug: channelSlug);
      _isSubscribedToChannel = meResponse?.isSubscribed ?? false;

      final globalEmotes = <Emote>[];
      final emojiEmotes = <Emote>[];

      for (final group in groups) {
        // Check if this is a Global group (id is string "Global")
        if (group.id == 'Global' || group.name == 'Global') {
          globalEmotes.addAll(
            group.emotes.map((e) => Emote.fromKick(e, EmoteType.kickGlobal)),
          );
          continue;
        }

        // Check if this is an Emoji group (id is string "Emoji")
        if (group.id == 'Emoji' || group.name == 'Emojis') {
          emojiEmotes.addAll(
            group.emotes.map((e) => Emote.fromKick(e, EmoteType.kickGlobal)),
          );
          continue;
        }

        // Check if this is the current channel's emotes
        if (group.slug?.toLowerCase() == channelSlug.toLowerCase()) {
          // Current channel emotes - filter by subscription status
          for (final emote in group.emotes) {
            // If subscribers_only and user is not subscribed, skip
            if (emote.subscribersOnly && !_isSubscribedToChannel) {
              continue;
            }
            final converted = Emote.fromKick(emote, EmoteType.kickChannel);
            _channelEmotes[converted.name] = converted;
          }
          continue;
        }

        // Any other group with numeric ID is a user's subscribed channel
        // (the API only returns channels the user is subscribed to)
        // Skip the current channel - it's already shown in "Channel" tab
        // Use displayName (user.username or name) for the tab label
        if (group.id is int && group.displayName != null) {
          // Skip if this is the current channel we're watching
          if (group.slug?.toLowerCase() == channelSlug.toLowerCase()) {
            continue;
          }
          final channelEmotes = group.emotes
              .map((e) => Emote.fromKick(e, EmoteType.kickChannel))
              .toList();
          if (channelEmotes.isNotEmpty) {
            globalAssetsStore.addUserSubEmotes(
              group.displayName!,
              channelEmotes,
            );
          }
        }
      }

      // Populate global assets store (only if we got emotes)
      if (globalEmotes.isNotEmpty) {
        globalAssetsStore.setGlobalEmotes(globalEmotes);
      }
      if (emojiEmotes.isNotEmpty) {
        globalAssetsStore.setEmojiEmotes(emojiEmotes);
      }
    } catch (e) {
      // Silently fail - channel may not have emotes
      debugPrint('Error fetching Kick emotes: $e');
    }
  }

  /// Fetch 7TV channel emotes.
  Future<void> _fetch7TVChannelEmotes() async {
    try {
      // First, get the channel to retrieve user_id from v2 channels endpoint
      final channel = await kickApi.getChannel(channelSlug: channelSlug);
      final userId = channel.user.id;

      // Store subscriber badges from channel info
      if (channel.subscriberBadges != null) {
        _subscriberBadges = channel.subscriberBadges!;
      }

      // Use user_id (not slug) for 7TV API
      final (_, emotes) = await sevenTVApi.getEmotesChannel(userId: userId);

      for (final emote in emotes) {
        _channelEmotes[emote.name] = emote;
      }
    } catch (e) {
      // Silently fail - 7TV may not be connected or channel may not exist
    }
  }

  /// Get the subscriber badge URL for a given month count.
  String? getSubscriberBadgeUrl(int months) {
    if (_subscriberBadges.isEmpty) return null;

    // Find the highest tier badge that the user qualifies for
    final sortedBadges = [..._subscriberBadges]
      ..sort((a, b) => b.months.compareTo(a.months));

    for (final badge in sortedBadges) {
      if (months >= badge.months) {
        return badge.badgeImage?.src;
      }
    }
    return null;
  }

  /// Clear all channel-specific assets.
  void dispose() {
    _channelEmotes.clear();
  }
}
