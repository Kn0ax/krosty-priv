// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kick_video.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KickVideo _$KickVideoFromJson(Map<String, dynamic> json) => KickVideo(
  id: (json['id'] as num).toInt(),
  slug: json['slug'] as String?,
  channelId: (json['channel_id'] as num?)?.toInt(),
  createdAt: json['created_at'] as String?,
  sessionTitle: json['session_title'] as String?,
  isLive: json['is_live'] as bool?,
  startTime: json['start_time'] as String?,
  source: json['source'] as String?,
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
  views: (json['views'] as num?)?.toInt(),
  video: json['video'] == null
      ? null
      : KickVideoMeta.fromJson(json['video'] as Map<String, dynamic>),
);

KickVideoMeta _$KickVideoMetaFromJson(Map<String, dynamic> json) =>
    KickVideoMeta(
      id: (json['id'] as num?)?.toInt(),
      liveStreamId: (json['live_stream_id'] as num?)?.toInt(),
      uuid: json['uuid'] as String?,
      views: (json['views'] as num?)?.toInt(),
      isPrivate: json['is_private'] as bool?,
      status: json['status'] as String?,
    );
