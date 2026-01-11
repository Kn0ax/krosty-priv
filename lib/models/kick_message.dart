import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:krosty/models/kick_user.dart';

/// Kick chat message model from Pusher WebSocket events.
///
/// Pusher event format:
/// ```json
/// {
///   "event": "App\\Events\\ChatMessageSentEvent",
///   "data": "{\"id\":\"abc\",\"chatroom_id\":123,\"content\":\"Hello\",\"type\":\"message\",\"created_at\":\"2024-01-01T00:00:00.000Z\",\"sender\":{...}}",
///   "channel": "chatrooms.123"
/// }
/// ```
class KickChatMessage {
  final String id;
  final int chatroomId;
  final String content;
  final String type;
  final DateTime createdAt;
  final KickMessageSender sender;
  final KickMessageMetadata? metadata;

  // UI state flags (similar to IRCMessage)
  bool isDeleted;
  bool isHistorical;
  bool isSystemMessage;

  KickChatMessage({
    required this.id,
    required this.chatroomId,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.sender,
    this.metadata,
    this.isDeleted = false,
    this.isHistorical = false,
    this.isSystemMessage = false,
  });

  /// Parse message from Pusher ChatMessageSentEvent.
  factory KickChatMessage.fromPusherEvent(Map<String, dynamic> eventData) {
    // The 'data' field is a JSON string that needs to be parsed
    final dataString = eventData['data'] as String;
    final data = jsonDecode(dataString) as Map<String, dynamic>;

    return KickChatMessage.fromJson(data);
  }

