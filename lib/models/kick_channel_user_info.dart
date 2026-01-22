import 'package:json_annotation/json_annotation.dart';

part 'kick_channel_user_info.g.dart';

/// User info in the context of a specific channel.
/// From endpoint: /api/v2/channels/{channel}/users/{user}
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickChannelUserInfo {
  final int id;
  final String username;
  final String slug;
  @JsonKey(name: 'profile_pic')
  final String? profilePic;
  @JsonKey(name: 'is_moderator')
  final bool isModerator;
  final List<KickUserBadge> badges;
  @JsonKey(name: 'following_since')
  final String? followingSince;
  @JsonKey(name: 'subscribed_for')
  final int? subscribedFor;

  const KickChannelUserInfo({
    required this.id,
    required this.username,
    required this.slug,
    this.profilePic,
    this.isModerator = false,
    this.badges = const [],
    this.followingSince,
    this.subscribedFor,
  });

  factory KickChannelUserInfo.fromJson(Map<String, dynamic> json) =>
      _$KickChannelUserInfoFromJson(json);
}

/// Badge info from channel user endpoint.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickUserBadge {
  final String type;
  final String? text;
  final int? count;
  final bool active;

  const KickUserBadge({
    required this.type,
    this.text,
    this.count,
    this.active = true,
  });

  factory KickUserBadge.fromJson(Map<String, dynamic> json) =>
      _$KickUserBadgeFromJson(json);
}
