// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kick_channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KickChannel _$KickChannelFromJson(Map<String, dynamic> json) => KickChannel(
  id: (json['id'] as num).toInt(),
  slug: json['slug'] as String,
  user: KickUser.fromJson(json['user'] as Map<String, dynamic>),
  chatroom: KickChatroom.fromJson(json['chatroom'] as Map<String, dynamic>),
  livestream: json['livestream'] == null
      ? null
      : KickLivestream.fromJson(json['livestream'] as Map<String, dynamic>),
  verifiedInfo: _verifiedFromJson(json['verified']),
  bannerImage: json['banner_image'] == null
      ? null
      : KickBannerImage.fromJson(json['banner_image'] as Map<String, dynamic>),
  recentCategories: (json['recent_categories'] as List<dynamic>?)
      ?.map((e) => KickCategory.fromJson(e as Map<String, dynamic>))
      .toList(),
  canHost: json['can_host'] as bool?,
  subscriberBadges: (json['subscriber_badges'] as List<dynamic>?)
      ?.map((e) => KickSubscriberBadge.fromJson(e as Map<String, dynamic>))
      .toList(),
  followersCount: (json['followers_count'] as num?)?.toInt(),
  following: json['following'] as bool?,
  subscriptionEnabled: json['subscription_enabled'] as bool?,
  vodEnabled: json['vod_enabled'] as bool?,
  isAffiliate: json['is_affiliate'] as bool?,
  playbackUrl: json['playback_url'] as String?,
);

KickChatroom _$KickChatroomFromJson(Map<String, dynamic> json) => KickChatroom(
  id: (json['id'] as num).toInt(),
  chatableType: json['chatable_type'] as String?,
  channelId: (json['channel_id'] as num?)?.toInt(),
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  chatModeOld: json['chat_mode_old'] as String?,
  chatMode: json['chat_mode'] as String?,
  slowMode: json['slow_mode'] as bool? ?? false,
  chatableId: (json['chatable_id'] as num?)?.toInt(),
  followersMode: json['followers_mode'] as bool? ?? false,
  subscribersMode: json['subscribers_mode'] as bool? ?? false,
  emotesMode: json['emotes_mode'] as bool? ?? false,
  messageInterval: (json['message_interval'] as num?)?.toInt(),
  followingMinDuration: (json['following_min_duration'] as num?)?.toInt(),
);

