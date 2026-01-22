import 'package:json_annotation/json_annotation.dart';
import 'package:krosty/models/kick_channel.dart';

part 'kick_video.g.dart';

/// Kick video/VOD model from /api/v2/channels/{slug}/videos endpoint.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickVideo {
  final int id;
  final String? slug;
  @JsonKey(name: 'channel_id')
  final int? channelId;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'session_title')
  final String? sessionTitle;
  @JsonKey(name: 'is_live')
  final bool? isLive;
  @JsonKey(name: 'start_time')
  final String? startTime;

  /// HLS m3u8 URL for VOD playback.
  final String? source;

  /// Duration in milliseconds.
  final int? duration;
  final String? language;
  @JsonKey(name: 'is_mature')
  final bool? isMature;
  @JsonKey(name: 'viewer_count')
  final int? viewerCount;
  final KickThumbnail? thumbnail;
  final List<KickCategory>? categories;
  final int? views;

  /// Metadata about the video including privacy status.
  final KickVideoMeta? video;

  const KickVideo({
    required this.id,
    this.slug,
    this.channelId,
    this.createdAt,
    this.sessionTitle,
    this.isLive,
    this.startTime,
    this.source,
    this.duration,
    this.language,
    this.isMature,
    this.viewerCount,
    this.thumbnail,
    this.categories,
    this.views,
    this.video,
  });

  factory KickVideo.fromJson(Map<String, dynamic> json) =>
      _$KickVideoFromJson(json);

  /// Get video title.
  String get title => sessionTitle ?? '';

  /// Get category name (first category).
  String get categoryName =>
      categories?.isNotEmpty == true ? categories!.first.name : '';

  /// Get thumbnail URL.
  String? get thumbnailUrl => thumbnail?.imageUrl;

  /// Check if video is public (available to play).
  bool get isPublic => video?.status == 'public' && video?.isPrivate != true;

  /// Check if video is subscriber-only.
  bool get isSubscriberOnly => video?.status == 'subscriber_only';

  /// Check if video is playable by the user.
  /// Public videos are always playable.
  /// Subscriber-only videos are playable if the user is a subscriber and the video has a source.
  bool isPlayable({required bool isSubscriber}) {
    if (isPublic) return true;
    if (isSubscriberOnly && isSubscriber && source != null) return true;
    return false;
  }

  /// Get formatted duration string (e.g., "1h 23m" or "45m").
  String get formattedDuration {
    if (duration == null) return '';
    final totalSeconds = duration! ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Kick video metadata model.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class KickVideoMeta {
  final int? id;
  @JsonKey(name: 'live_stream_id')
  final int? liveStreamId;
  final String? uuid;
  final int? views;
  @JsonKey(name: 'is_private')
  final bool? isPrivate;

  /// Status of the video: "public" or "private".
  final String? status;

  const KickVideoMeta({
    this.id,
    this.liveStreamId,
    this.uuid,
    this.views,
    this.isPrivate,
    this.status,
  });

  factory KickVideoMeta.fromJson(Map<String, dynamic> json) =>
      _$KickVideoMetaFromJson(json);
}
