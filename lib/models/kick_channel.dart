import 'package:json_annotation/json_annotation.dart';
import 'package:krosty/models/kick_user.dart';

part 'kick_channel.g.dart';

/// Helper to parse 'verified' field which can be bool or Map.
KickVerifiedInfo? _verifiedFromJson(dynamic json) {
  if (json == null || json == false) return null;
  if (json is Map<String, dynamic>) {
    return KickVerifiedInfo.fromJson(json);
  }
  return null;
}

/// Kick channel model from /api/v2/channels/{slug} endpoint.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickChannel {
  final int id;
  final String slug;
  final KickUser user;
  final KickChatroom chatroom;
  final KickLivestream? livestream;
  @JsonKey(name: 'verified', fromJson: _verifiedFromJson)
  final KickVerifiedInfo? verifiedInfo;
  @JsonKey(name: 'banner_image')
  final KickBannerImage? bannerImage;
  @JsonKey(name: 'recent_categories')
  final List<KickCategory>? recentCategories;
  @JsonKey(name: 'can_host')
  final bool? canHost;
  @JsonKey(name: 'subscriber_badges')
  final List<KickSubscriberBadge>? subscriberBadges;
  @JsonKey(name: 'followers_count')
  final int? followersCount;
  @JsonKey(name: 'following')
  final bool? following;
  @JsonKey(name: 'subscription_enabled')
  final bool? subscriptionEnabled;
  @JsonKey(name: 'vod_enabled')
  final bool? vodEnabled;
  @JsonKey(name: 'is_affiliate')
  final bool? isAffiliate;
  @JsonKey(name: 'playback_url')
  final String? playbackUrl;

  const KickChannel({
    required this.id,
    required this.slug,
    required this.user,
    required this.chatroom,
    this.livestream,
    this.verifiedInfo,
    this.bannerImage,
    this.recentCategories,
    this.canHost,
    this.subscriberBadges,
    this.followersCount,
    this.following,
    this.subscriptionEnabled,
    this.vodEnabled,
    this.isAffiliate,
    this.playbackUrl,
  });

  factory KickChannel.fromJson(Map<String, dynamic> json) =>
      _$KickChannelFromJson(json);

  /// Get the chatroom ID for WebSocket subscription.
  int get chatroomId => chatroom.id;

  /// Check if channel is currently live.
  bool get isLive => livestream != null;

  /// Check if channel is verified.
  bool get isVerified => verifiedInfo != null;

  /// Get display name from user.
  String get displayName => user.displayName;

  /// Get profile picture URL.
  String? get profilePicUrl => user.profilePic;
}

/// Kick chatroom model - contains settings and ID for WebSocket.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickChatroom {
  final int id;
  @JsonKey(name: 'chatable_type')
  final String? chatableType;
  @JsonKey(name: 'channel_id')
  final int? channelId;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;
  @JsonKey(name: 'chat_mode_old')
  final String? chatModeOld;
  @JsonKey(name: 'chat_mode')
  final String? chatMode;
  @JsonKey(name: 'slow_mode')
  final bool slowMode;
  @JsonKey(name: 'chatable_id')
  final int? chatableId;
  @JsonKey(name: 'followers_mode')
  final bool followersMode;
  @JsonKey(name: 'subscribers_mode')
  final bool subscribersMode;
  @JsonKey(name: 'emotes_mode')
  final bool emotesMode;
  @JsonKey(name: 'message_interval')
  final int? messageInterval;
  @JsonKey(name: 'following_min_duration')
  final int? followingMinDuration;

  const KickChatroom({
    required this.id,
    this.chatableType,
    this.channelId,
    this.createdAt,
    this.updatedAt,
    this.chatModeOld,
    this.chatMode,
    this.slowMode = false,
    this.chatableId,
    this.followersMode = false,
    this.subscribersMode = false,
    this.emotesMode = false,
    this.messageInterval,
    this.followingMinDuration,
  });

  factory KickChatroom.fromJson(Map<String, dynamic> json) =>
      _$KickChatroomFromJson(json);
}