KickLivestream _$KickLivestreamFromJson(Map<String, dynamic> json) =>
    KickLivestream(
      id: json['id'],
      slug: json['slug'] as String?,
      channelId: (json['channel_id'] as num?)?.toInt(),
      createdAt: json['created_at'] as String?,
      sessionTitle: json['session_title'] as String?,
      isLive: json['is_live'] as bool?,
      riskLevelId: (json['risk_level_id'] as num?)?.toInt(),
      startTime: json['start_time'] as String?,
      source: json['source'] as String?,
      twitchChannel: json['twitch_channel'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      language: json['language'] as String?,
      isMature: json['is_mature'] as bool?,
      viewerCount: (json['viewer_count'] as num?)?.toInt(),
      thumbnail: json['thumbnail'] == null
          ? null
          : KickThumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>),
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => KickCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

KickThumbnail _$KickThumbnailFromJson(Map<String, dynamic> json) =>
    KickThumbnail(url: json['url'] as String?, src: json['src'] as String?);

KickCategory _$KickCategoryFromJson(Map<String, dynamic> json) => KickCategory(
  id: (json['id'] as num).toInt(),
  categoryId: (json['category_id'] as num?)?.toInt(),
  name: json['name'] as String,
  slug: json['slug'] as String,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  description: json['description'] as String?,
  deletedAt: json['deleted_at'] as String?,
  viewers: (json['viewers'] as num?)?.toInt(),
  banner: json['banner'] == null
      ? null
      : KickCategoryBanner.fromJson(json['banner'] as Map<String, dynamic>),
);

KickCategoryBanner _$KickCategoryBannerFromJson(Map<String, dynamic> json) =>
    KickCategoryBanner(
      responsive: json['responsive'] as String?,
      url: json['url'] as String?,
    );

KickVerifiedInfo _$KickVerifiedInfoFromJson(Map<String, dynamic> json) =>
    KickVerifiedInfo(
      id: (json['id'] as num).toInt(),
      channelId: (json['channel_id'] as num).toInt(),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

KickBannerImage _$KickBannerImageFromJson(Map<String, dynamic> json) =>
    KickBannerImage(url: json['url'] as String?);

KickSubscriberBadge _$KickSubscriberBadgeFromJson(Map<String, dynamic> json) =>
    KickSubscriberBadge(
      id: (json['id'] as num).toInt(),
      channelId: (json['channel_id'] as num).toInt(),
      months: (json['months'] as num).toInt(),
      badgeImage: json['badge_image'] == null
          ? null
          : KickBadgeImage.fromJson(
              json['badge_image'] as Map<String, dynamic>,
            ),
    );

KickBadgeImage _$KickBadgeImageFromJson(Map<String, dynamic> json) =>
    KickBadgeImage(src: json['src'] as String?);

KickChannelSearch _$KickChannelSearchFromJson(Map<String, dynamic> json) =>
    KickChannelSearch(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      username: json['username'] as String,
      profilePic: json['profile_pic'] as String?,
      isLive: json['is_live'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      viewerCount: (json['viewer_count'] as num?)?.toInt(),
      startTime: json['start_time'] as String?,
    );

KickLivestreamsResponse _$KickLivestreamsResponseFromJson(
  Map<String, dynamic> json,
) => KickLivestreamsResponse(
  data:
      (json['data'] as List<dynamic>?)
          ?.map((e) => KickLivestreamItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  currentPage: (json['current_page'] as num?)?.toInt(),
  lastPage: (json['last_page'] as num?)?.toInt(),
  perPage: (json['per_page'] as num?)?.toInt(),
  total: (json['total'] as num?)?.toInt(),
);

KickLivestreamItem _$KickLivestreamItemFromJson(Map<String, dynamic> json) =>
    KickLivestreamItem(
      id: json['id'],
      slug: json['slug'] as String?,
      channelId: (json['channel_id'] as num?)?.toInt(),
      createdAt: json['created_at'] as String?,
      startTime: json['start_time'] as String?,
      title: json['title'] as String?,
      sessionTitle: json['session_title'] as String?,
      isLive: json['is_live'] as bool? ?? false,
      riskLevelId: (json['risk_level_id'] as num?)?.toInt(),
      source: json['source'] as String?,
      twitchChannel: json['twitch_channel'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      language: json['language'] as String?,
      isMature: json['is_mature'] as bool? ?? false,
      viewerCount: (json['viewer_count'] as num?)?.toInt(),
      thumbnail: json['thumbnail'] == null
          ? null
          : KickThumbnail.fromJson(json['thumbnail'] as Map<String, dynamic>),
      category: json['category'] == null
          ? null
          : KickCategory.fromJson(json['category'] as Map<String, dynamic>),
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => KickCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      channel: json['channel'] == null
          ? null
          : KickChannelInfo.fromJson(json['channel'] as Map<String, dynamic>),
    );

KickChannelInfo _$KickChannelInfoFromJson(Map<String, dynamic> json) =>
    KickChannelInfo(
      id: (json['id'] as num?)?.toInt(),
      slug: json['slug'] as String?,
      profilePic: json['profile_pic'] as String?,
      username: json['username'] as String?,
      user: json['user'] == null
          ? null
          : KickUser.fromJson(json['user'] as Map<String, dynamic>),
    );

KickCategoriesResponse _$KickCategoriesResponseFromJson(
  Map<String, dynamic> json,
) => KickCategoriesResponse(
  data: (json['data'] as List<dynamic>)
      .map((e) => KickCategory.fromJson(e as Map<String, dynamic>))
      .toList(),
  currentPage: (json['current_page'] as num?)?.toInt(),
  lastPage: (json['last_page'] as num?)?.toInt(),
  perPage: (json['per_page'] as num?)?.toInt(),
  total: (json['total'] as num?)?.toInt(),
);

KickFollowedChannelsResponse _$KickFollowedChannelsResponseFromJson(
  Map<String, dynamic> json,
) => KickFollowedChannelsResponse(
  channels:
      (json['channels'] as List<dynamic>?)
          ?.map((e) => KickFollowedChannel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  nextCursor: (json['nextCursor'] as num?)?.toInt(),
);

KickFollowedChannel _$KickFollowedChannelFromJson(Map<String, dynamic> json) =>
    KickFollowedChannel(
      isLive: json['is_live'] as bool,
      profilePicture: json['profile_picture'] as String?,
      channelSlug: json['channel_slug'] as String,
      viewerCount: (json['viewer_count'] as num?)?.toInt(),
      categoryName: json['category_name'] as String?,
      userUsername: json['user_username'] as String,
      sessionTitle: json['session_title'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
