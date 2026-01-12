import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:krosty/apis/base_api_client.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/models/kick_channel_user_info.dart';
import 'package:krosty/models/kick_chatroom_state.dart';
import 'package:krosty/models/kick_silenced_user.dart';
import 'package:krosty/models/kick_user.dart';
import 'package:krosty/utils.dart';

/// The Kick API service for making API calls.
///
/// Uses a combination of:
/// - Official API (docs.kick.com): OAuth, authenticated endpoints
/// - Internal API (kick.com/api): Channel data, livestreams, categories
class KickApi extends BaseApiClient {
  // Internal API base URLs (reverse-engineered, more complete data)
  static const String _internalV1Url = 'https://web.kick.com/api/v1';
  static const String _internalV2Url = 'https://kick.com/api/v2';

  // Official API base URL (documented, OAuth endpoints)
  //  static const String _officialBaseUrl = 'https://api.kick.com/public/v1';
  static const String _oauthBaseUrl = 'https://id.kick.com/oauth';

  /// In-flight channel requests for deduplication.
  /// Prevents multiple concurrent requests to the same channel endpoint.
  final _inFlightChannelRequests = <String, Future<KickChannel>>{};

  KickApi(Dio dio) : super(dio, _internalV1Url);

  // ============================================================
  // CHANNEL ENDPOINTS (Internal API - more complete data)
  // ============================================================

  /// Returns detailed channel info including chatroom_id.
  /// Uses internal API v2 for channel data.
  ///
  /// Concurrent requests to the same channel are deduplicated - only one
  /// network request is made and the result is shared across all callers.
  Future<KickChannel> getChannel({required String channelSlug}) async {
    final slug = normalizeSlug(channelSlug.toLowerCase());

    // Check for in-flight request (deduplication)
    final inFlight = _inFlightChannelRequests[slug];
    if (inFlight != null) {
      debugPrint('⏳ Reusing in-flight request for channel: $slug');
      return inFlight;
    }

    // Create and track the request
    final future = _fetchChannel(slug);
    _inFlightChannelRequests[slug] = future;

    try {
      return await future;
    } finally {
      _inFlightChannelRequests.remove(slug);
    }
  }

  /// Internal fetch without deduplication logic.
  Future<KickChannel> _fetchChannel(String channelSlug) async {
    final data = await get<JsonMap>('$_internalV2Url/channels/$channelSlug');
    return KickChannel.fromJson(data);
  }

  /// Returns chatroom state/settings including chat modes and restrictions.
  ///
  /// This includes slow mode, followers-only mode, subscribers-only mode,
  /// emotes-only mode, account age requirements, etc.
  Future<KickChatroomState> getChatroomState({
    required String channelSlug,
  }) async {
    final slug = normalizeSlug(channelSlug.toLowerCase());
    final data = await get<JsonMap>('$_internalV2Url/channels/$slug/chatroom');
    return KickChatroomState.fromJson(data);
  }

  // ============================================================
  // SEARCH HELPERS
  // ============================================================

  /// Shared Typesense search implementation.
  /// Returns list of document maps from search hits.
  Future<List<Map<String, dynamic>>> _searchTypesense({
    required String preset,
    required String query,
  }) async {
    final data = await post<JsonMap>(
      'https://search.kick.com/multi_search',
      data: {
        'searches': [
          {'preset': preset, 'q': query},
        ],
      },
      headers: {'x-typesense-api-key': 'nXIMW0iEN6sMujFYjFuhdrSwVow3pDQu'},
    );

    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return [];

    final hits = results[0]['hits'] as List<dynamic>?;
    if (hits == null) return [];

    return hits.map((hit) => hit['document'] as Map<String, dynamic>).toList();
  }

  /// Parse search ID which may be int or string.
  int _parseSearchId(dynamic id) {
    if (id is int) return id;
    return int.tryParse(id.toString()) ?? 0;
  }

