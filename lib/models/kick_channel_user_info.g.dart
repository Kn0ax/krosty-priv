// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kick_channel_user_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KickChannelUserInfo _$KickChannelUserInfoFromJson(Map<String, dynamic> json) =>
    KickChannelUserInfo(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      slug: json['slug'] as String,
      profilePic: json['profile_pic'] as String?,
      isModerator: json['is_moderator'] as bool? ?? false,
      badges:
          (json['badges'] as List<dynamic>?)
              ?.map((e) => KickUserBadge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      followingSince: json['following_since'] as String?,
      subscribedFor: (json['subscribed_for'] as num?)?.toInt(),
    );

KickUserBadge _$KickUserBadgeFromJson(Map<String, dynamic> json) =>
    KickUserBadge(
      type: json['type'] as String,
      text: json['text'] as String?,
      count: (json['count'] as num?)?.toInt(),
      active: json['active'] as bool? ?? true,
    );