  /// Parse message from JSON.
  factory KickChatMessage.fromJson(Map<String, dynamic> json) {
    return KickChatMessage(
      id: json['id'] as String,
      chatroomId: _parseInt(json['chatroom_id']),
      content: json['content'] as String? ?? json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'message',
      createdAt: _parseDateTime(json['created_at']),
      sender: KickMessageSender.fromJson(
        json['sender'] as Map<String, dynamic>? ?? {},
      ),
      metadata: json['metadata'] != null
          ? KickMessageMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Create a system/notice message.
  factory KickChatMessage.createNotice({
    required String message,
    int chatroomId = 0,
  }) {
    return KickChatMessage(
      id: 'notice_${DateTime.now().millisecondsSinceEpoch}',
      chatroomId: chatroomId,
      content: message,
      type: 'system',
      createdAt: DateTime.now(),
      sender: KickMessageSender.system(),
      isSystemMessage: true,
    );
  }

  /// Create a historical message (from recent messages).
  factory KickChatMessage.historical(Map<String, dynamic> json) {
    final message = KickChatMessage.fromJson(json);
    message.isHistorical = true;
    return message;
  }

  /// Check if message is a reply.
  bool get isReply => metadata?.originalMessage != null;

  /// Get the original message this is replying to.
  KickOriginalMessage? get replyTo => metadata?.originalMessage;

  /// Get sender's display name.
  String get senderName => sender.username;

  /// Get sender's color (for username display).
  String? get senderColor => sender.identity?.color;

  /// Get sender's badges.
  List<KickBadgeInfo> get senderBadges => sender.identity?.badges ?? [];

  /// Check if sender is a subscriber.
  bool get isSenderSubscriber {
    return senderBadges.any((b) => b.type == 'subscriber');
  }

  /// Check if sender is a moderator.
  bool get isSenderModerator {
    return senderBadges.any((b) => b.type == 'moderator');
  }

  /// Check if sender is the broadcaster.
  bool get isSenderBroadcaster {
    return senderBadges.any((b) => b.type == 'broadcaster');
  }

  /// Check if sender is VIP.
  bool get isSenderVip {
    return senderBadges.any((b) => b.type == 'vip');
  }

  /// Check if sender is verified.
  bool get isSenderVerified {
    return senderBadges.any((b) => b.type == 'verified');
  }

  /// Get words split by spaces (for emote matching).
  List<String> get words => content.split(' ');

  // Helper to parse int from dynamic
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Helper to parse DateTime from various formats
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      // Unix timestamp in seconds
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

/// Kick message sender model.
class KickMessageSender {
  final int id;
  final String username;
  final String slug;
  final KickSenderIdentity? identity;

  const KickMessageSender({
    required this.id,
    required this.username,
    required this.slug,
    this.identity,
  });

  factory KickMessageSender.fromJson(Map<String, dynamic> json) {
    return KickMessageSender(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? 'Unknown',
      slug: json['slug'] as String? ?? '',
      identity: json['identity'] != null
          ? KickSenderIdentity.fromJson(json['identity'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Create system sender.
  factory KickMessageSender.system() {
    return const KickMessageSender(
      id: 0,
      username: 'System',
      slug: 'system',
      identity: null,
    );
  }

  String get displayName => username;
}

/// Kick sender identity (color and badges).
class KickSenderIdentity {
  final String color;
  final List<KickBadgeInfo> badges;

  const KickSenderIdentity({
    required this.color,
    required this.badges,
  });

  factory KickSenderIdentity.fromJson(Map<String, dynamic> json) {
    final badgesList = json['badges'] as List<dynamic>? ?? [];
    return KickSenderIdentity(
      color: json['color'] as String? ?? '',
      badges: badgesList
          .map((b) => KickBadgeInfo.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Kick badge info (type and text).
class KickBadgeInfo {
  final String type;
  final String? text;
  final int? count;

  const KickBadgeInfo({
    required this.type,
    this.text,
    this.count,
  });

  factory KickBadgeInfo.fromJson(Map<String, dynamic> json) {
    return KickBadgeInfo(
      type: json['type'] as String? ?? '',
      text: json['text'] as String?,
      count: json['count'] as int?,
    );
  }
}

/// Kick message metadata (for replies).
class KickMessageMetadata {
  final KickOriginalMessage? originalMessage;
  final KickOriginalSender? originalSender;

  const KickMessageMetadata({
    this.originalMessage,
    this.originalSender,
  });

  factory KickMessageMetadata.fromJson(Map<String, dynamic> json) {
    return KickMessageMetadata(
      originalMessage: json['original_message'] != null
          ? KickOriginalMessage.fromJson(
              json['original_message'] as Map<String, dynamic>,
            )
          : null,
      originalSender: json['original_sender'] != null
          ? KickOriginalSender.fromJson(
              json['original_sender'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Original message in a reply.
class KickOriginalMessage {
  final String id;
  final String content;

  const KickOriginalMessage({
    required this.id,
    required this.content,
  });

  factory KickOriginalMessage.fromJson(Map<String, dynamic> json) {
    return KickOriginalMessage(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

/// Original sender in a reply.
class KickOriginalSender {
  final int id;
  final String username;

  const KickOriginalSender({
    required this.id,
    required this.username,
  });

  factory KickOriginalSender.fromJson(Map<String, dynamic> json) {
    return KickOriginalSender(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
    );
  }
}

// ============================================================
// PUSHER EVENT MODELS
// ============================================================

/// Base Pusher event wrapper.
class KickPusherEvent {
  final String event;
  final String? data;
  final String? channel;

  const KickPusherEvent({
    required this.event,
    this.data,
    this.channel,
  });

  factory KickPusherEvent.fromJson(Map<String, dynamic> json) {
    return KickPusherEvent(
      event: json['event'] as String? ?? '',
      data: json['data'] as String?,
      channel: json['channel'] as String?,
    );
  }

  /// Get parsed data as Map.
  Map<String, dynamic>? get parsedData {
    if (data == null) return null;
    try {
      return jsonDecode(data!) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}

/// Pusher connection established event data.
class KickPusherConnectionData {
  final String socketId;
  final int? activityTimeout;

  const KickPusherConnectionData({
    required this.socketId,
    this.activityTimeout,
  });

  factory KickPusherConnectionData.fromJson(Map<String, dynamic> json) {
    return KickPusherConnectionData(
      socketId: json['socket_id'] as String? ?? '',
      activityTimeout: json['activity_timeout'] as int?,
    );
  }
}

/// Chat message deleted event data.
class KickMessageDeletedEvent {
  final String id;
  final KickDeletedMessage message;

  const KickMessageDeletedEvent({
    required this.id,
    required this.message,
  });

  factory KickMessageDeletedEvent.fromJson(Map<String, dynamic> json) {
    return KickMessageDeletedEvent(
      id: json['id'] as String? ?? '',
      message: KickDeletedMessage.fromJson(
        json['message'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Deleted message info.
class KickDeletedMessage {
  final String id;

  const KickDeletedMessage({required this.id});

  factory KickDeletedMessage.fromJson(Map<String, dynamic> json) {
    return KickDeletedMessage(
      id: json['id'] as String? ?? '',
    );
  }
}

/// User banned event data.
class KickUserBannedEvent {
  final String id;
  final KickBannedUser user;
  final KickBannedUser? bannedBy;
  final bool permanent;
  final int? duration;
  final DateTime? expiresAt;

  const KickUserBannedEvent({
    required this.id,
    required this.user,
    this.bannedBy,
    this.permanent = false,
    this.duration,
    this.expiresAt,
  });

  factory KickUserBannedEvent.fromJson(Map<String, dynamic> json) {
    return KickUserBannedEvent(
      id: json['id'] as String? ?? '',
      user: KickBannedUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
      bannedBy: json['banned_by'] != null
          ? KickBannedUser.fromJson(json['banned_by'] as Map<String, dynamic>)
          : null,
      permanent: json['permanent'] as bool? ?? false,
      duration: json['duration'] as int?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }
}

/// Banned user info.
class KickBannedUser {
  final int id;
  final String username;
  final String slug;

  const KickBannedUser({
    required this.id,
    required this.username,
    required this.slug,
  });

  factory KickBannedUser.fromJson(Map<String, dynamic> json) {
    return KickBannedUser(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }
}

/// User unbanned event data.
class KickUserUnbannedEvent {
  final String id;
  final KickBannedUser user;
  final KickBannedUser? unbannedBy;

  const KickUserUnbannedEvent({
    required this.id,
    required this.user,
    this.unbannedBy,
  });

  factory KickUserUnbannedEvent.fromJson(Map<String, dynamic> json) {
    return KickUserUnbannedEvent(
      id: json['id'] as String? ?? '',
      user: KickBannedUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
      unbannedBy: json['unbanned_by'] != null
          ? KickBannedUser.fromJson(json['unbanned_by'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Chatroom updated event data (slow mode, followers only, etc).
class KickChatroomUpdatedEvent {
  final int id;
  final bool? slowMode;
  final bool? subscribersMode;
  final bool? followersMode;
  final bool? emotesMode;
  final int? messageInterval;
  final int? followingMinDuration;

  const KickChatroomUpdatedEvent({
    required this.id,
    this.slowMode,
    this.subscribersMode,
    this.followersMode,
    this.emotesMode,
    this.messageInterval,
    this.followingMinDuration,
  });

  factory KickChatroomUpdatedEvent.fromJson(Map<String, dynamic> json) {
    return KickChatroomUpdatedEvent(
      id: json['id'] as int? ?? 0,
      slowMode: json['slow_mode'] as bool?,
      subscribersMode: json['subscribers_mode'] as bool?,
      followersMode: json['followers_mode'] as bool?,
      emotesMode: json['emotes_mode'] as bool?,
      messageInterval: json['message_interval'] as int?,
      followingMinDuration: json['following_min_duration'] as int?,
    );
  }
}

/// Livestream started event data.
class KickLivestreamStartedEvent {
  final int livestreamId;

  const KickLivestreamStartedEvent({required this.livestreamId});

  factory KickLivestreamStartedEvent.fromJson(Map<String, dynamic> json) {
    return KickLivestreamStartedEvent(
      livestreamId: json['livestream_id'] as int? ??
          json['id'] as int? ??
          0,
    );
  }
}

/// Livestream stopped event data.
class KickLivestreamStoppedEvent {
  final int livestreamId;

  const KickLivestreamStoppedEvent({required this.livestreamId});

  factory KickLivestreamStoppedEvent.fromJson(Map<String, dynamic> json) {
    return KickLivestreamStoppedEvent(
      livestreamId: json['livestream_id'] as int? ??
          json['id'] as int? ??
          0,
    );
  }
}

// ============================================================
// PUSHER EVENT TYPES
// ============================================================

/// Known Pusher event types for Kick chat.
abstract class KickPusherEventTypes {
  // Connection events
  static const connectionEstablished = 'pusher:connection_established';
  static const subscriptionSucceeded = 'pusher_internal:subscription_succeeded';
  static const subscriptionError = 'pusher:subscription_error';
  static const ping = 'pusher:ping';
  static const pong = 'pusher:pong';
  static const error = 'pusher:error';

  // Chat events
  static const chatMessage = r'App\Events\ChatMessageEvent';
  static const chatMessageSent = r'App\Events\ChatMessageSentEvent';
  static const messageDeleted = r'App\Events\MessageDeletedEvent';
  static const chatMessageDeleted = r'App\Events\ChatMessageDeletedEvent';

  // User events
  static const userBanned = r'App\Events\UserBannedEvent';
  static const userUnbanned = r'App\Events\UserUnbannedEvent';

  // Chatroom events
  static const chatroomUpdated = r'App\Events\ChatroomUpdatedEvent';
  static const chatroomClear = r'App\Events\ChatroomClearEvent';

  // Livestream events
  static const livestreamStarted = r'App\Events\StreamerIsLive';
  static const livestreamStopped = r'App\Events\StopStreamBroadcast';

  // Subscription events
  static const subscriptionEvent = r'App\Events\SubscriptionEvent';
  static const giftedSubscription = r'App\Events\GiftedSubscriptionsEvent';
  static const luckyUsersWhoGotGiftSubscriptions =
      r'App\Events\LuckyUsersWhoGotGiftSubscriptionsEvent';
}
