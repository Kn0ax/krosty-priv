import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:krosty/apis/base_api_client.dart';
import 'package:krosty/models/emotes.dart';

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
  /// Uses the Kick platform endpoint: `/users/kick/{user_id}`
  /// Requires the user_id from Kick API v2 channels endpoint.
  Future<(String, List<Emote>)> getEmotesChannel({
    required int userId,
  }) async {
    try {
      // 7TV uses 'kick' as the platform identifier and user_id (not slug)
      final data = await get<JsonMap>('/users/kick/$userId');

      // Handle case where emote_set might be null
      final emoteSet = data['emote_set'] as Map<String, dynamic>?;
      if (emoteSet == null) {
        debugPrint('No 7TV emote set found for Kick user ID: $userId');
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
      debugPrint('Kick user ID $userId not found on 7TV');
      return ('', <Emote>[]);
    } catch (e) {
      debugPrint('Error fetching 7TV emotes for user ID $userId: $e');
      return ('', <Emote>[]);
    }
  }

  /// Returns the user connection data for a Kick channel.
  /// This includes the emote set ID needed for real-time updates.
  /// Requires the user_id from Kick API v2 channels endpoint.
  Future<String?> getChannelEmoteSetId({required int userId}) async {
    try {
      final data = await get<JsonMap>('/users/kick/$userId');
      final emoteSet = data['emote_set'] as Map<String, dynamic>?;
      return emoteSet?['id'] as String?;
    } catch (e) {
      debugPrint('Error fetching 7TV emote set ID for user ID $userId: $e');
      return null;
    }
  }
}