  /// Returns channel info by ID.
  Future<KickChannel> getChannelById({required int channelId}) async {
    // Internal API doesn't have direct ID lookup, use slug from search
    throw UnimplementedError('Use getChannel with slug instead');
  }

  // ============================================================
  // LIVESTREAM ENDPOINTS (Internal API)
  // ============================================================

  /// Returns a paginated list of livestreams sorted by viewer count.
  ///
  /// Uses the new unified endpoint that supports:
  /// - Cursor-based pagination via [afterCursor]
  /// - Optional category filtering via [categoryId]
  /// - Configurable [limit] (default 24)
  Future<KickLivestreamsResponse> getLivestreams({
    int limit = 24,
    int? categoryId,
    String? afterCursor,
  }) async {
    final data = await get<JsonMap>(
      '$_internalV1Url/livestreams',
      queryParameters: {
        'limit': limit,
        'sort': 'viewer_count_desc',
        if (categoryId != null) 'category_id': categoryId,
        if (afterCursor != null) 'after': afterCursor,
      },
    );

    return KickLivestreamsResponse.fromLivestreamsJson(data);
  }

  /// Returns the current viewer count for a livestream.
  ///
  /// Uses the lightweight /current-viewers endpoint which is much faster
  /// than fetching full channel data. The [livestreamId] is the livestream ID
  /// from the channel's livestream object.
  ///
  /// Returns null if the viewer count cannot be fetched.
  Future<int?> getLivestreamViewerCount({required int livestreamId}) async {
    try {
      final data = await get<JsonList>(
        'https://kick.com/current-viewers?ids[]=$livestreamId',
      );

      if (data.isNotEmpty) {
        final item = data.first as Map<String, dynamic>;
        return item['viewers'] as int?;
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('Failed to get livestream viewer count: $e');
      return null;
    }
  }

  /// Returns a list of featured livestreams.
  @Deprecated('Use getLivestreams() instead for better pagination support')
  Future<KickLivestreamsResponse> getFeaturedLivestreams({
    int? page,
    String lang = 'en', // TODO: switch to locale
  }) async {
    final data = await get<JsonMap>(
      '$_internalV1Url/livestreams/featured?language=$lang',
      queryParameters: page != null ? {'page': page.toString()} : null,
    );

    // Featured endpoint has structure: { data: { livestreams: [...] } }
    // Unlike others which are { data: [...] }
    final livestreamsData = data['data'];
    final livestreams = switch (livestreamsData) {
      {'livestreams': final List items} =>
        items.map((e) => KickLivestreamItem.fromJson(e)).toList(),
      final List items =>
        items.map((e) => KickLivestreamItem.fromJson(e)).toList(),
      _ => <KickLivestreamItem>[],
    };

    // Featured response doesn't seem to include standard pagination meta
    return KickLivestreamsResponse(data: livestreams);
  }

  /// Returns livestreams for a specific category.
  @Deprecated('Use getLivestreams(categoryId: id) instead')
  Future<KickLivestreamsResponse> getLivestreamsByCategory({
    required String categorySlug,
    int? page,
  }) async {
    final data = await get<JsonMap>(
      '$_internalV2Url/categories/${normalizeSlug(categorySlug)}/streams',
      queryParameters: page != null ? {'page': page.toString()} : null,
    );

    return KickLivestreamsResponse.fromJson(data);
  }

  /// Returns live streams from followed channels (requires auth).
  /// Uses /api/v1/user/livestreams - returns full stream details with thumbnails.
  Future<List<KickLivestreamItem>> getFollowedLivestreams() async {
    // This endpoint requires authentication
    final data = await get<List<dynamic>>(
      'https://kick.com/api/v1/user/livestreams',
    );

    return data
        .map(
          (item) => KickLivestreamItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  /// Returns all followed channels with pagination (requires auth).
  /// Uses /api/v2/channels/followed-page - returns basic channel info.
  Future<KickFollowedChannelsResponse> getFollowedChannelsPage({
    int cursor = 0,
  }) async {
    final data = await get<JsonMap>(
      '$_internalV2Url/channels/followed-page',
      queryParameters: {'cursor': cursor.toString()},
    );

    return KickFollowedChannelsResponse.fromJson(data);
  }

  // ============================================================
  // USER ENDPOINTS
  // ============================================================

  /// Returns current authenticated user info.
  Future<KickUser> getCurrentUser() async {
    // Auth headers are automatically added by KickAuthInterceptor
    final data = await get<JsonMap>('https://kick.com/api/v1/user');
    return KickUser.fromJson(data);
  }

  /// Returns user info by username.
  /// Uses V2 API via getChannel since /api/v1/users/{username} is deprecated/broken.
  Future<KickUser> getUser({required String username}) async {
    try {
      final channel = await getChannel(channelSlug: username);
      return channel.user;
    } catch (e) {
      debugPrint('Failed to get user by calling getChannel: $e');
      rethrow;
    }
  }

  /// Returns user info in the context of a specific channel.
  /// Includes badges, mod status, following/subscription info for that channel.
  Future<KickChannelUserInfo> getChannelUserInfo({
    required String channelSlug,
    required String userSlug,
  }) async {
    final data = await get<JsonMap>(
      '$_internalV2Url/channels/${normalizeSlug(channelSlug)}/users/$userSlug',
    );
    return KickChannelUserInfo.fromJson(data);
  }

  // ============================================================
  // CATEGORY ENDPOINTS (Internal API)
  // ============================================================

  /// Returns top/popular categories.
  Future<KickCategoriesResponse> getTopCategories({int? page}) async {
    final queryParams = <String, dynamic>{'limit': 32};
    if (page != null) queryParams['page'] = page.toString();

    final data = await get<JsonMap>(
      'https://kick.com/api/v1/subcategories',
      queryParameters: queryParams,
    );

    return KickCategoriesResponse.fromJson(data);
  }

  /// Returns all categories.
  Future<List<KickCategory>> getCategories() async {
    final data = await get<JsonList>('$_internalV1Url/categories');
    return data.map((c) => KickCategory.fromJson(c)).toList();
  }

  /// Returns category info by slug.
  Future<KickCategory> getCategory({required String categorySlug}) async {
    final data = await get<JsonMap>(
      '$_internalV1Url/categories/${normalizeSlug(categorySlug)}',
    );
    return KickCategory.fromJson(data);
  }

  // ============================================================
  // SEARCH ENDPOINTS (Internal API)
  // ============================================================

  /// Search for channels by query.
  Future<List<KickChannelSearch>> searchChannels({
    required String query,
  }) async {
    try {
      final hits = await _searchTypesense(
        preset: 'channel_search',
        query: query,
      );

      return hits.map((doc) {
        final id = _parseSearchId(doc['id']);
        return KickChannelSearch(
          id: id,
          slug: doc['slug'] as String? ?? '',
          username: doc['username'] as String? ?? '',
          profilePic: doc['profile_pic'] as String?,
          isLive: doc['is_live'] as bool? ?? false,
          isVerified: doc['verified'] as bool? ?? false,
          viewerCount: doc['viewer_count'] as int?,
          startTime: doc['start_time'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Search channels failed: $e');
      return [];
    }
  }

  /// Search for categories by query.
  Future<List<KickCategory>> searchCategories({required String query}) async {
    try {
      final hits = await _searchTypesense(
        preset: 'category_search',
        query: query,
      );

      return hits.map((doc) {
        final id = _parseSearchId(doc['id']);
        final bannerUrl = doc['src'] as String?;
        return KickCategory(
          id: id,
          categoryId: doc['category_id'] as int?,
          name: doc['name'] as String? ?? '',
          slug: doc['slug'] as String? ?? '',
          banner: bannerUrl != null ? KickCategoryBanner(url: bannerUrl) : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('Search categories failed: $e');
      return [];
    }
  }

  // ============================================================
  // CHAT ENDPOINTS (Official API for sending)
  // ============================================================

  /// Send a chat message (requires authentication).
  ///
  /// For replies, provide [replyToMessage] and [replyToSender] with full data.
  /// The API requires type "reply" with complete original message content and sender info.
  Future<bool> sendChatMessage({
    required int chatroomId,
    required String content,
    KickReplyData? replyTo,
  }) async {
    try {
      final data = <String, dynamic>{'content': content};

      if (replyTo != null) {
        data['type'] = 'reply';
        data['metadata'] = {
          'original_message': {
            'id': replyTo.messageId,
            'content': replyTo.messageContent,
          },
          'original_sender': {
            'id': replyTo.senderId,
            'username': replyTo.senderUsername,
          },
        };
      } else {
        data['type'] = 'message';
      }

      await post<dynamic>(
        '$_internalV2Url/messages/send/$chatroomId',
        data: data,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to send chat message: $e');
      return false;
    }
  }

  /// Delete a chat message (requires authentication + mod permissions).
  ///
  /// Uses the V2 endpoint: DELETE /api/v2/chatrooms/{chatroomId}/messages/{messageId}
  Future<bool> deleteChatMessage({
    required int chatroomId,
    required String messageId,
  }) async {
    try {
      await delete<dynamic>(
        '$_internalV2Url/chatrooms/$chatroomId/messages/$messageId',
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to delete chat message: $e');
      return false;
    }
  }

  // ============================================================
  // PUSHER AUTHENTICATION
  // ============================================================

  /// Authenticate a Pusher private channel subscription.
  ///
  /// Required for subscribing to private channels like:
  /// - `private-chatroom_{chatroomId}`
  /// - `private-channel_{channelId}`
  /// - `private-livestream_{livestreamId}`
  ///
  /// Returns the auth string to send in the Pusher subscribe payload.
  Future<String> authenticatePusherChannel({
    required String socketId,
    required String channelName,
  }) async {
    final data = await post<JsonMap>(
      'https://kick.com/broadcasting/auth',
      data: {'socket_id': socketId, 'channel_name': channelName},
    );
    return data['auth'] as String;
  }

  // ============================================================
  // MODERATION ENDPOINTS
  // ============================================================

  /// Timeout a user in a channel (requires mod/host permissions).
  ///
  /// [durationSeconds] - timeout duration in seconds (e.g., 60, 300, 600, 3600)
  Future<void> timeoutUser({
    required String channelSlug,
    required String username,
    required int durationSeconds,
    String reason = '',
  }) async {
    await post<JsonMap>(
      '$_internalV2Url/channels/${normalizeSlug(channelSlug)}/bans',
      data: {
        'banned_username': username,
        'permanent': false,
        'duration': durationSeconds,
        'reason': reason,
      },
    );
  }

  /// Ban a user permanently from a channel (requires mod/host permissions).
  Future<void> banUser({
    required String channelSlug,
    required String username,
    String reason = '',
  }) async {
    await post<JsonMap>(
      '$_internalV2Url/channels/${normalizeSlug(channelSlug)}/bans',
      data: {'banned_username': username, 'permanent': true, 'reason': reason},
    );
  }

  /// Unban a user from a channel (requires mod/host permissions).
  Future<void> unbanUser({
    required String channelSlug,
    required String username,
  }) async {
    await delete<dynamic>(
      '$_internalV2Url/channels/${normalizeSlug(channelSlug)}/bans/$username',
    );
  }

  // ============================================================
  // PREDICTION & POLL ENDPOINTS (Viewer Participation)
  // ============================================================

  /// Vote on an active prediction (place a bet).
  ///
  /// [amount] - The number of channel points/Kicks to bet
  /// [outcomeId] - The ID of the outcome to bet on
  ///
  /// Returns the updated prediction state and user's vote info.
  Future<KickPredictionVoteResponse> voteOnPrediction({
    required String channelSlug,
    required String outcomeId,
    required int amount,
  }) async {
    final data = await post<JsonMap>(
      '$_internalV2Url/channels/${normalizeSlug(channelSlug)}/predictions/vote',
      data: {'outcome_id': outcomeId, 'amount': amount},
    );
    return KickPredictionVoteResponse.fromJson(data);
  }

  /// Vote on an active poll.
  ///
  /// [optionIndex] - The 0-based index of the poll option (0-5 for up to 6 options)
  Future<void> voteOnPoll({
    required String channelSlug,
    required int optionIndex,
  }) async {
    await post<JsonMap>(
      '$_internalV2Url/channels/${normalizeSlug(channelSlug)}/polls/vote',
      data: {'id': optionIndex},
    );
  }

  // ============================================================
  // EMOTE ENDPOINTS
  // ============================================================

  /// Get all emotes for a channel (Global, Channel, Emoji).
  /// Uses https://kick.com/emotes/{slug}
  Future<List<KickEmoteGroup>> getEmotes({required String channelSlug}) async {
    try {
      // Direct call to main domain endpoint - returns a List of Groups
      final data = await get<List<dynamic>>(
        'https://kick.com/emotes/${normalizeSlug(channelSlug)}',
      );

      return data.map((json) => KickEmoteGroup.fromJson(json)).toList();
    } on ApiException catch (e) {
      debugPrint('Failed to get emotes for $channelSlug: $e');
      return [];
    }
  }

  /// Get global Kick emotes. (Deprecated: Use getEmotes)
  @Deprecated('Use getEmotes')
  Future<List<KickEmoteData>> getGlobalEmotes() async {
    // We can use a random channel or hardcoded one to get globals,
    // or arguably just fetch from any valid user endpoint.
    // Usually 'kick' or generic user works. Let's try 'kick'.
    // Or we handle this in the store.
    // For backward compatibility, let's just return empty or try to fetch.
    // The user's request showed `https://kick.com/emotes/{username}` gives global too.
    return [];
  }

  /// Get channel-specific emotes. (Deprecated: Use getEmotes)
  @Deprecated('Use getEmotes')
  Future<List<KickEmoteData>> getChannelEmotes({
    required String channelSlug,
  }) async {
    try {
      final groups = await getEmotes(channelSlug: channelSlug);
      // Filter for the group that matches the channel slug
      final channelGroup = groups.firstWhere(
        (g) => g.slug == channelSlug,
        orElse: () => const KickEmoteGroup(id: 0, emotes: []),
      );
      return channelGroup.emotes;
    } catch (e) {
      return [];
    }
  }

  // ...

  // ============================================================
  // OAUTH ENDPOINTS (Official API)
  // ============================================================

  /// Exchange authorization code for tokens.
  Future<KickTokenResponse> exchangeAuthCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    required String clientId,
  }) async {
    final data = await post<JsonMap>(
      '$_oauthBaseUrl/token',
      data: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'code_verifier': codeVerifier,
        'redirect_uri': redirectUri,
      },
    );

    return KickTokenResponse.fromJson(data);
  }

  /// Refresh access token using refresh token.
  Future<KickTokenResponse> refreshToken({
    required String refreshToken,
    required String clientId,
  }) async {
    final data = await post<JsonMap>(
      '$_oauthBaseUrl/token',
      data: {
        'grant_type': 'refresh_token',
        'client_id': clientId,
        'refresh_token': refreshToken,
      },
    );

    return KickTokenResponse.fromJson(data);
  }

  /// Revoke a token (logout).
  Future<bool> revokeToken({required String token}) async {
    try {
      await post<dynamic>('$_oauthBaseUrl/revoke', data: {'token': token});
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to revoke token: $e');
      return false;
    }
  }

  /// Validate current access token.
  Future<bool> validateToken({required String token}) async {
    try {
      await get<JsonMap>(
        '$_oauthBaseUrl/validate',
        headers: {'Authorization': 'Bearer $token'},
      );
      return true;
    } on UnauthorizedException {
      return false;
    } on ApiException catch (e) {
      debugPrint('Token validation indeterminate: $e');
      rethrow;
    }
  }

  // ============================================================
  // FOLLOW ENDPOINTS
  // ============================================================

  /// Follow a channel (requires authentication).
  /// Uses V2 API: POST /api/v2/channels/{slug}/follow
  Future<bool> followChannel({required String channelSlug}) async {
    try {
      await post<dynamic>(
        '$_internalV2Url/channels/${normalizeSlug(channelSlug)}/follow',
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to follow channel: $e');
      return false;
    }
  }

  /// Unfollow a channel (requires authentication).
  /// Uses V2 API: DELETE /api/v2/channels/{slug}/follow
  Future<bool> unfollowChannel({required String channelSlug}) async {
    try {
      await delete<dynamic>(
        '$_internalV2Url/channels/${normalizeSlug(channelSlug)}/follow',
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to unfollow channel: $e');
      return false;
    }
  }

  /// Get current user's relationship to a channel.
  /// Returns subscription status, following status, etc.
  /// Requires authentication.
  Future<KickChannelMeResponse?> getChannelMe({
    required String channelSlug,
  }) async {
    try {
      final data = await get<JsonMap>(
        '$_internalV2Url/channels/${normalizeSlug(channelSlug)}/me',
      );
      return KickChannelMeResponse.fromJson(data);
    } on ApiException catch (e) {
      debugPrint('Failed to get channel /me: $e');
      return null;
    }
  }

  /// Check if user is following a channel.
  /// Convenience wrapper around [getChannelMe].
  Future<bool> isFollowing({required String channelSlug}) async {
    final me = await getChannelMe(channelSlug: channelSlug);
    return me?.isFollowing ?? false;
  }

  // ============================================================
  // BLOCK/SILENCE ENDPOINTS
  // ============================================================

  /// Get list of silenced (blocked) users.
  Future<List<KickSilencedUser>> getSilencedUsers() async {
    try {
      final data = await get<JsonMap>('$_internalV2Url/silenced-users');
      final response = KickSilencedUsersResponse.fromJson(data);
      return response.data;
    } on ApiException catch (e) {
      debugPrint('Failed to get silenced users: $e');
      return [];
    }
  }

  /// Block (silence) a user by username.
  Future<bool> blockUser({required String username}) async {
    try {
      // First fetching user to get ID might be safer, but the prompt says
      // post to same endpoint with {"data": {"id": ..., "username": ...}}.
      // We need the ID. So let's fetch user first.

      final user = await getUser(username: username);

      final body = {
        'data': {'id': user.id, 'username': username},
      };

      await post<dynamic>('$_internalV2Url/silenced-users', data: body);
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to mute user $username: $e');
      return false;
    }
  }

  /// Unblock (unsilence) a user by ID.
  Future<bool> unblockUser({required int userId}) async {
    try {
      await delete<dynamic>('$_internalV2Url/silenced-users/$userId');
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to unmute user $userId: $e');
      return false;
    }
  }

  // ============================================================
  // HISTORY ENDPOINTS
  // ============================================================

  /// Get chat history for a channel.
  /// Note: Uses channel ID (not chatroom ID) for the history endpoint.
  Future<List<dynamic>> getChatHistory({required int channelId}) async {
    try {
      final data = await get<JsonMap>(
        '$_internalV1Url/chat/$channelId/history',
      );

      // Expected structure: { data: { messages: [...] }, ... }
      final messages = data['data']['messages'] as List<dynamic>? ?? [];
      return messages;
    } on ApiException catch (e) {
      debugPrint('Failed to get chat history: $e');
      return [];
    }
  }
}

// ============================================================
// HELPER MODELS
// ============================================================

/// Kick OAuth token response.
class KickTokenResponse {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int expiresIn;
  final String? scope;

  const KickTokenResponse({
    required this.accessToken,
    this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    this.scope,
  });

  factory KickTokenResponse.fromJson(Map<String, dynamic> json) {
    return KickTokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 3600,
      scope: json['scope'] as String?,
    );
  }
}

/// Kick emote data from API.
class KickEmoteData {
  final dynamic id; // Can be int or string
  final int? channelId;
  final String name;
  final bool subscribersOnly;
  final String? type; // 'global', 'channel', 'emoji' if provided

  const KickEmoteData({
    required this.id,
    this.channelId,
    required this.name,
    this.subscribersOnly = false,
    this.type,
  });

  factory KickEmoteData.fromJson(Map<String, dynamic> json) {
    return KickEmoteData(
      id: json['id'], // dynamic
      channelId: json['channel_id'] as int?,
      name: json['name'] as String? ?? 'emote',
      subscribersOnly: json['subscribers_only'] as bool? ?? false,
      type: json['type'] as String?,
    );
  }

  /// Get emote URL.
  String get url => 'https://files.kick.com/emotes/$id/fullsize';
}

/// Represents a group of emotes (e.g. Channel specific, Global, Emojis)
class KickEmoteGroup {
  final dynamic id; // Int ID for channels, String "Global"/"Emoji" for others
  final String? slug;
  final String? name; // "Global", "Emojis"
  final KickEmoteGroupUser? user; // User info for subscribed channels
  final List<KickEmoteData> emotes;

  const KickEmoteGroup({
    required this.id,
    this.slug,
    this.name,
    this.user,
    required this.emotes,
  });

  /// Get display name for this emote group.
  /// For subscribed channels, returns username. For global/emoji, returns name.
  String? get displayName => user?.username ?? name;

  factory KickEmoteGroup.fromJson(Map<String, dynamic> json) {
    return KickEmoteGroup(
      id: json['id'],
      slug: json['slug'] as String?,
      name: json['name'] as String?,
      user: json['user'] != null
          ? KickEmoteGroupUser.fromJson(json['user'])
          : null,
      emotes:
          (json['emotes'] as List<dynamic>?)
              ?.map((e) => KickEmoteData.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// User info within an emote group (for subscribed channels).
class KickEmoteGroupUser {
  final int id;
  final String username;

  const KickEmoteGroupUser({required this.id, required this.username});

  factory KickEmoteGroupUser.fromJson(Map<String, dynamic> json) {
    return KickEmoteGroupUser(
      id: json['id'] as int,
      username: json['username'] as String,
    );
  }
}

/// Kick silenced user pagination response.
class KickSilencedUsersResponse {
  final List<KickSilencedUser> data;
  final String? nextCursor; // Using path or explicit cursor if available

  const KickSilencedUsersResponse({required this.data, this.nextCursor});

  factory KickSilencedUsersResponse.fromJson(Map<String, dynamic> json) {
    final data =
        (json['data'] as List<dynamic>?)
            ?.map((e) => KickSilencedUser.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    // Pagination structure in provided sample: links: { next: url }, meta: { ... }
    // We might extract page/cursor logic if needed, but simple list for now.
    return KickSilencedUsersResponse(data: data);
  }
}

/// User's relationship to a channel (from /channels/{slug}/me).
class KickChannelMeResponse {
  final bool isFollowing;
  final bool isModerator;
  final bool isSuperAdmin;
  final KickSubscriptionInfo? subscription;
  final List<int> bannedUsers;
  final List<int> mutedUsers;

  const KickChannelMeResponse({
    required this.isFollowing,
    required this.isModerator,
    required this.isSuperAdmin,
    this.subscription,
    this.bannedUsers = const [],
    this.mutedUsers = const [],
  });

  /// Whether the user is subscribed to this channel.
  bool get isSubscribed => subscription != null;

  factory KickChannelMeResponse.fromJson(Map<String, dynamic> json) {
    return KickChannelMeResponse(
      isFollowing: json['is_following'] as bool? ?? false,
      isModerator: json['is_moderator'] as bool? ?? false,
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
      subscription: json['subscription'] != null
          ? KickSubscriptionInfo.fromJson(
              json['subscription'] as Map<String, dynamic>,
            )
          : null,
      bannedUsers:
          (json['banned_users'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      mutedUsers:
          (json['muted_users'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

/// Subscription info from /channels/{slug}/me.
class KickSubscriptionInfo {
  final int id;
  final int channelId;
  final int subscriberId;
  final String? type;
  final int? months;
  final DateTime? createdAt;

  const KickSubscriptionInfo({
    required this.id,
    required this.channelId,
    required this.subscriberId,
    this.type,
    this.months,
    this.createdAt,
  });

  factory KickSubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return KickSubscriptionInfo(
      id: json['id'] as int? ?? 0,
      channelId: json['channel_id'] as int? ?? 0,
      subscriberId: json['subscriber_id'] as int? ?? 0,
      type: json['type'] as String?,
      months: json['months'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// Data required for sending a reply message.
///
/// The Kick API requires both the original message content and sender info
/// when sending a reply (type: "reply").
class KickReplyData {
  final String messageId;
  final String messageContent;
  final int senderId;
  final String senderUsername;

  const KickReplyData({
    required this.messageId,
    required this.messageContent,
    required this.senderId,
    required this.senderUsername,
  });
}

/// Response from voting on a prediction.
class KickPredictionVoteResponse {
  final KickPredictionData prediction;
  final KickUserVote userVote;
  final String? message;

  const KickPredictionVoteResponse({
    required this.prediction,
    required this.userVote,
    this.message,
  });

  factory KickPredictionVoteResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return KickPredictionVoteResponse(
      prediction: KickPredictionData.fromJson(
        data['prediction'] as Map<String, dynamic>? ?? {},
      ),
      userVote: KickUserVote.fromJson(
        data['user_vote'] as Map<String, dynamic>? ?? {},
      ),
      message: json['message'] as String?,
    );
  }
}

/// Prediction data from vote response.
class KickPredictionData {
  final String id;
  final int channelId;
  final String title;
  final String state;
  final List<KickPredictionOutcomeData> outcomes;
  final int duration;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const KickPredictionData({
    required this.id,
    required this.channelId,
    required this.title,
    required this.state,
    required this.outcomes,
    required this.duration,
    this.createdAt,
    this.updatedAt,
  });

  factory KickPredictionData.fromJson(Map<String, dynamic> json) {
    final outcomesList = json['outcomes'] as List<dynamic>? ?? [];
    return KickPredictionData(
      id: json['id'] as String? ?? '',
      channelId: json['channel_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      state: json['state'] as String? ?? '',
      outcomes: outcomesList
          .map(
            (o) =>
                KickPredictionOutcomeData.fromJson(o as Map<String, dynamic>),
          )
          .toList(),
      duration: json['duration'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

/// Prediction outcome data from vote response.
class KickPredictionOutcomeData {
  final String id;
  final String title;
  final int totalVoteAmount;
  final int voteCount;
  final double returnRate;

  const KickPredictionOutcomeData({
    required this.id,
    required this.title,
    required this.totalVoteAmount,
    required this.voteCount,
    required this.returnRate,
  });

  factory KickPredictionOutcomeData.fromJson(Map<String, dynamic> json) {
    return KickPredictionOutcomeData(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      totalVoteAmount: json['total_vote_amount'] as int? ?? 0,
      voteCount: json['vote_count'] as int? ?? 0,
      returnRate: (json['return_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// User's vote on a prediction.
class KickUserVote {
  final String outcomeId;
  final int totalVoteAmount;

  const KickUserVote({required this.outcomeId, required this.totalVoteAmount});

  factory KickUserVote.fromJson(Map<String, dynamic> json) {
    return KickUserVote(
      outcomeId: json['outcome_id'] as String? ?? '',
      totalVoteAmount: json['total_vote_amount'] as int? ?? 0,
    );
  }
}
