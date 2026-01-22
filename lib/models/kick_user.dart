import 'package:json_annotation/json_annotation.dart';

part 'kick_user.g.dart';

/// Helper to read profile pic from either 'profilepic' or 'profile_pic' field.
Object? _readProfilePic(Map<dynamic, dynamic> json, String key) {
  return json['profilepic'] ?? json['profile_pic'];
}

/// Kick user model from API responses.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickUser {
  final int id;
  final String username;
  final String? bio;
  // API returns 'profilepic' (no underscore) from /user/livestreams
  // and 'profile_pic' from other endpoints
  @JsonKey(readValue: _readProfilePic)
  final String? profilePic;
  final String? instagram;
  final String? twitter;
  final String? youtube;
  final String? discord;
  final String? tiktok;
  final String? facebook;

  const KickUser({
    required this.id,
    required this.username,
    this.bio,
    this.profilePic,
    this.instagram,
    this.twitter,
    this.youtube,
    this.discord,
    this.tiktok,
    this.facebook,
  });

  factory KickUser.fromJson(Map<String, dynamic> json) =>
      _$KickUserFromJson(json);

  /// Get display name (username is the display name in Kick)
  String get displayName => username;

  /// Get slug (lowercase username for URL)
  String get slug => username.toLowerCase();
}

/// Kick identity model for chat messages (contains badge info).
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickIdentity {
  final String color;
  final List<KickBadgeInfo> badges;

  const KickIdentity({required this.color, required this.badges});

  factory KickIdentity.fromJson(Map<String, dynamic> json) =>
      _$KickIdentityFromJson(json);
}

/// Kick badge info from identity.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickBadgeInfo {
  final String type;
  final String? text;
  final int? count;

  const KickBadgeInfo({required this.type, this.text, this.count});

  factory KickBadgeInfo.fromJson(Map<String, dynamic> json) =>
      _$KickBadgeInfoFromJson(json);
}

/// Kick sender model for chat messages.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickSender {
  final int id;
  final String username;
  final String slug;
  final KickIdentity identity;

  const KickSender({
    required this.id,
    required this.username,
    required this.slug,
    required this.identity,
  });

  factory KickSender.fromJson(Map<String, dynamic> json) =>
      _$KickSenderFromJson(json);

  String get displayName => username;
  String? get color => identity.color.isNotEmpty ? identity.color : null;
  List<KickBadgeInfo> get badges => identity.badges;
}
