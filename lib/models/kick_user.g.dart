// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kick_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KickUser _$KickUserFromJson(Map<String, dynamic> json) => KickUser(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  bio: json['bio'] as String?,
  profilePic: json['profile_pic'] as String?,
  instagram: json['instagram'] as String?,
  twitter: json['twitter'] as String?,
  youtube: json['youtube'] as String?,
  discord: json['discord'] as String?,
  tiktok: json['tiktok'] as String?,
  facebook: json['facebook'] as String?,
);

KickIdentity _$KickIdentityFromJson(Map<String, dynamic> json) => KickIdentity(
  color: json['color'] as String,
  badges: (json['badges'] as List<dynamic>)
      .map((e) => KickBadgeInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
);

KickBadgeInfo _$KickBadgeInfoFromJson(Map<String, dynamic> json) =>
    KickBadgeInfo(
      type: json['type'] as String,
      text: json['text'] as String?,
      count: (json['count'] as num?)?.toInt(),
    );

KickSender _$KickSenderFromJson(Map<String, dynamic> json) => KickSender(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  slug: json['slug'] as String,
  identity: KickIdentity.fromJson(json['identity'] as Map<String, dynamic>),
);
