// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badges.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BadgeInfoFFZ _$BadgeInfoFFZFromJson(Map<String, dynamic> json) => BadgeInfoFFZ(
  (json['id'] as num).toInt(),
  json['title'] as String,
  json['color'] as String,
  BadgeUrlsFFZ.fromJson(json['urls'] as Map<String, dynamic>),
);

BadgeUrlsFFZ _$BadgeUrlsFFZFromJson(Map<String, dynamic> json) =>
    BadgeUrlsFFZ(json['1'] as String, json['2'] as String, json['4'] as String);

BadgeInfo7TV _$BadgeInfo7TVFromJson(Map<String, dynamic> json) => BadgeInfo7TV(
  json['tooltip'] as String,
  (json['urls'] as List<dynamic>)
      .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
      .toList(),
  (json['users'] as List<dynamic>).map((e) => e as String).toList(),
);

BadgeInfoBTTV _$BadgeInfoBTTVFromJson(Map<String, dynamic> json) =>
    BadgeInfoBTTV(
      json['providerId'] as String,
      BadgeDetailsBTTV.fromJson(json['badge'] as Map<String, dynamic>),
    );

BadgeDetailsBTTV _$BadgeDetailsBTTVFromJson(Map<String, dynamic> json) =>
    BadgeDetailsBTTV(json['description'] as String, json['svg'] as String);
