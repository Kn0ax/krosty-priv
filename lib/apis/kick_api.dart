import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:krosty/apis/base_api_client.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/models/kick_user.dart';
import 'package:krosty/models/kick_silenced_user.dart';

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

  KickApi(Dio dio) : super(dio, _internalV1Url);

  // ============================================================
  // CHANNEL ENDPOINTS (Internal API - more complete data)
  // ============================================================

  /// Returns detailed channel info including chatroom_id.
  /// Uses internal API v2 for channel data.
  Future<KickChannel> getChannel({required String channelSlug}) async {
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

  /// Returns a list of featured livestreams.
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
  Future<KickLivestreamsResponse> getLivestreamsByCategory({
    required String categorySlug,
    int? page,
  }) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page.toString();

    final data = await get<JsonMap>(
      '$_internalV2Url/categories/$categorySlug/streams',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return KickLivestreamsResponse.fromJson(data);
  }

  /// Returns followed channels' livestreams (requires auth).
  /// Uses api/v2/channels/followed with cursor-based pagination.
  Future<KickLivestreamsResponse> getFollowedLivestreams({int? cursor}) async {
    final queryParams = <String, dynamic>{};
    if (cursor != null) queryParams['cursor'] = cursor.toString();

    // This endpoint requires authentication
    final data = await get<JsonMap>(
      '$_internalV2Url/channels/followed',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return KickLivestreamsResponse.fromJson(data);
  }

  // ============================================================
  // USER ENDPOINTS
  // ============================================================

  /// Returns current authenticated user info.
  Future<KickUser> getCurrentUser() async {
    final data = await get<JsonMap>('$_internalV1Url/user');
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

  // ============================================================
  // CATEGORY ENDPOINTS (Internal API)
  // ============================================================

  /// Returns top/popular categories.
  Future<KickCategoriesResponse> getTopCategories({int? page}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page.toString();

    final data = await get<JsonMap>(
      '$_internalV2Url/subcategories',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
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
    final data = await get<JsonMap>('$_internalV1Url/categories/$categorySlug');
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
          viewerCount: null, // Not provided in search hits usually
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
  Future<List<KickEmoteData>> getEmotes({required String channelSlug}) async {
    try {
      // Direct call to main domain endpoint
      final data = await get<JsonList>('https://kick.com/emotes/$channelSlug');
      return data.map((e) => KickEmoteData.fromJson(e)).toList();
    } on ApiException catch (e) {
      debugPrint('Failed to get emotes for $channelSlug: $e');
      return [];
    }
  }

  /// Get global Kick emotes. (Deprecated: Use getEmotes)
  @Deprecated('Use getEmotes')
  Future<List<KickEmoteData>> getGlobalEmotes() async {
    return [];
  }

  /// Get channel-specific emotes. (Deprecated: Use getEmotes)
  @Deprecated('Use getEmotes')
  Future<List<KickEmoteData>> getChannelEmotes({
    required String channelSlug,
  }) async {
    return getEmotes(channelSlug: channelSlug);
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
      await post<dynamic>('$_internalV2Url/channels/$channelSlug/follow');
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
      await delete<dynamic>('$_internalV2Url/channels/$channelSlug/follow');
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to unfollow channel: $e');
      return false;
    }
  }

  /// Check if user is following a channel.
  /// Uses V2 API: GET /api/v2/channels/{slug}/follow
  Future<bool> isFollowing({required String channelSlug}) async {
    try {
      await get<dynamic>('$_internalV2Url/channels/$channelSlug/follow');
      return true;
    } on NotFoundException {
      return false;
    } on ApiException catch (e) {
      debugPrint('Failed to check follow status: $e');
      return false;
    }
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

  /// Get chat history for a chatroom.
  Future<List<dynamic>> getChatHistory({required int chatroomId}) async {
    try {
      final data = await get<JsonMap>(
        '$_internalV1Url/chat/$chatroomId/history',
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
  final String name;
  final bool subscribersOnly;
  final String? type; // 'global', 'channel', 'emoji' if provided

  const KickEmoteData({
    required this.id,
    required this.name,
    this.subscribersOnly = false,
    this.type,
  });

  factory KickEmoteData.fromJson(Map<String, dynamic> json) {
    return KickEmoteData(
      id: json['id'], // dynamic
      name: json['name'] as String? ?? 'emote',
      subscribersOnly: json['subscribers_only'] as bool? ?? false,
      type: json['type'] as String?,
    );
  }

  /// Get emote URL.
  String get url => 'https://files.kick.com/emotes/$id/fullsize';
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
