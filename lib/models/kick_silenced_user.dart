import 'package:json_annotation/json_annotation.dart';

part 'kick_silenced_user.g.dart';

@JsonSerializable(createToJson: false)
class KickSilencedUser {
  final int id;
  final String username;

  const KickSilencedUser({
    required this.id,
    required this.username,
  });

  factory KickSilencedUser.fromJson(Map<String, dynamic> json) =>
      _$KickSilencedUserFromJson(json);
}
