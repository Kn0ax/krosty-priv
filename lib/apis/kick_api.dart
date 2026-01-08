import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/models/kick_channel.dart';
import 'package:frosty/models/kick_user.dart';

/// The Kick API service for making API calls.
///
/// Uses a combination of:
/// - Official API (docs.kick.com): OAuth, authenticated endpoints
/// - Internal API (kick.com/api): Channel data, livestreams, categories
class KickApi extends BaseApiClient {
  // Internal API base URLs (reverse-engineered, more complete data)
  static const String _internalBaseUrl = 'https://kick.com/api';
  static const String _internalV1Url = 'https://kick.com/api/v1';
  static const String _internalV2Url = 'https://kick.com/api/v2';

  // Official API base URL (documented, OAuth endpoints)
  static const String _officialBaseUrl = 'https://api.kick.com/public/v1';
  static const String _oauthBaseUrl = 'https://id.kick.com/oauth';

  KickApi(Dio dio) : super(dio, _internalBaseUrl);

  // ============================================================
  // CHANNEL ENDPOINTS (Internal API - more complete data)
  // ============================================================

  /// Returns detailed channel info including chatroom_id.
  /// Uses internal API v2 for complete data.
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

  /// Returns a list of top/featured livestreams.
  Future<KickLivestreamsResponse> getTopLivestreams({int? page}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page.toString();

    final data = await get<JsonMap>(
      '$_internalV1Url/livestreams',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return KickLivestreamsResponse.fromJson(data);
  }

  /// Returns livestreams for a specific category.
  Future<KickLivestreamsResponse> getLivestreamsByCategory({
    required String categorySlug,
    int? page,
  }) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page.toString();

    final data = await get<JsonMap>(
      '$_internalV1Url/categories/$categorySlug/streams',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    return KickLivestreamsResponse.fromJson(data);
  }

  /// Returns followed channels' livestreams (requires auth).
  /// Note: This may need to be implemented via Official API when available.
  Future<KickLivestreamsResponse> getFollowedLivestreams({int? page}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page.toString();

    // This endpoint requires authentication
    final data = await get<JsonMap>(
      '$_internalV1Url/channels/followed',
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
  Future<KickUser> getUser({required String username}) async {
    final data = await get<JsonMap>('$_internalV1Url/users/$username');
    return KickUser.fromJson(data);
  }

  // ============================================================
  // CATEGORY ENDPOINTS (Internal API)
  // ============================================================

  /// Returns top/popular categories.
  Future<KickCategoriesResponse> getTopCategories({int? page}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page.toString();

    final data = await get<JsonMap>(
      '$_internalV1Url/categories/top',
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
    final data = await get<JsonMap>(
      '$_internalV1Url/categories/$categorySlug',
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
    final data = await get<JsonMap>(
      '$_internalBaseUrl/search',
      queryParameters: {'query': query},
    );

    final channels = data['channels'] as JsonList? ?? [];
    return channels.map((c) => KickChannelSearch.fromJson(c)).toList();
  }

  /// Search for categories by query.
  Future<List<KickCategory>> searchCategories({required String query}) async {
    final data = await get<JsonMap>(
      '$_internalBaseUrl/search',
      queryParameters: {'query': query},
    );

    final categories = data['categories'] as JsonList? ?? [];
    return categories.map((c) => KickCategory.fromJson(c)).toList();
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
      final data = <String, dynamic>{
        'content': content,
        'type': 'message',
      };

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

  /// Get global Kick emotes.
  Future<List<KickEmoteData>> getGlobalEmotes() async {
    try {
      final data = await get<JsonList>('$_internalV1Url/emotes/global');
      return data.map((e) => KickEmoteData.fromJson(e)).toList();
    } on ApiException catch (e) {
      debugPrint('Failed to get global emotes: $e');
      return [];
    }
  }

  /// Get channel-specific emotes.
  Future<List<KickEmoteData>> getChannelEmotes({
    required String channelSlug,
  }) async {
    try {
      final data = await get<JsonList>(
        '$_internalV1Url/channels/$channelSlug/emotes',
      );
      return data.map((e) => KickEmoteData.fromJson(e)).toList();
    } on ApiException catch (e) {
      debugPrint('Failed to get channel emotes: $e');
      return [];
    }
  }

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
      await post<dynamic>(
        '$_oauthBaseUrl/revoke',
        data: {'token': token},
      );
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
  Future<bool> followChannel({required int channelId}) async {
    try {
      await post<dynamic>(
        '$_internalV1Url/channels/$channelId/follow',
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to follow channel: $e');
      return false;
    }
  }

  /// Unfollow a channel (requires authentication).
  Future<bool> unfollowChannel({required int channelId}) async {
    try {
      await delete<dynamic>(
        '$_internalV1Url/channels/$channelId/follow',
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('Failed to unfollow channel: $e');
      return false;
    }
  }

  /// Check if user is following a channel.
  Future<bool> isFollowing({required int channelId}) async {
    try {
      await get<dynamic>('$_internalV1Url/channels/$channelId/follow');
      return true;
    } on NotFoundException {
      return false;
    } on ApiException catch (e) {
      debugPrint('Failed to check follow status: $e');
      return false;
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
  final int id;
  final String name;
  final List<String> subscribers;

  const KickEmoteData({
    required this.id,
    required this.name,
    required this.subscribers,
  });

  factory KickEmoteData.fromJson(Map<String, dynamic> json) {
    return KickEmoteData(
      id: json['id'] as int,
      name: json['name'] as String,
      subscribers: (json['subscribers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Get emote URL.
  String get url => 'https://files.kick.com/emotes/$id/fullsize';
}
