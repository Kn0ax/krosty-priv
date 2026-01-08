import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/models/emotes.dart';

/// The 7TV service for making API calls.
/// Updated for Kick platform support.
class SevenTVApi extends BaseApiClient {
  SevenTVApi(Dio dio) : super(dio, 'https://7tv.io/v3');

  /// Returns a list of global 7TV emotes.
  Future<List<Emote>> getEmotesGlobal() async {
    final data = await get<JsonMap>('/emote-sets/global');

    final decoded = data['emotes'] as JsonList;
    final emotes = decoded.map((emote) => Emote7TV.fromJson(emote));

    return emotes
        .map((emote) => Emote.from7TV(emote, EmoteType.sevenTVGlobal))
        .toList();
  }

  /// Returns a tuple containing the emote set ID and a list of a Kick channel's
  /// 7TV emotes.
  ///
  /// Uses the Kick platform endpoint: `/users/kick/{channel_slug}`
  Future<(String, List<Emote>)> getEmotesChannel({
    required String channelSlug,
  }) async {
    try {
      // 7TV uses 'kick' as the platform identifier for Kick channels
      final data = await get<JsonMap>('/users/kick/$channelSlug');

      // Handle case where emote_set might be null
      final emoteSet = data['emote_set'] as Map<String, dynamic>?;
      if (emoteSet == null) {
        debugPrint('No 7TV emote set found for Kick channel: $channelSlug');
        return ('', <Emote>[]);
      }

      final emoteSetId = emoteSet['id'] as String? ?? '';
      final emotesList = emoteSet['emotes'] as List<dynamic>? ?? [];

      final emotes = emotesList.map((emote) => Emote7TV.fromJson(emote));

      return (
        emoteSetId,
        emotes
            .map((emote) => Emote.from7TV(emote, EmoteType.sevenTVChannel))
            .where((emote) => emote.url.isNotEmpty)
            .toList(),
      );
    } on NotFoundException {
      // Channel doesn't have 7TV emotes
      debugPrint('Kick channel $channelSlug not found on 7TV');
      return ('', <Emote>[]);
    } catch (e) {
      debugPrint('Error fetching 7TV emotes for $channelSlug: $e');
      return ('', <Emote>[]);
    }
  }

  /// Returns the user connection data for a Kick channel.
  /// This includes the emote set ID needed for real-time updates.
  Future<String?> getChannelEmoteSetId({required String channelSlug}) async {
    try {
      final data = await get<JsonMap>('/users/kick/$channelSlug');
      final emoteSet = data['emote_set'] as Map<String, dynamic>?;
      return emoteSet?['id'] as String?;
    } catch (e) {
      debugPrint('Error fetching 7TV emote set ID for $channelSlug: $e');
      return null;
    }
  }
}