/// Kick livestream model.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickLivestream {
  final dynamic id;
  final String? slug;
  @JsonKey(name: 'channel_id')
  final int? channelId;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'session_title')
  final String? sessionTitle;
  @JsonKey(name: 'is_live')
  final bool? isLive;
  @JsonKey(name: 'risk_level_id')
  final int? riskLevelId;
  @JsonKey(name: 'start_time')
  final String? startTime;
  final String? source;
  @JsonKey(name: 'twitch_channel')
  final String? twitchChannel;
  final int? duration;
  final String? language;
  @JsonKey(name: 'is_mature')
  final bool? isMature;
  @JsonKey(name: 'viewer_count')
  final int? viewerCount;
  final KickThumbnail? thumbnail;
  final List<KickCategory>? categories;
  final List<String>? tags;

  const KickLivestream({
    required this.id,
    required this.slug,
    this.channelId,
    this.createdAt,
    this.sessionTitle,
    this.isLive,
    this.riskLevelId,
    this.startTime,
    this.source,
    this.twitchChannel,
    this.duration,
    this.language,
    this.isMature,
    this.viewerCount,
    this.thumbnail,
    this.categories,
    this.tags,
  });

  factory KickLivestream.fromJson(Map<String, dynamic> json) =>
      _$KickLivestreamFromJson(json);

  /// Get stream title.
  String get title => sessionTitle ?? '';

  /// Get category name (first category).
  String get categoryName =>
      categories?.isNotEmpty == true ? categories!.first.name : '';

  /// Get category ID.
  int? get categoryId =>
      categories?.isNotEmpty == true ? categories!.first.id : null;

  /// Get thumbnail URL.
  String? get thumbnailUrl => thumbnail?.imageUrl;
}

/// Kick thumbnail model.
/// API returns 'src' for featured endpoint and 'url' for channel endpoint.
@JsonSerializable(createToJson: false)
class KickThumbnail {
  final String? url;
  final String? src;

  const KickThumbnail({this.url, this.src});

  factory KickThumbnail.fromJson(Map<String, dynamic> json) =>
      _$KickThumbnailFromJson(json);

  /// Get the best available thumbnail URL.
  String? get imageUrl => src ?? url;
}

/// Kick category model.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickCategory {
  final int id;
  @JsonKey(name: 'category_id')
  final int? categoryId;
  final String name;
  final String slug;
  final List<String>? tags;
  final String? description;
  @JsonKey(name: 'deleted_at')
  final String? deletedAt;
  final int? viewers;
  final KickCategoryBanner? banner;

  const KickCategory({
    required this.id,
    this.categoryId,
    required this.name,
    required this.slug,
    this.tags,
    this.description,
    this.deletedAt,
    this.viewers,
    this.banner,
  });

  factory KickCategory.fromJson(Map<String, dynamic> json) =>
      _$KickCategoryFromJson(json);
}

/// Kick category banner/icon model.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickCategoryBanner {
  final String? responsive;
  final String? url;

  const KickCategoryBanner({this.responsive, this.url});

  factory KickCategoryBanner.fromJson(Map<String, dynamic> json) =>
      _$KickCategoryBannerFromJson(json);
}

/// Kick verified info model.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickVerifiedInfo {
  final int id;
  @JsonKey(name: 'channel_id')
  final int channelId;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const KickVerifiedInfo({
    required this.id,
    required this.channelId,
    this.createdAt,
    this.updatedAt,
  });

  factory KickVerifiedInfo.fromJson(Map<String, dynamic> json) =>
      _$KickVerifiedInfoFromJson(json);
}

/// Kick banner image model.
@JsonSerializable(createToJson: false)
class KickBannerImage {
  final String? url;

  const KickBannerImage({this.url});

  factory KickBannerImage.fromJson(Map<String, dynamic> json) =>
      _$KickBannerImageFromJson(json);
}

/// Kick subscriber badge model.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickSubscriberBadge {
  final int id;
  @JsonKey(name: 'channel_id')
  final int channelId;
  final int months;
  @JsonKey(name: 'badge_image')
  final KickBadgeImage? badgeImage;

  const KickSubscriberBadge({
    required this.id,
    required this.channelId,
    required this.months,
    this.badgeImage,
  });

  factory KickSubscriberBadge.fromJson(Map<String, dynamic> json) =>
      _$KickSubscriberBadgeFromJson(json);
}

/// Kick badge image model.
@JsonSerializable(createToJson: false)
class KickBadgeImage {
  final String? src;

  const KickBadgeImage({this.src});

  factory KickBadgeImage.fromJson(Map<String, dynamic> json) =>
      _$KickBadgeImageFromJson(json);
}

