/// Chatroom state/settings from the Kick API.
///
/// Fetched from `/api/v2/channels/{slug}/chatroom` when joining a chat.
/// Contains chat modes and restrictions that affect message sending.
class KickChatroomState {
  final int id;
  final KickSlowMode slowMode;
  final KickSubscribersMode subscribersMode;
  final KickFollowersMode followersMode;
  final KickEmotesMode emotesMode;
  final KickAdvancedBotProtection advancedBotProtection;
  final KickAccountAge accountAge;
  final dynamic pinnedMessage;
  final bool showQuickEmotes;
  final bool showBanners;
  final bool giftsEnabled;
  final bool giftsWeekEnabled;
  final bool giftsMonthEnabled;

  const KickChatroomState({
    required this.id,
    required this.slowMode,
    required this.subscribersMode,
    required this.followersMode,
    required this.emotesMode,
    required this.advancedBotProtection,
    required this.accountAge,
    this.pinnedMessage,
    this.showQuickEmotes = false,
    this.showBanners = false,
    this.giftsEnabled = false,
    this.giftsWeekEnabled = false,
    this.giftsMonthEnabled = false,
  });

  factory KickChatroomState.fromJson(Map<String, dynamic> json) {
    return KickChatroomState(
      id: json['id'] as int? ?? 0,
      slowMode: KickSlowMode.fromJson(
        json['slow_mode'] as Map<String, dynamic>? ?? {},
      ),
      subscribersMode: KickSubscribersMode.fromJson(
        json['subscribers_mode'] as Map<String, dynamic>? ?? {},
      ),
      followersMode: KickFollowersMode.fromJson(
        json['followers_mode'] as Map<String, dynamic>? ?? {},
      ),
      emotesMode: KickEmotesMode.fromJson(
        json['emotes_mode'] as Map<String, dynamic>? ?? {},
      ),
      advancedBotProtection: KickAdvancedBotProtection.fromJson(
        json['advanced_bot_protection'] as Map<String, dynamic>? ?? {},
      ),
      accountAge: KickAccountAge.fromJson(
        json['account_age'] as Map<String, dynamic>? ?? {},
      ),
      pinnedMessage: json['pinned_message'],
      showQuickEmotes:
          (json['show_quick_emotes'] as Map<String, dynamic>?)?['enabled']
                  as bool? ??
              false,
      showBanners:
          (json['show_banners'] as Map<String, dynamic>?)?['enabled'] as bool? ??
              false,
      giftsEnabled:
          (json['gifts_enabled'] as Map<String, dynamic>?)?['enabled']
                  as bool? ??
              false,
      giftsWeekEnabled:
          (json['gifts_week_enabled'] as Map<String, dynamic>?)?['enabled']
                  as bool? ??
              false,
      giftsMonthEnabled:
          (json['gifts_month_enabled'] as Map<String, dynamic>?)?['enabled']
                  as bool? ??
              false,
    );
  }

  /// Default state with no restrictions.
  static const none = KickChatroomState(
    id: 0,
    slowMode: KickSlowMode.disabled,
    subscribersMode: KickSubscribersMode.disabled,
    followersMode: KickFollowersMode.disabled,
    emotesMode: KickEmotesMode.disabled,
    advancedBotProtection: KickAdvancedBotProtection.disabled,
    accountAge: KickAccountAge.disabled,
  );
}

/// Slow mode settings - limits how often users can send messages.
class KickSlowMode {
  final bool enabled;

  /// Message interval in seconds (e.g., 5 = can only send a message every 5 seconds).
  final int messageInterval;

  const KickSlowMode({required this.enabled, this.messageInterval = 0});

  factory KickSlowMode.fromJson(Map<String, dynamic> json) {
    return KickSlowMode(
      enabled: json['enabled'] as bool? ?? false,
      messageInterval: json['message_interval'] as int? ?? 0,
    );
  }

  static const disabled = KickSlowMode(enabled: false);
}

/// Subscribers-only mode - only subscribers can chat.
class KickSubscribersMode {
  final bool enabled;

  const KickSubscribersMode({required this.enabled});

  factory KickSubscribersMode.fromJson(Map<String, dynamic> json) {
    return KickSubscribersMode(enabled: json['enabled'] as bool? ?? false);
  }

  static const disabled = KickSubscribersMode(enabled: false);
}

/// Followers-only mode - only followers can chat.
class KickFollowersMode {
  final bool enabled;

  /// Minimum follow duration in minutes (e.g., 1 = must have followed for at least 1 minute).
  final int minDuration;

  const KickFollowersMode({required this.enabled, this.minDuration = 0});

  factory KickFollowersMode.fromJson(Map<String, dynamic> json) {
    return KickFollowersMode(
      enabled: json['enabled'] as bool? ?? false,
      minDuration: json['min_duration'] as int? ?? 0,
    );
  }

  static const disabled = KickFollowersMode(enabled: false);
}

/// Emotes-only mode - only emote messages are allowed.
class KickEmotesMode {
  final bool enabled;

  const KickEmotesMode({required this.enabled});

  factory KickEmotesMode.fromJson(Map<String, dynamic> json) {
    return KickEmotesMode(enabled: json['enabled'] as bool? ?? false);
  }

  static const disabled = KickEmotesMode(enabled: false);
}

/// Advanced bot protection settings.
class KickAdvancedBotProtection {
  final bool enabled;
  final int remainingTime;

  const KickAdvancedBotProtection({
    required this.enabled,
    this.remainingTime = 0,
  });

  factory KickAdvancedBotProtection.fromJson(Map<String, dynamic> json) {
    return KickAdvancedBotProtection(
      enabled: json['enabled'] as bool? ?? false,
      remainingTime: json['remaining_time'] as int? ?? 0,
    );
  }

  static const disabled = KickAdvancedBotProtection(enabled: false);
}

/// Account age restriction - accounts must be a certain age to chat.
class KickAccountAge {
  final bool enabled;

  /// Minimum account age in minutes.
  final int minDuration;

  const KickAccountAge({required this.enabled, this.minDuration = 0});

  factory KickAccountAge.fromJson(Map<String, dynamic> json) {
    return KickAccountAge(
      enabled: json['enabled'] as bool? ?? false,
      minDuration: json['min_duration'] as int? ?? 0,
    );
  }

  static const disabled = KickAccountAge(enabled: false);
}
