import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:krosty/apis/base_api_client.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/models/kick_channel_user_info.dart';
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
  static const String _officialBaseUrl = 'https://api.kick.com/public/v1';
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
    final queryParams = <String, dynamic>{
      'limit': limit,
      'sort': 'viewer_count_desc',
    };
    if (categoryId != null) queryParams['category_id'] = categoryId;
    if (afterCursor != null) queryParams['after'] = afterCursor;

    final data = await get<JsonMap>(
      '$_internalV1Url/livestreams',
      queryParameters: queryParams,
    );

    return KickLivestreamsResponse.fromLivestreamsJson(data);
  }

  /// Returns a list of featured livestreams.
  @Deprecated('Use getLivestreams() instead for better pagination support')
  Future<KickLivestreamsResponse> getFeaturedLivestreams({
    int? page,
    String lang = 'en', // TODO: switch to locale
  }) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page.toString();

    final data = await get<JsonMap>(
      '$_internalV1Url/livestreams/featured?language=$lang',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    // Featured endpoint has structure: { data: { livestreams: [...] } }
    // Unlike others which are { data: [...] }
    final livestreamsData = data['data'];
    List<KickLivestreamItem> livestreams = [];

    if (livestreamsData is Map && livestreamsData['livestreams'] is List) {
      livestreams = (livestreamsData['livestreams'] as List)
          .map((e) => KickLivestreamItem.fromJson(e))
          .toList();
    } else if (livestreamsData is List) {
      // Fallback in case structure changes
      livestreams = livestreamsData
          .map((e) => KickLivestreamItem.fromJson(e))
          .toList();
    }

    // Featured response doesn't seem to include standard pagination meta
    // So we return a wrapper with just the data
    return KickLivestreamsResponse(data: livestreams);
  }

  /// Returns livestreams for a specific category.
  @Deprecated('Use getLivestreams(categoryId: id) instead')
  Future<KickLivestreamsResponse> getLivestreamsByCategory({
    required String categorySlug,
    int? page,
  }) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page.toString();

    final data = await get<JsonMap>(
      '$_internalV2Url/categories/${normalizeSlug(categorySlug)}/streams',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
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
      final data = await post<JsonMap>(
        'https://search.kick.com/multi_search',
        data: {
          'searches': [
            {'preset': 'channel_search', 'q': query},
          ],
        },
        headers: {'x-typesense-api-key': 'nXIMW0iEN6sMujFYjFuhdrSwVow3pDQu'},
      );

      // Response structure: { results: [ { hits: [ { document: {...} } ] } ] }
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return [];

      final hits = results[0]['hits'] as List<dynamic>?;
      if (hits == null) return [];

      return hits.map((hit) {
        final doc = hit['document'] as Map<String, dynamic>;
        // Map search document to KickChannelSearch
        // Note: Search API might return string IDs, handle parsing
        final id = doc['id'] is int
            ? doc['id'] as int
            : int.tryParse(doc['id'].toString()) ?? 0;

        return KickChannelSearch(
          id: id,
          slug: doc['slug'] as String? ?? '',
          username: doc['username'] as String? ?? '',
          profilePic: doc['profile_pic'] as String?, // Might be null in search
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
      final data = await post<JsonMap>(
        'https://search.kick.com/multi_search',
        data: {
          'searches': [
            {'preset': 'category_search', 'q': query},
          ],
        },
        headers: {'x-typesense-api-key': 'nXIMW0iEN6sMujFYjFuhdrSwVow3pDQu'},
      );

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return [];

      final hits = results[0]['hits'] as List<dynamic>?;
      if (hits == null) return [];

      return hits.map((hit) {
        final doc = hit['document'] as Map<String, dynamic>;
        final id = doc['id'] is int
            ? doc['id'] as int
            : int.tryParse(doc['id'].toString()) ?? 0;

        // Map search document to KickCategory
        // Search doc has 'src' for banner, map to KickCategoryBanner
        return KickCategory(
          id: id,
          categoryId: doc['category_id'] as int?,
          name: doc['name'] as String? ?? '',
          slug: doc['slug'] as String? ?? '',
          banner: doc['src'] != null
              ? KickCategoryBanner(url: doc['src'] as String)
              : null,
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
  Future<bool> sendChatMessage({
    required int chatroomId,
    required String content,
    String? replyToMessageId,
  }) async {
    try {
      final data = <String, dynamic>{'content': content, 'type': 'message'};

      if (replyToMessageId != null) {
        data['metadata'] = {
          'original_message': {'id': replyToMessageId},
        };
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
  Future<bool> deleteChatMessage({required String messageId}) async {
    try {
      await delete<dynamic>('$_internalV1Url/chat/$messageId');
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to delete chat message: $e');
      return false;
    }
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