/// Kick channel search result model.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickChannelSearch {
  final int id;
  final String slug;
  final String username;
  @JsonKey(name: 'profile_pic')
  final String? profilePic;
  @JsonKey(name: 'is_live')
  final bool isLive;
  @JsonKey(name: 'is_verified')
  final bool isVerified;
  @JsonKey(name: 'viewer_count')
  final int? viewerCount;
  @JsonKey(name: 'start_time')
  final String? startTime;

  const KickChannelSearch({
    required this.id,
    required this.slug,
    required this.username,
    this.profilePic,
    this.isLive = false,
    this.isVerified = false,
    this.viewerCount,
    this.startTime,
  });

  factory KickChannelSearch.fromJson(Map<String, dynamic> json) =>
      _$KickChannelSearchFromJson(json);

  String get displayName => username;
}

/// Wrapper for paginated livestream responses.
@JsonSerializable(createToJson: false)
class KickLivestreamsResponse {
  @JsonKey(name: 'data', defaultValue: <KickLivestreamItem>[])
  final List<KickLivestreamItem> data;
  @JsonKey(name: 'current_page')
  final int? currentPage;
  @JsonKey(name: 'last_page')
  final int? lastPage;
  @JsonKey(name: 'per_page')
  final int? perPage;
  final int? total;

  const KickLivestreamsResponse({
    this.data = const <KickLivestreamItem>[],
    this.currentPage,
    this.lastPage,
    this.perPage,
    this.total,
  });

  factory KickLivestreamsResponse.fromJson(Map<String, dynamic> json) =>
      _$KickLivestreamsResponseFromJson(json);

  bool get hasMore =>
      currentPage != null && lastPage != null && currentPage! < lastPage!;
}

/// Kick livestream item from list endpoints (includes channel info).
/// Featured endpoint uses: title, category (singular), thumbnail.src
/// Other endpoints may use: session_title, categories (array), thumbnail.url
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickLivestreamItem {
  final dynamic id;
  final String? slug;
  @JsonKey(name: 'channel_id')
  final int? channelId;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'start_time')
  final String? startTime;
  // Featured endpoint uses 'title', other endpoints use 'session_title'
  final String? title;
  @JsonKey(name: 'session_title')
  final String? sessionTitle;
  @JsonKey(name: 'is_live')
  final bool? isLive;
  @JsonKey(name: 'risk_level_id')
  final int? riskLevelId;
  final String? source;
  @JsonKey(name: 'twitch_channel')
  final String? twitchChannel;
  final int? duration;
  final String? language;
  @JsonKey(name: 'is_mature')
  final bool? isMature;
  @JsonKey(name: 'viewer_count')
  final int? viewerCount;
  final KickThumbnail? thumbnail;
  // Featured endpoint uses 'category' (singular), other endpoints use 'categories' (array)
  final KickCategory? category;
  final List<KickCategory>? categories;
  final List<String>? tags;
  final KickChannelInfo? channel;

  const KickLivestreamItem({
    required this.id,
    required this.slug,
    this.channelId,
    this.createdAt,
    this.startTime,
    this.title,
    this.sessionTitle,
    this.isLive = false,
    this.riskLevelId,
    this.source,
    this.twitchChannel,
    this.duration,
    this.language,
    this.isMature = false,
    this.viewerCount,
    this.thumbnail,
    this.category,
    this.categories,
    this.tags,
    this.channel,
  });

  factory KickLivestreamItem.fromJson(Map<String, dynamic> json) =>
      _$KickLivestreamItemFromJson(json);

  /// Get stream title - prefers 'title' (featured), falls back to 'session_title'
  String get streamTitle => title ?? sessionTitle ?? '';

  /// Get category name - prefers 'category' (featured), falls back to 'categories' array
  String get categoryName {
    if (category != null) return category!.name;
    if (categories?.isNotEmpty == true) return categories!.first.name;
    return '';
  }

  /// Get thumbnail URL - uses imageUrl getter which handles both src and url
  String? get thumbnailUrl => thumbnail?.imageUrl;

  String get channelSlug => channel?.slug ?? '';
  String get channelDisplayName => channel?.displayName ?? '';
  String? get channelProfilePic => channel?.profilePicUrl;

  /// Get the best available time for uptime calculation.
  /// Prefers startTime, falls back to createdAt.
  String? get uptimeStartTime => startTime ?? createdAt;
}

