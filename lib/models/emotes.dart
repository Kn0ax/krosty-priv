import 'package:collection/collection.dart';
import 'package:krosty/apis/kick_api.dart';

import 'package:json_annotation/json_annotation.dart';

part 'emotes.g.dart';

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class Emote7TV {
  final String id;
  final String name;
  final Emote7TVData data;

  const Emote7TV(this.id, this.name, this.data);

  factory Emote7TV.fromJson(Map<String, dynamic> json) =>
      _$Emote7TVFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class Owner7TV {
  final String username;
  final String displayName;

  const Owner7TV({required this.username, required this.displayName});

  factory Owner7TV.fromJson(Map<String, dynamic> json) =>
      _$Owner7TVFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class Emote7TVData {
  final String id;
  final String name;
  final int flags;
  final Owner7TV? owner;
  final Emote7TVHost host;

  const Emote7TVData(this.id, this.name, this.flags, this.owner, this.host);

  factory Emote7TVData.fromJson(Map<String, dynamic> json) =>
      _$Emote7TVDataFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class Emote7TVHost {
  final String url;
  final List<Emote7TVFile> files;

  Emote7TVHost(this.url, this.files);

  factory Emote7TVHost.fromJson(Map<String, dynamic> json) =>
      _$Emote7TVHostFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class Emote7TVFile {
  final String name;
  final int width;
  final int height;
  final String format;

  Emote7TVFile(this.name, this.width, this.height, this.format);

  factory Emote7TVFile.fromJson(Map<String, dynamic> json) =>
      _$Emote7TVFileFromJson(json);
}

/// The common emote class.
@JsonSerializable()
class Emote {
  final String name;
  final String? realName;
  final int? width;
  final int? height;
  final bool zeroWidth;
  final String url;
  final EmoteType type;
  final String? ownerDisplayName;
  final String? ownerUsername;
  final String? ownerId;

  const Emote({
    required this.name,
    this.realName,
    this.width,
    this.height,
    required this.zeroWidth,
    required this.url,
    required this.type,
    this.ownerDisplayName,
    this.ownerUsername,
    this.ownerId,
  });

  factory Emote.from7TV(Emote7TV emote, EmoteType type) {
    final emoteData = emote.data;

    final url = emoteData.host.url;

    // TODO: Remove if/when Flutter natively supports AVIF.
    final file = emoteData.host.files.lastWhereOrNull(
      (file) => file.format != 'AVIF',
    );

    // Check if the flag has 1 at the 8th bit.
    final isZeroWidth = (emoteData.flags & 256) == 256;

    return Emote(
      name: emote.name,
      realName: emote.name != emoteData.name ? emoteData.name : null,
      width: emoteData.host.files.firstOrNull?.width,
      height: emoteData.host.files.firstOrNull?.height,
      zeroWidth: isZeroWidth,
      url: file != null ? 'https:$url/${file.name}' : '',
      type: type,
      ownerDisplayName: emoteData.owner?.displayName,
      ownerUsername: emoteData.owner?.username,
    );
  }

  factory Emote.fromKick(KickEmoteData emote, EmoteType type) =>
      Emote(name: emote.name, zeroWidth: false, url: emote.url, type: type);

  factory Emote.fromJson(Map<String, dynamic> json) => _$EmoteFromJson(json);
  Map<String, dynamic> toJson() => _$EmoteToJson(this);
}

enum EmoteType {
  kickGlobal,
  kickChannel,
  sevenTVGlobal,
  sevenTVChannel;

  @override
  String toString() {
    switch (this) {
      case EmoteType.kickGlobal:
        return 'Kick global emote';
      case EmoteType.kickChannel:
        return 'Kick channel emote';
      case EmoteType.sevenTVGlobal:
        return '7TV global emote';
      case EmoteType.sevenTVChannel:
        return '7TV channel emote';
    }
  }
}
