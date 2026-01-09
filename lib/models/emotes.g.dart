// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emotes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Emote7TV _$Emote7TVFromJson(Map<String, dynamic> json) => Emote7TV(
  json['id'] as String,
  json['name'] as String,
  Emote7TVData.fromJson(json['data'] as Map<String, dynamic>),
);

Owner7TV _$Owner7TVFromJson(Map<String, dynamic> json) => Owner7TV(
  username: json['username'] as String,
  displayName: json['display_name'] as String,
);

Emote7TVData _$Emote7TVDataFromJson(Map<String, dynamic> json) => Emote7TVData(
  json['id'] as String,
  json['name'] as String,
  (json['flags'] as num).toInt(),
  json['owner'] == null
      ? null
      : Owner7TV.fromJson(json['owner'] as Map<String, dynamic>),
  Emote7TVHost.fromJson(json['host'] as Map<String, dynamic>),
);

Emote7TVHost _$Emote7TVHostFromJson(Map<String, dynamic> json) => Emote7TVHost(
  json['url'] as String,
  (json['files'] as List<dynamic>)
      .map((e) => Emote7TVFile.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Emote7TVFile _$Emote7TVFileFromJson(Map<String, dynamic> json) => Emote7TVFile(
  json['name'] as String,
  (json['width'] as num).toInt(),
  (json['height'] as num).toInt(),
  json['format'] as String,
);

Emote _$EmoteFromJson(Map<String, dynamic> json) => Emote(
  name: json['name'] as String,
  id: json['id'] as String?,
  realName: json['realName'] as String?,
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  zeroWidth: json['zeroWidth'] as bool,
  url: json['url'] as String,
  lowQualityUrl: json['lowQualityUrl'] as String?,
  type: $enumDecode(_$EmoteTypeEnumMap, json['type']),
  ownerDisplayName: json['ownerDisplayName'] as String?,
  ownerUsername: json['ownerUsername'] as String?,
  ownerId: json['ownerId'] as String?,
);

Map<String, dynamic> _$EmoteToJson(Emote instance) => <String, dynamic>{
  'name': instance.name,
  'id': instance.id,
  'realName': instance.realName,
  'width': instance.width,
  'height': instance.height,
  'zeroWidth': instance.zeroWidth,
  'url': instance.url,
  'type': _$EmoteTypeEnumMap[instance.type]!,
  'ownerDisplayName': instance.ownerDisplayName,
  'ownerUsername': instance.ownerUsername,
  'ownerId': instance.ownerId,
  'lowQualityUrl': instance.lowQualityUrl,
};

const _$EmoteTypeEnumMap = {
  EmoteType.kickGlobal: 'kickGlobal',
  EmoteType.kickChannel: 'kickChannel',
  EmoteType.sevenTVGlobal: 'sevenTVGlobal',
  EmoteType.sevenTVChannel: 'sevenTVChannel',
};