/// Minimal channel info included in livestream items.
/// Featured endpoint has profile_pic/username directly on channel,
/// while other endpoints may have them nested in a 'user' object.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickChannelInfo {
  final int? id;
  final String? slug;
  // Direct fields from featured endpoint
  @JsonKey(name: 'profile_pic')
  final String? profilePic;
  final String? username;
  // Nested user object from other endpoints
  final KickUser? user;

  const KickChannelInfo({
    this.id,
    this.slug,
    this.profilePic,
    this.username,
    this.user,
  });

  factory KickChannelInfo.fromJson(Map<String, dynamic> json) =>
      _$KickChannelInfoFromJson(json);

  /// Get the display name - prefer direct username, fallback to user.username
  String? get displayName => username ?? user?.username;

  /// Get the profile picture URL - prefer direct profilePic, fallback to user.profilePic
  String? get profilePicUrl => profilePic ?? user?.profilePic;
}

/// Wrapper for paginated category responses.
@JsonSerializable(createToJson: false)
class KickCategoriesResponse {
  final List<KickCategory> data;
  @JsonKey(name: 'current_page')
  final int? currentPage;
  @JsonKey(name: 'last_page')
  final int? lastPage;
  @JsonKey(name: 'per_page')
  final int? perPage;
  final int? total;

  const KickCategoriesResponse({
    required this.data,
    this.currentPage,
    this.lastPage,
    this.perPage,
    this.total,
  });

  factory KickCategoriesResponse.fromJson(Map<String, dynamic> json) =>
      _$KickCategoriesResponseFromJson(json);

  bool get hasMore =>
      currentPage != null && lastPage != null && currentPage! < lastPage!;
}

/// Response from /api/v2/channels/followed endpoint.
/// This endpoint has a different structure than other livestream endpoints.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickFollowedChannelsResponse {
  @JsonKey(name: 'channels', defaultValue: <KickFollowedChannel>[])
  final List<KickFollowedChannel> channels;
  @JsonKey(name: 'nextCursor')
  final int? nextCursor;

  const KickFollowedChannelsResponse({
    this.channels = const <KickFollowedChannel>[],
    this.nextCursor,
  });

  factory KickFollowedChannelsResponse.fromJson(Map<String, dynamic> json) =>
      _$KickFollowedChannelsResponseFromJson(json);

  /// Convert to standard KickLivestreamsResponse for compatibility.
  KickLivestreamsResponse toLivestreamsResponse() {
    final items = channels
        .map((channel) => channel.toLivestreamItem())
        .toList();
    return KickLivestreamsResponse(data: items);
  }

  bool get hasMore => nextCursor != null;
}

/// Simplified channel info from /api/v2/channels/followed endpoint.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickFollowedChannel {
  @JsonKey(name: 'is_live')
  final bool isLive;
  @JsonKey(name: 'profile_picture')
  final String? profilePicture;
  @JsonKey(name: 'channel_slug')
  final String channelSlug;
  @JsonKey(name: 'viewer_count')
  final int? viewerCount;
  @JsonKey(name: 'category_name')
  final String? categoryName;
  @JsonKey(name: 'user_username')
  final String userUsername;
  @JsonKey(name: 'session_title')
  final String? sessionTitle;
  @JsonKey(name: 'thumbnail_url')
  final String? thumbnailUrl;

  const KickFollowedChannel({
    required this.isLive,
    this.profilePicture,
    required this.channelSlug,
    this.viewerCount,
    this.categoryName,
    required this.userUsername,
    this.sessionTitle,
    this.thumbnailUrl,
  });

  factory KickFollowedChannel.fromJson(Map<String, dynamic> json) =>
      _$KickFollowedChannelFromJson(json);

  /// Convert to KickLivestreamItem for compatibility with existing UI.
  KickLivestreamItem toLivestreamItem() {
    return KickLivestreamItem(
      id: channelSlug, // Use slug as ID since we don't have numeric ID
      slug: channelSlug,
      sessionTitle: sessionTitle,
      isLive: isLive,
      viewerCount: viewerCount,
      // Add thumbnail if available
      thumbnail: thumbnailUrl != null ? KickThumbnail(url: thumbnailUrl) : null,
      channel: KickChannelInfo(
        slug: channelSlug,
        user: KickUser(
          id: 0, // We don't have user ID from this endpoint
          username: userUsername,
          profilePic: profilePicture,
        ),
      ),
      // Create a minimal category if we have a name
      category: categoryName != null
          ? KickCategory(
              id: 0, // We don't have category ID
              name: categoryName!,
              slug: categoryName!.toLowerCase().replaceAll(' ', '-'),
            )
          : null,
    );
  }
}
