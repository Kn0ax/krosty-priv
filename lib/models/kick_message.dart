import 'dart:convert';
import 'package:flutter/material.dart';

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
  bool _isDeleted;
  bool _isHistorical;
  bool _isSystemMessage;

  // Cache for the rendered text spans
  List<InlineSpan>? cachedSpan;
  Brightness? cachedBrightness;

  bool get isDeleted => _isDeleted;
  set isDeleted(bool value) {
    if (_isDeleted != value) {
      _isDeleted = value;
      clearCache();
    }
  }

  bool get isHistorical => _isHistorical;
  set isHistorical(bool value) {
    if (_isHistorical != value) {
      _isHistorical = value;
      clearCache();
    }
  }

  bool get isSystemMessage => _isSystemMessage;
  set isSystemMessage(bool value) {
    if (_isSystemMessage != value) {
      _isSystemMessage = value;
      clearCache();
    }
  }

  void clearCache() {
    cachedSpan = null;
    cachedBrightness = null;
  }

  KickChatMessage({
    required this.id,
    required this.chatroomId,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.sender,
    this.metadata,
    bool isDeleted = false,
    bool isHistorical = false,
    bool isSystemMessage = false,
  }) : _isDeleted = isDeleted,
       _isHistorical = isHistorical,
       _isSystemMessage = isSystemMessage;

  /// Parse message from Pusher ChatMessageSentEvent.
  factory KickChatMessage.fromPusherEvent(Map<String, dynamic> eventData) {
    // The 'data' field is a JSON string that needs to be parsed
    final dataString = eventData['data'] as String;
    final data = jsonDecode(dataString) as Map<String, dynamic>;

    return KickChatMessage.fromJson(data);
  }

  /// Parse message from JSON.
  factory KickChatMessage.fromJson(Map<String, dynamic> json) {
    // Handle metadata - can be a string "null", actual null, a JSON string, or a Map
    KickMessageMetadata? metadata;
    final metadataValue = json['metadata'];
    if (metadataValue != null && metadataValue != 'null') {
      if (metadataValue is String) {
        try {
          final parsed = jsonDecode(metadataValue) as Map<String, dynamic>;
          metadata = KickMessageMetadata.fromJson(parsed);
        } catch (_) {
          // Invalid JSON string, ignore
        }
      } else if (metadataValue is Map<String, dynamic>) {
        metadata = KickMessageMetadata.fromJson(metadataValue);
      }
    }

    return KickChatMessage(
      id: json['id'] as String,
      // History API uses 'chat_id', WebSocket uses 'chatroom_id'
      chatroomId: _parseInt(json['chatroom_id'] ?? json['chat_id']),
      content: json['content'] as String? ?? json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'message',
      createdAt: _parseDateTime(json['created_at']),
      sender: KickMessageSender.fromJson(
        json['sender'] as Map<String, dynamic>? ?? {},
      ),
      metadata: metadata,
    );
  }

  /// Create a system notice message.
  ///
  /// [noticeType] can be used to style different types of notices:
  /// - 'system' (default) - General system messages
  /// - 'subscription' - New subscriber or resub
  /// - 'gift' - Gifted subscriptions
  /// - 'follow' - New follower
  /// - 'raid' - Incoming raid
  /// - 'kicks' - Kicks currency gifted
  /// - 'reward' - Channel reward redeemed
  factory KickChatMessage.createNotice({
    required String message,
    int chatroomId = 0,
    String noticeType = 'system',
  }) {
    return KickChatMessage(
      id: 'notice_${noticeType}_${DateTime.now().millisecondsSinceEpoch}',
      chatroomId: chatroomId,
      content: message,
      type: noticeType,
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
          ? KickSenderIdentity.fromJson(
              json['identity'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Create system sender.
  factory KickMessageSender.system() {
    return const KickMessageSender(id: 0, username: 'System', slug: 'system');
  }

  String get displayName => username;
}

/// Kick sender identity (color and badges).
class KickSenderIdentity {
  final String color;
  final List<KickBadgeInfo> badges;

  const KickSenderIdentity({required this.color, required this.badges});

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

  const KickBadgeInfo({required this.type, this.text, this.count});

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

  const KickMessageMetadata({this.originalMessage, this.originalSender});

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

  const KickOriginalMessage({required this.id, required this.content});

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

  const KickOriginalSender({required this.id, required this.username});

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

  const KickPusherEvent({required this.event, this.data, this.channel});

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

  const KickMessageDeletedEvent({required this.id, required this.message});

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
    return KickDeletedMessage(id: json['id'] as String? ?? '');
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
///
/// The Kick API returns nested objects for each mode setting:
/// ```json
/// {
///   "id": 123,
///   "slow_mode": { "enabled": true, "message_interval": 5 },
///   "followers_mode": { "enabled": true, "min_duration": 10 },
///   "subscribers_mode": { "enabled": false },
///   "emotes_mode": { "enabled": false }
/// }
/// ```
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
    // Parse nested mode objects - API returns { "enabled": bool, ... } for each mode
    final slowModeData = json['slow_mode'];
    final followersModeData = json['followers_mode'];
    final subscribersModeData = json['subscribers_mode'];
    final emotesModeData = json['emotes_mode'];

    // Handle both nested objects and flat booleans for backwards compatibility
    bool? parseEnabled(dynamic data) {
      if (data is Map<String, dynamic>) {
        return data['enabled'] as bool?;
      }
      if (data is bool) {
        return data;
      }
      return null;
    }

    int? parseNestedInt(dynamic data, String key) {
      if (data is Map<String, dynamic>) {
        return data[key] as int?;
      }
      return null;
    }

    return KickChatroomUpdatedEvent(
      id: json['id'] as int? ?? 0,
      slowMode: parseEnabled(slowModeData),
      messageInterval:
          parseNestedInt(slowModeData, 'message_interval') ??
          json['message_interval'] as int?,
      followersMode: parseEnabled(followersModeData),
      followingMinDuration:
          parseNestedInt(followersModeData, 'min_duration') ??
          json['following_min_duration'] as int?,
      subscribersMode: parseEnabled(subscribersModeData),
      emotesMode: parseEnabled(emotesModeData),
    );
  }
}

/// Livestream started event data.
class KickLivestreamStartedEvent {
  final int livestreamId;

  const KickLivestreamStartedEvent({required this.livestreamId});

  factory KickLivestreamStartedEvent.fromJson(Map<String, dynamic> json) {
    return KickLivestreamStartedEvent(
      livestreamId: json['livestream_id'] as int? ?? json['id'] as int? ?? 0,
    );
  }
}

/// Livestream stopped event data.
class KickLivestreamStoppedEvent {
  final int livestreamId;

  const KickLivestreamStoppedEvent({required this.livestreamId});

  factory KickLivestreamStoppedEvent.fromJson(Map<String, dynamic> json) {
    return KickLivestreamStoppedEvent(
      livestreamId: json['livestream_id'] as int? ?? json['id'] as int? ?? 0,
    );
  }
}

// ============================================================
// EVENT USER (shared across many event types)
// ============================================================

/// User info in events (follows, subs, gifts, etc).
class KickEventUser {
  final int id;
  final String username;
  final String? slug;

  const KickEventUser({required this.id, required this.username, this.slug});

  factory KickEventUser.fromJson(Map<String, dynamic> json) {
    return KickEventUser(
      id: _safeParseInt(json['id']),
      username: json['username'] as String? ?? '',
      slug: json['slug'] as String?,
    );
  }

  /// Safely parse int from dynamic (handles string IDs).
  static int _safeParseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Channel info in events.
class KickEventChannel {
  final int id;
  final String? slug;

  const KickEventChannel({required this.id, this.slug});

  factory KickEventChannel.fromJson(Map<String, dynamic> json) {
    return KickEventChannel(
      id: KickEventUser._safeParseInt(json['id']),
      slug: json['slug'] as String?,
    );
  }
}

// ============================================================
// PINNED MESSAGE EVENTS
// ============================================================

/// Pinned message created event data.
class KickPinnedMessageEvent {
  final String? duration;
  final KickChatMessage message;
  final KickEventUser? pinnedBy;

  const KickPinnedMessageEvent({
    this.duration,
    required this.message,
    this.pinnedBy,
  });

  factory KickPinnedMessageEvent.fromJson(Map<String, dynamic> json) {
    return KickPinnedMessageEvent(
      duration: json['duration'] as String?,
      message: KickChatMessage.fromJson(
        json['message'] as Map<String, dynamic>? ?? {},
      ),
      pinnedBy: json['pinnedBy'] != null
          ? KickEventUser.fromJson(json['pinnedBy'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ============================================================
// SUBSCRIPTION EVENTS
// ============================================================

/// Subscription event data.
class KickSubscriptionEvent {
  final String? id;
  final int chatroomId;
  final String username;
  final int months;
  final KickEventUser? user;
  final KickEventChannel? channel;
  final KickSubscriptionDetails? subscription;
  final DateTime? createdAt;

  const KickSubscriptionEvent({
    this.id,
    required this.chatroomId,
    required this.username,
    required this.months,
    this.user,
    this.channel,
    this.subscription,
    this.createdAt,
  });

  /// Whether this is a first-time subscriber.
  bool get isNewSubscriber =>
      subscription == null || (subscription!.total ?? 1) <= 1;

  factory KickSubscriptionEvent.fromJson(Map<String, dynamic> json) {
    return KickSubscriptionEvent(
      id: json['id'] as String?,
      chatroomId: KickEventUser._safeParseInt(json['chatroom_id']),
      username: json['username'] as String? ?? '',
      months: json['months'] as int? ?? 1,
      user: json['user'] != null
          ? KickEventUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      channel: json['channel'] != null
          ? KickEventChannel.fromJson(json['channel'] as Map<String, dynamic>)
          : null,
      subscription: json['subscription'] != null
          ? KickSubscriptionDetails.fromJson(
              json['subscription'] as Map<String, dynamic>,
            )
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// Subscription details.
class KickSubscriptionDetails {
  final int interval;
  final int tier;
  final int? total;

  const KickSubscriptionDetails({this.interval = 1, this.tier = 1, this.total});

  factory KickSubscriptionDetails.fromJson(Map<String, dynamic> json) {
    return KickSubscriptionDetails(
      interval: json['interval'] as int? ?? 1,
      tier: json['tier'] as int? ?? 1,
      total: json['total'] as int?,
    );
  }
}

/// Gifted subscription event data.
class KickGiftedSubscriptionEvent {
  final String? id;
  final List<KickEventUser> giftedUsers;
  final KickEventUser? gifter;
  final KickEventChannel? channel;
  final DateTime? createdAt;

  const KickGiftedSubscriptionEvent({
    this.id,
    required this.giftedUsers,
    this.gifter,
    this.channel,
    this.createdAt,
  });

  /// Number of subs gifted.
  int get giftCount => giftedUsers.length;

  factory KickGiftedSubscriptionEvent.fromJson(Map<String, dynamic> json) {
    final users = json['gifted_users'] as List<dynamic>? ?? [];
    return KickGiftedSubscriptionEvent(
      id: json['id'] as String?,
      giftedUsers: users
          .map((u) => KickEventUser.fromJson(u as Map<String, dynamic>))
          .toList(),
      gifter: json['user'] != null
          ? KickEventUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      channel: json['channel'] != null
          ? KickEventChannel.fromJson(json['channel'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

// ============================================================
// FOLLOW EVENT
// ============================================================

/// Channel follow event data.
class KickChannelFollowEvent {
  final String? id;
  final int followersCount;
  final KickEventUser? user;
  final KickEventChannel? channel;
  final bool isFollowing;
  final DateTime? createdAt;

  const KickChannelFollowEvent({
    this.id,
    required this.followersCount,
    this.user,
    this.channel,
    this.isFollowing = true,
    this.createdAt,
  });

  factory KickChannelFollowEvent.fromJson(Map<String, dynamic> json) {
    return KickChannelFollowEvent(
      id: json['id'] as String?,
      followersCount: json['followers_count'] as int? ?? 0,
      user: json['user'] != null
          ? KickEventUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      channel: json['channel'] != null
          ? KickEventChannel.fromJson(json['channel'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Create an unfollow event (sets isFollowing to false).
  KickChannelFollowEvent asUnfollow() {
    return KickChannelFollowEvent(
      id: id,
      followersCount: followersCount,
      user: user,
      channel: channel,
      isFollowing: false,
      createdAt: createdAt,
    );
  }
}

// ============================================================
// RAID EVENT
// ============================================================

/// Raid (host received) event data.
class KickRaidEvent {
  final KickRaidHost host;

  const KickRaidEvent({required this.host});

  factory KickRaidEvent.fromJson(Map<String, dynamic> json) {
    return KickRaidEvent(
      host: KickRaidHost.fromJson(json['host'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Raid host info.
class KickRaidHost {
  final int viewersCount;
  final KickEventUser? user;

  const KickRaidHost({required this.viewersCount, this.user});

  factory KickRaidHost.fromJson(Map<String, dynamic> json) {
    return KickRaidHost(
      viewersCount: json['viewers_count'] as int? ?? 0,
      user: json['user'] != null
          ? KickEventUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ============================================================
// KICKS GIFTED EVENT
// ============================================================

/// Kicks (currency) gifted event data.
class KickKicksGiftedEvent {
  final String? message;
  final KickKicksGiftingUser? sender;
  final KickKicksGift? gift;

  const KickKicksGiftedEvent({this.message, this.sender, this.gift});

  factory KickKicksGiftedEvent.fromJson(Map<String, dynamic> json) {
    return KickKicksGiftedEvent(
      message: json['message'] as String?,
      sender: json['sender'] != null
          ? KickKicksGiftingUser.fromJson(
              json['sender'] as Map<String, dynamic>,
            )
          : null,
      gift: json['gift'] != null
          ? KickKicksGift.fromJson(json['gift'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Kicks gift sender info.
class KickKicksGiftingUser {
  final String? id;
  final String username;
  final String? color;

  const KickKicksGiftingUser({this.id, required this.username, this.color});

  factory KickKicksGiftingUser.fromJson(Map<String, dynamic> json) {
    return KickKicksGiftingUser(
      id: json['id']?.toString(),
      username: json['username'] as String? ?? '',
      color: json['username_color'] as String?,
    );
  }
}

/// Kicks gift details.
class KickKicksGift {
  final String? giftId;
  final String? name;
  final int amount;
  final String? type;
  final String? tier;
  final int? pinnedTime;

  const KickKicksGift({
    this.giftId,
    this.name,
    required this.amount,
    this.type,
    this.tier,
    this.pinnedTime,
  });

  factory KickKicksGift.fromJson(Map<String, dynamic> json) {
    return KickKicksGift(
      giftId: json['gift_id'] as String?,
      name: json['name'] as String?,
      amount: json['amount'] as int? ?? 0,
      type: json['type'] as String?,
      tier: json['tier'] as String?,
      pinnedTime: json['pinned_time'] as int?,
    );
  }
}

// ============================================================
// REWARD REDEEMED EVENT
// ============================================================

/// Channel reward redeemed event data.
class KickRewardRedeemedEvent {
  final String id;
  final KickEventUser? user;
  final KickRedeemedReward reward;
  final DateTime? createdAt;

  const KickRewardRedeemedEvent({
    required this.id,
    this.user,
    required this.reward,
    this.createdAt,
  });

  factory KickRewardRedeemedEvent.fromJson(Map<String, dynamic> json) {
    return KickRewardRedeemedEvent(
      id: json['id'] as String? ?? '',
      user: json['user'] != null
          ? KickEventUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      reward: KickRedeemedReward.fromJson(
        json['reward'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// Redeemed reward details.
class KickRedeemedReward {
  final String id;
  final String title;
  final String? userInput;

  const KickRedeemedReward({
    required this.id,
    required this.title,
    this.userInput,
  });

  factory KickRedeemedReward.fromJson(Map<String, dynamic> json) {
    return KickRedeemedReward(
      id: json['id'] as String? ?? '',
      title: json['reward_title'] as String? ?? json['title'] as String? ?? '',
      userInput: json['user_input'] as String?,
    );
  }
}

// ============================================================
// POLL EVENTS
// ============================================================

/// Poll state enum.
enum KickPollState { inProgress, completed, cancelled }

/// Poll update event data.
class KickPollUpdateEvent {
  final KickPoll poll;
  final KickPollState state;

  const KickPollUpdateEvent({
    required this.poll,
    this.state = KickPollState.inProgress,
  });

  factory KickPollUpdateEvent.fromJson(Map<String, dynamic> json) {
    return KickPollUpdateEvent(
      poll: KickPoll.fromJson(json['poll'] as Map<String, dynamic>? ?? json),
    );
  }

  /// Create a cancelled poll event.
  KickPollUpdateEvent asCancelled() {
    return KickPollUpdateEvent(poll: poll, state: KickPollState.cancelled);
  }

  /// Create a completed poll event.
  KickPollUpdateEvent asCompleted() {
    return KickPollUpdateEvent(poll: poll, state: KickPollState.completed);
  }
}

/// Poll data.
class KickPoll {
  final String? title;
  final int duration;
  final int remaining;
  final int resultDisplayDuration;
  final bool hasVoted;
  final List<KickPollOption> options;

  const KickPoll({
    this.title,
    required this.duration,
    required this.remaining,
    this.resultDisplayDuration = 0,
    this.hasVoted = false,
    required this.options,
  });

  factory KickPoll.fromJson(Map<String, dynamic> json) {
    final optionsList = json['options'] as List<dynamic>? ?? [];
    return KickPoll(
      title: json['title'] as String?,
      duration: json['duration'] as int? ?? 0,
      remaining: json['remaining'] as int? ?? 0,
      resultDisplayDuration: json['result_display_duration'] as int? ?? 0,
      hasVoted: json['has_voted'] as bool? ?? false,
      options: optionsList
          .map((o) => KickPollOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Total votes across all options.
  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.votes);
}

/// Poll option data.
class KickPollOption {
  final int id;
  final String label;
  final int votes;

  const KickPollOption({
    required this.id,
    required this.label,
    required this.votes,
  });

  factory KickPollOption.fromJson(Map<String, dynamic> json) {
    return KickPollOption(
      id: json['id'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      votes: json['votes'] as int? ?? 0,
    );
  }
}

// ============================================================
// PREDICTION EVENTS
// ============================================================

/// Prediction state constants.
abstract class KickPredictionState {
  static const active = 'ACTIVE';
  static const locked = 'LOCKED';
  static const resolved = 'RESOLVED';
  static const cancelled = 'CANCELLED';
}

/// Prediction event data.
class KickPredictionEvent {
  final String id;
  final int channelId;
  final String title;
  final String state;
  final List<KickPredictionOutcome> outcomes;
  final int duration;
  final String? winningOutcomeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lockedAt;

  const KickPredictionEvent({
    required this.id,
    required this.channelId,
    required this.title,
    required this.state,
    required this.outcomes,
    required this.duration,
    this.winningOutcomeId,
    this.createdAt,
    this.updatedAt,
    this.lockedAt,
  });

  /// Check if prediction is active.
  bool get isActive => state == KickPredictionState.active;

  /// Check if prediction is locked.
  bool get isLocked => state == KickPredictionState.locked;

  /// Check if prediction is resolved.
  bool get isResolved => state == KickPredictionState.resolved;

  /// Check if prediction is cancelled.
  bool get isCancelled => state == KickPredictionState.cancelled;

  /// Get winning outcome if resolved.
  KickPredictionOutcome? get winningOutcome {
    if (winningOutcomeId == null) return null;
    return outcomes.cast<KickPredictionOutcome?>().firstWhere(
      (o) => o?.id == winningOutcomeId,
      orElse: () => null,
    );
  }

  /// Total vote amount across all outcomes.
  int get totalVoteAmount =>
      outcomes.fold(0, (sum, o) => sum + o.totalVoteAmount);

  factory KickPredictionEvent.fromJson(Map<String, dynamic> json) {
    // Handle wrapped response {prediction: {...}}
    final data = json['prediction'] as Map<String, dynamic>? ?? json;

    final outcomesList = data['outcomes'] as List<dynamic>? ?? [];
    return KickPredictionEvent(
      id: data['id'] as String? ?? '',
      channelId: KickEventUser._safeParseInt(data['channel_id']),
      title: data['title'] as String? ?? '',
      state: data['state'] as String? ?? KickPredictionState.active,
      outcomes: outcomesList
          .map((o) => KickPredictionOutcome.fromJson(o as Map<String, dynamic>))
          .toList(),
      duration: data['duration'] as int? ?? 0,
      winningOutcomeId: data['winning_outcome_id'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'] as String)
          : null,
      lockedAt: data['locked_at'] != null
          ? DateTime.tryParse(data['locked_at'] as String)
          : null,
    );
  }
}

/// Prediction outcome data.
class KickPredictionOutcome {
  final String id;
  final String title;
  final int totalVoteAmount;
  final int voteCount;
  final double returnRate;

  const KickPredictionOutcome({
    required this.id,
    required this.title,
    required this.totalVoteAmount,
    required this.voteCount,
    this.returnRate = 1.0,
  });

  factory KickPredictionOutcome.fromJson(Map<String, dynamic> json) {
    return KickPredictionOutcome(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      totalVoteAmount: json['total_vote_amount'] as int? ?? 0,
      voteCount: json['vote_count'] as int? ?? 0,
      returnRate: (json['return_rate'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Calculate percentage of total votes.
  double percentageOf(int totalVotes) {
    if (totalVotes == 0) return 0;
    return (totalVoteAmount / totalVotes) * 100;
  }
}

// ============================================================
// PUSHER EVENT TYPES
// ============================================================

/// Known Pusher event types for Kick chat.
///
/// Events are organized by the channel they arrive on:
/// - `chatrooms.{id}.v2` - Public chat events
/// - `channel_{id}` - Public channel events (stream status, kicks gifted)
/// - `private-chatroom_{id}` - Mod events (bans, chat mode changes)
/// - `private-channel_{id}` - Follows, subscriptions, rewards
/// - `private-livestream_{id}` - Raids
/// - `predictions-channel-{id}` - Predictions
abstract class KickPusherEventTypes {
  // ============================================================
  // CONNECTION EVENTS
  // ============================================================
  static const connectionEstablished = 'pusher:connection_established';
  static const subscriptionSucceeded = 'pusher_internal:subscription_succeeded';
  static const subscriptionError = 'pusher:subscription_error';
  static const ping = 'pusher:ping';
  static const pong = 'pusher:pong';
  static const error = 'pusher:error';

  // ============================================================
  // PUBLIC CHATROOM EVENTS (chatrooms.{id}.v2)
  // ============================================================
  static const chatMessage = r'App\Events\ChatMessageEvent';
  static const chatMessageSent = r'App\Events\ChatMessageSentEvent';
  static const messageDeleted = r'App\Events\MessageDeletedEvent';
  static const chatMessageDeleted = r'App\Events\ChatMessageDeletedEvent';
  static const userBanned = r'App\Events\UserBannedEvent';
  static const userUnbanned = r'App\Events\UserUnbannedEvent';
  static const chatroomUpdated = r'App\Events\ChatroomUpdatedEvent';
  static const chatroomClear = r'App\Events\ChatroomClearEvent';

  // Pinned message events (public chatroom)
  static const pinnedMessageCreated = r'App\Events\PinnedMessageCreatedEvent';
  static const pinnedMessageDeleted = r'App\Events\PinnedMessageDeletedEvent';

  // Poll events (public chatroom)
  static const pollUpdate = r'App\Events\PollUpdateEvent';
  static const pollDelete = r'App\Events\PollDeleteEvent';

  // Public subscription event (different from private-channel version)
  static const subscriptionEvent = r'App\Events\SubscriptionEvent';
  static const giftedSubscription = r'App\Events\GiftedSubscriptionsEvent';
  static const luckyUsersWhoGotGiftSubscriptions =
      r'App\Events\LuckyUsersWhoGotGiftSubscriptionsEvent';

  // ============================================================
  // PUBLIC CHANNEL EVENTS (channel_{id})
  // ============================================================
  static const livestreamStarted = r'App\Events\StreamerIsLive';
  static const livestreamStopped = r'App\Events\StopStreamBroadcast';
  static const kicksGifted = 'KicksGifted';
  static const channelSubscription = r'App\Events\ChannelSubscriptionEvent';

  // ============================================================
  // PRIVATE CHATROOM EVENTS (private-chatroom_{id})
  // Requires Pusher authentication
  // ============================================================
  static const bannedWordAdded = 'BannedWordAdded';
  static const bannedWordDeleted = 'BannedWordDeleted';
  static const bannedUserAdded = 'BannedUserAdded';
  static const bannedUserDeleted = 'BannedUserDeleted';
  static const userTimeouted = 'UserTimeouted';
  static const slowModeActivated = 'SlowModeActivated';
  static const slowModeDeactivated = 'SlowModeDeactivated';
  static const emotesModeActivated = 'EmotesModeActivated';
  static const emotesModeDeactivated = 'EmotesModeDeactivated';
  static const followersModeActivated = 'FollowersModeActivated';
  static const followersModeDeactivated = 'FollowersModeDeactivated';
  static const subscribersModeActivated = 'SubscribersModeActivated';
  static const subscribersModeDeactivated = 'SubscribersModeDeactivated';
  static const allowLinksActivated = 'AllowLinksActivated';
  static const allowLinksDeactivated = 'AllowLinksDeactivated';
  static const messagePinned = 'MessagePinned';
  static const messageUnpinned = 'MessageUnpinned';
  static const pollCreated = 'PollCreated';
  static const pollDeleted = 'PollDeleted';

  // ============================================================
  // PRIVATE CHANNEL EVENTS (private-channel_{id})
  // Requires Pusher authentication
  // ============================================================
  static const followerAdded = 'FollowerAdded';
  static const followerDeleted = 'FollowerDeleted';
  static const subscriptionCreated = 'SubscriptionCreated';
  static const subscriptionRenewed = 'SubscriptionRenewed';
  static const subscriptionGifted = 'SubscriptionGifted';
  static const redeemedReward = 'RedeemedReward';

  // ============================================================
  // PRIVATE LIVESTREAM EVENTS (private-livestream_{id})
  // Requires Pusher authentication
  // ============================================================
  static const hostReceived = 'HostReceived';
  static const titleChanged = 'TitleChanged';
  static const categoryChanged = 'CategoryChanged';
  static const matureModeActivated = 'MatureModeActivated';
  static const matureModeDeactivated = 'MatureModeDeactivated';

  // Private livestream updated (private-livestream-updated.{id})
  static const livestreamUpdated =
      r'App\Events\LiveStream\UpdatedLiveStreamEvent';

  // ============================================================
  // PREDICTION EVENTS (predictions-channel-{id})
  // ============================================================
  static const predictionCreated = 'PredictionCreated';
  static const predictionUpdated = 'PredictionUpdated';
}
