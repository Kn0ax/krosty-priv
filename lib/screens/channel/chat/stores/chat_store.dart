import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/constants.dart';
import 'package:krosty/models/emotes.dart';
import 'package:krosty/models/kick_chatroom_state.dart';
import 'package:krosty/models/kick_message.dart';
import 'package:krosty/screens/channel/chat/details/chat_details_store.dart';
import 'package:krosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/utils.dart';
import 'package:mobx/mobx.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'chat_store.g.dart';

/// The store and view-model for chat-related activities.
/// Uses Kick Pusher WebSocket for real-time chat.
class ChatStore = ChatStoreBase with _$ChatStore;

abstract class ChatStoreBase with Store {
  /// The total maximum amount of messages in chat.
  static const _messageLimit = 5000;

  /// The maximum amount of messages to render when autoscroll is enabled.
  static const _renderMessageLimit = 100;

  /// Base height of the bottom bar (input field area).
  static const _baseBottomBarHeight = 68.0;

  /// Height of the autocomplete bar (SizedBox + Divider).
  static const _autocompleteHeight = 51.0;

  /// Height of the reply bar (Container + Divider).
  static const _replyBarHeight = 41.0;

  /// Kick API service for sending messages and fetching data.
  final KickApi kickApi;

  /// The amount of messages to free (remove) when the [_messageLimit] is reached.
  final _messagesToRemove = (_messageLimit * 0.2).toInt();

  /// The provided auth store to determine login status.
  final AuthStore auth;

  /// The provided setting store to account for any user-defined behaviors.
  final SettingsStore settings;

  /// The focus node for the textfield.
  final textFieldFocusNode = FocusNode();

  /// The channel slug (username) to connect to.
  final String channelSlug;

  /// The chatroom ID for Pusher subscription.
  int? chatroomId;

  /// The channel ID for API calls (e.g., chat history).
  int? channelId;

  /// The livestream ID (if channel is live). Used for private livestream subscriptions.
  int? livestreamId;

  /// Current stream title (updated via Pusher events).
  @observable
  String? streamTitle;

  /// Current stream category (updated via Pusher events).
  @observable
  String? streamCategory;

  /// Whether the current user is a moderator in this channel.
  bool isModerator = false;

  /// Whether the current user is the channel host/owner.
  bool isChannelHost = false;

  /// The Pusher socket ID (received on connection, needed for private channel auth).
  String? _pusherSocketId;

  /// Set of subscribed Pusher channel names (to prevent duplicate subscriptions).
  final _subscribedChannels = <String>{};

  /// The channel's display name to show on widgets.
  final String displayName;

  var _shouldDisconnect = false;

  /// The Pusher WebSocket channel.
  WebSocketChannel? _channel;

  /// The subscription that handles the WebSocket connection.
  StreamSubscription? _channelListener;

  /// 7TV WebSocket channel for emote updates.
  WebSocketChannel? _sevenTVChannel;

  /// The subscription that handles the 7TV WebSocket connection.
  StreamSubscription? _sevenTVChannelListener;

  static const _maxRetries = 5;

  // The retry counter for exponential backoff.
  var _retries = 0;

  // The current time to wait between retries for exponential backoff.
  var _backoffTime = 0;

  // Reference to the reconnect message for in-place updates.
  KickChatMessage? _reconnectMessage;

  // Timestamp when reconnection started.
  DateTime? _reconnectStartTime;

  /// The scroll controller that controls auto-scroll and resume-scroll behavior.
  final scrollController = ScrollController();

  /// The text controller that handles the TextField inputs.
  final textController = TextEditingController();

  /// The chat details store responsible for chat modes and users.
  final ChatDetailsStore chatDetailsStore;

  /// The assets store responsible for emotes and the emote menu.
  final ChatAssetsStore assetsStore;

  /// Requested message to be sent by the user.
  KickChatMessage? toSend;

  /// The list of reaction disposer functions.
  final reactions = <ReactionDisposer>[];

  /// The periodic timer used for batching chat message re-renders.
  Timer? _messageBufferTimer;

  /// The list of chat messages to add once autoscroll is resumed.
  final messageBuffer = ObservableList<KickChatMessage>();

  /// The set of message IDs that have been revealed by the user (for deleted messages).
  final revealedMessageIds = ObservableSet<String>();

  @action
  void revealMessage(String id) {
    revealedMessageIds.add(id);
  }

  /// Timer used for dismissing the notification.
  Timer? _notificationTimer;

  /// Timer used for resetting the sending state if no acknowledgment is received.
  Timer? _sendingTimeoutTimer;

  /// Timer used for updating the chat delay countdown message.
  Timer? _chatDelayCountdownTimer;

  /// Reference to the current countdown message.
  KickChatMessage? _countdownMessage;

  /// Tracks whether the initial chat delay sync has completed.
  bool _chatDelaySyncCompleted = false;

  /// The current timer for the sleep timer if active.
  Timer? sleepTimer;

  /// The time remaining for the sleep timer.
  @observable
  var timeRemaining = const Duration();

  /// A notification message to display above the chat.
  @readonly
  String? _notification;

  /// The list of chat messages to render and display.
  @readonly
  var _messages = ObservableList<KickChatMessage>();

  /// The list of chat messages that should be rendered.
  @computed
  List<KickChatMessage> get renderMessages {
    if (!_autoScroll || _messages.length < _renderMessageLimit) {
      return _messages;
    }
    return _messages.sublist(_messages.length - _renderMessageLimit);
  }

  /// If the chat should automatically scroll/jump to the latest message.
  @readonly
  var _autoScroll = true;

  @readonly
  var _inputText = '';

  @readonly
  var _showSendButton = false;

  @readonly
  var _showEmoteAutocomplete = false;

  @readonly
  var _showMentionAutocomplete = false;

  /// Whether we're waiting for server acknowledgment of a sent message.
  @readonly
  var _isWaitingForAck = false;

  /// Whether the chat WebSocket is currently connected.
  @readonly
  var _isConnected = false;

  /// Whether we've successfully connected at least once.
  @readonly
  var _hasConnected = false;

  @observable
  var expandChat = false;

  @observable
  KickChatMessage? replyingToMessage;

  /// The currently pinned message in the chat (if any).
  @observable
  KickPinnedMessageEvent? pinnedMessage;

  /// The currently active poll in the chat (if any).
  @observable
  KickPollUpdateEvent? activePoll;

  /// The currently active prediction in the channel (if any).
  @observable
  KickPredictionEvent? activePrediction;

  // ============================================================
  // LOCAL VOTE TRACKING (persists until event ends)
  // ============================================================

  /// Whether the user has voted on the current poll (local tracking).
  @observable
  bool hasVotedOnPoll = false;

  /// The option index the user voted for on the current poll.
  @observable
  int? pollVotedOptionIndex;

  /// Whether the user has bet on the current prediction (local tracking).
  @observable
  bool hasVotedOnPrediction = false;

  /// The outcome ID the user bet on for the current prediction.
  @observable
  String? predictionVotedOutcomeId;

  /// The amount the user bet on the current prediction.
  @observable
  int? predictionVoteAmount;

  // ============================================================
  // PANEL MINIMIZE STATES
  // ============================================================

  /// Whether the pinned message panel is minimized.
  @observable
  bool isPinnedMessageMinimized = false;

  /// Whether the poll panel is minimized.
  @observable
  bool isPollMinimized = false;

  /// Whether the prediction panel is minimized.
  @observable
  bool isPredictionMinimized = false;

  // ============================================================
  // CHATROOM STATE (modes & restrictions)
  // ============================================================

  /// The current chatroom state/settings fetched when joining chat.
  @observable
  KickChatroomState chatroomState = KickChatroomState.none;

  /// Whether the current user is following this channel.
  /// Used to enforce followers-only mode.
  @observable
  bool isFollowingChannel = false;

  /// Whether the current user is subscribed to this channel.
  /// Used to enforce subscribers-only mode.
  @observable
  bool isSubscribedToChannel = false;

  /// Timestamp when the last message was sent (for slow mode enforcement).
  @observable
  DateTime? lastMessageSentAt;

  /// Remaining seconds until next message can be sent (slow mode countdown).
  @observable
  int slowModeSecondsRemaining = 0;

  /// Timer for slow mode countdown.
  Timer? _slowModeTimer;

  /// Whether chat input is blocked due to chat restrictions.
  @computed
  bool get isChatBlocked {
    if (!auth.isLoggedIn) return true;
    if (isModerator || isChannelHost) return false;

    // Followers-only mode: must be following
    if (chatroomState.followersMode.enabled && !isFollowingChannel) {
      return true;
    }

    // Subscribers-only mode: must be subscribed
    if (chatroomState.subscribersMode.enabled && !isSubscribedToChannel) {
      return true;
    }

    return false;
  }

  /// Whether slow mode is currently enforced (countdown active).
  @computed
  bool get isSlowModeActive => slowModeSecondsRemaining > 0;

  /// Message explaining why chat is blocked, or null if not blocked.
  @computed
  String? get chatBlockedReason {
    if (!auth.isLoggedIn) return null;
    if (isModerator || isChannelHost) return null;

    if (chatroomState.followersMode.enabled && !isFollowingChannel) {
      final duration = chatroomState.followersMode.minDuration;
      if (duration > 0) {
        return 'Followers-only mode (${duration}m)';
      }
      return 'Followers-only mode';
    }

    if (chatroomState.subscribersMode.enabled && !isSubscribedToChannel) {
      return 'Subscribers-only mode';
    }

    return null;
  }

  /// Emotes matching the current autocomplete search term.
  @computed
  List<Emote> get matchingEmotes {
    if (!_showEmoteAutocomplete) return const [];
    final searchTerm = _inputText.split(' ').last.toLowerCase();
    if (searchTerm.isEmpty) return const [];

    return assetsStore.emotesList
        .where((emote) => emote.name.toLowerCase().contains(searchTerm))
        .toList();
  }

  /// Chatters matching the current mention autocomplete search term.
  @computed
  List<String> get matchingChatters {
    if (!_showMentionAutocomplete) return const [];
    final searchTerm = _inputText
        .split(' ')
        .last
        .replaceFirst('@', '')
        .toLowerCase();
    return chatDetailsStore.chatUsers
        .where((chatter) => chatter.contains(searchTerm))
        .toList();
  }

  /// Current bottom bar height based on visible overlays.
  @computed
  double get bottomBarHeight {
    var height = _baseBottomBarHeight;

    if (replyingToMessage != null) {
      height += _replyBarHeight;
    }

    if (settings.autocomplete &&
        ((_showEmoteAutocomplete && matchingEmotes.isNotEmpty) ||
            (_showMentionAutocomplete && matchingChatters.isNotEmpty))) {
      height += _autocompleteHeight;
    }

    return height;
  }

  ChatStoreBase({
    required this.kickApi,
    required this.auth,
    required this.chatDetailsStore,
    required this.assetsStore,
    required this.settings,
    required this.channelSlug,
    this.chatroomId,
    this.channelId,
    required this.displayName,
  }) {
    // Create a reaction that will reconnect to chat when logging in or out.
    reactions.add(
      reaction((_) => auth.isLoggedIn, (_) => _channel?.sink.close(1000)),
    );

    // Reaction for emote settings changes
    reactions.add(
      reaction((_) => [settings.showKickEmotes, settings.show7TVEmotes], (_) {
        if (!settings.show7TVEmotes) {
          _sevenTVChannel?.sink.close(1000);
        }
        getAssets();
      }),
    );

    // Start chat delay countdown when toggling video on
    reactions.add(
      reaction((_) => settings.showVideo, (showVideo) {
        if (showVideo && settings.chatDelay > 0) {
          _startChatDelayCountdown();
        } else if (!showVideo) {
          _cancelChatDelayCountdown();
          _chatDelaySyncCompleted = false;
        }
      }),
    );

    // Chat delay reaction
    reactions.add(
      reaction((_) => settings.chatDelay, (chatDelay) {
        if (chatDelay == 0) {
          _cancelChatDelayCountdown();
          _chatDelaySyncCompleted = false;
        } else if (settings.autoSyncChatDelay &&
            settings.showVideo &&
            chatDelay > 0 &&
            !_chatDelaySyncCompleted) {
          _startChatDelayCountdown();
        }
      }),
    );

    // Fetch assets
    assetsStore.fetchAssets(
      showKickEmotes: settings.showKickEmotes,
      show7TVEmotes: settings.show7TVEmotes,
    );

    _messages.add(
      KickChatMessage.createNotice(
        message: 'Connecting to chat...',
        chatroomId: chatroomId ?? 0,
      ),
    );

    connectToChat();

    // Auto-scroll setup
    scrollController.addListener(() {
      if (scrollController.position.pixels <= 0) {
        _autoScroll = true;
      } else if (scrollController.position.pixels > 0) {
        _autoScroll = false;
      }
    });

    // Emote menu toggle on focus
    textFieldFocusNode.addListener(() {
      if (textFieldFocusNode.hasFocus) {
        if (assetsStore.showEmoteMenu) assetsStore.showEmoteMenu = false;
      }
      if (!textFieldFocusNode.hasFocus) expandChat = false;
    });

    // Autocomplete setup
    textController.addListener(() {
      _inputText = textController.text;

      _showEmoteAutocomplete =
          !_showMentionAutocomplete &&
          textFieldFocusNode.hasFocus &&
          textController.text.split(' ').last.isNotEmpty;

      _showSendButton = textController.text.isNotEmpty;
      _showMentionAutocomplete =
          textFieldFocusNode.hasFocus &&
          textController.text.split(' ').last.startsWith('@');
    });
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Add a notice message to the message buffer.
  void _addNotice(String message, {String noticeType = 'system'}) {
    messageBuffer.add(
      KickChatMessage.createNotice(
        message: message,
        chatroomId: chatroomId ?? 0,
        noticeType: noticeType,
      ),
    );
  }

  /// Mark all messages from a user as deleted.
  void _markUserMessagesDeleted(String username) {
    for (final msg in _messages) {
      if (msg.sender.username == username) {
        msg.isDeleted = true;
      }
    }
    for (final msg in messageBuffer) {
      if (msg.sender.username == username) {
        msg.isDeleted = true;
      }
    }
  }

  /// Handle Pusher WebSocket events.
  @action
  void _handlePusherEvent(String rawData) {
    try {
      final json = jsonDecode(rawData) as Map<String, dynamic>;
      final event = KickPusherEvent.fromJson(json);

      switch (event.event) {
        case KickPusherEventTypes.connectionEstablished:
          // Parse socket_id from connection data for private channel auth
          if (event.parsedData != null) {
            _pusherSocketId = event.parsedData!['socket_id'] as String?;
            debugPrint('Pusher connected with socket_id: $_pusherSocketId');
          }
          _subscribeToAllChannels();
          break;

        case KickPusherEventTypes.subscriptionSucceeded:
          // Track which channel was subscribed
          final subscribedChannel = json['channel'] as String?;
          if (subscribedChannel != null) {
            _subscribedChannels.add(subscribedChannel);
            debugPrint('Subscribed to: $subscribedChannel');
          }
          // Only trigger _onConnected when primary chatroom is subscribed
          if (subscribedChannel == 'chatrooms.$chatroomId.v2') {
            _onConnected();
          }
          break;

        case KickPusherEventTypes.ping:
          _channel?.sink.add(jsonEncode({'event': 'pusher:pong', 'data': {}}));
          break;

        case KickPusherEventTypes.chatMessage:
        case KickPusherEventTypes.chatMessageSent:
          _handleChatMessage(event);
          break;

        case KickPusherEventTypes.messageDeleted:
        case KickPusherEventTypes.chatMessageDeleted:
          _handleMessageDeleted(event);
          break;

        case KickPusherEventTypes.userBanned:
          _handleUserBanned(event);
          break;

        case KickPusherEventTypes.userUnbanned:
          _handleUserUnbanned(event);
          break;

        case KickPusherEventTypes.chatroomUpdated:
          _handleChatroomUpdated(event);
          break;

        case KickPusherEventTypes.chatroomClear:
          _handleChatroomClear();
          break;

        // Pinned message events
        case KickPusherEventTypes.pinnedMessageCreated:
        case KickPusherEventTypes.messagePinned:
          _handlePinnedMessageCreated(event);
          break;

        case KickPusherEventTypes.pinnedMessageDeleted:
        case KickPusherEventTypes.messageUnpinned:
          _handlePinnedMessageDeleted();
          break;

        // Poll events
        case KickPusherEventTypes.pollUpdate:
        case KickPusherEventTypes.pollCreated:
          _handlePollUpdate(event);
          break;

        case KickPusherEventTypes.pollDelete:
        case KickPusherEventTypes.pollDeleted:
          _handlePollDeleted();
          break;

        // Prediction events
        case KickPusherEventTypes.predictionCreated:
        case KickPusherEventTypes.predictionUpdated:
          _handlePredictionUpdate(event);
          break;

        // Subscription events (show as notices)
        case KickPusherEventTypes.subscriptionEvent:
        case KickPusherEventTypes.subscriptionCreated:
        case KickPusherEventTypes.subscriptionRenewed:
          _handleSubscriptionEvent(event);
          break;

        case KickPusherEventTypes.giftedSubscription:
        case KickPusherEventTypes.subscriptionGifted:
          _handleGiftedSubscriptionEvent(event);
          break;

        // Follow events (show as notices)
        case KickPusherEventTypes.followerAdded:
          _handleFollowEvent(event, isFollowing: true);
          break;

        case KickPusherEventTypes.followerDeleted:
          _handleFollowEvent(event, isFollowing: false);
          break;

        // Raid events
        case KickPusherEventTypes.hostReceived:
          _handleRaidEvent(event);
          break;

        // Kicks gifted
        case KickPusherEventTypes.kicksGifted:
          _handleKicksGiftedEvent(event);
          break;

        // Reward redeemed
        case KickPusherEventTypes.redeemedReward:
          _handleRewardRedeemedEvent(event);
          break;

        case KickPusherEventTypes.error:
          debugPrint('Pusher error: ${event.data}');
          break;

        // Stream info updates
        case KickPusherEventTypes.titleChanged:
          _handleTitleChanged(event);
          break;

        case KickPusherEventTypes.categoryChanged:
          _handleCategoryChanged(event);
          break;

        case KickPusherEventTypes.livestreamUpdated:
          _handleLivestreamUpdated(event);
          break;

        default:
          debugPrint('Unhandled Pusher event: ${event.event}');
      }
    } catch (e) {
      debugPrint('Error handling Pusher event: $e');
    }
  }

  /// Subscribe to all relevant Pusher channels based on user role.
  ///
  /// Public channels (always subscribed):
  /// - chatroom_{chatroomId} - Chatroom events
  /// - chatrooms.{chatroomId} - Chatroom events (alternative format)
  /// - chatrooms.{chatroomId}.v2 - Chat messages (v2 format)
  /// - channel_{channelId} - Stream status, kicks gifted
  /// - channel.{channelId} - Stream status (alternative format)
  /// - predictions-channel-{channelId} - Predictions
  ///
  /// Private channels (only if moderator/host, requires auth):
  /// - private-chatroom_{chatroomId} - Mod events
  /// - private-channel_{channelId} - Follows, subs, rewards
  /// - private-livestream_{livestreamId} - Raids, title changes
  void _subscribeToAllChannels() {
    _subscribedChannels.clear();

    // Subscribe to all public chatroom channels
    _subscribeToPublicChannel('chatroom_$chatroomId');
    _subscribeToPublicChannel('chatrooms.$chatroomId');
    _subscribeToPublicChannel('chatrooms.$chatroomId.v2');

    if (channelId != null) {
      // Subscribe to all public channel variants
      _subscribeToPublicChannel('channel_$channelId');
      _subscribeToPublicChannel('channel.$channelId');
      _subscribeToPublicChannel('predictions-channel-$channelId');
    }

    // Subscribe to private channels if user has mod/host privileges
    if ((isModerator || isChannelHost) && auth.isLoggedIn) {
      _subscribeToPrivateChannel('private-chatroom_$chatroomId');
      if (channelId != null) {
        _subscribeToPrivateChannel('private-channel_$channelId');
      }
      if (livestreamId != null) {
        _subscribeToPrivateChannel('private-livestream_$livestreamId');
      }
    }
  }

  /// Subscribe to a public Pusher channel.
  void _subscribeToPublicChannel(String channelName) {
    final subscribePayload = jsonEncode({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName},
    });
    _channel?.sink.add(subscribePayload);
  }

  /// Subscribe to a private Pusher channel (requires authentication).
  Future<void> _subscribeToPrivateChannel(String channelName) async {
    if (_pusherSocketId == null) {
      debugPrint('Cannot subscribe to private channel: no socket_id');
      return;
    }

    try {
      final authToken = await kickApi.authenticatePusherChannel(
        socketId: _pusherSocketId!,
        channelName: channelName,
      );

      final subscribePayload = jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName, 'auth': authToken},
      });
      _channel?.sink.add(subscribePayload);
    } catch (e) {
      debugPrint('Failed to auth private channel $channelName: $e');
    }
  }

  /// Called when successfully connected and subscribed.
  @action
  void _onConnected() {
    // Activate the message buffer
    _messageBufferTimer?.cancel();
    _messageBufferTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (timer) => addMessages(),
    );

    messageBuffer.add(
      KickChatMessage.createNotice(
        message:
            "Welcome to ${getReadableName(displayName, channelSlug)}'s chat!",
        chatroomId: chatroomId ?? 0,
      ),
    );

    // Transform reconnect message to summary on successful connection
    if (_reconnectMessage != null && _reconnectStartTime != null) {
      final elapsed = DateTime.now().difference(_reconnectStartTime!).inSeconds;
      final attempts = _retries;
      final index = _messages.indexOf(_reconnectMessage!);
      if (index != -1) {
        _messages[index] = KickChatMessage.createNotice(
          message:
              'Reconnected ($attempts ${attempts == 1 ? 'attempt' : 'attempts'}, ${elapsed}s)',
          chatroomId: chatroomId ?? 0,
        );
      }
    }
    _reconnectMessage = null;
    _reconnectStartTime = null;

    // Reset exponential backoff
    _retries = 0;
    _backoffTime = 0;

    _isConnected = true;
    _hasConnected = true;
  }

  /// Handle incoming chat message.
  @action
  void _handleChatMessage(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final message = KickChatMessage.fromJson(data);

      // Add sender to chat users list
      chatDetailsStore.chatUsers.add(message.senderName);

      // Check for blocked users
      if (auth.user.blockedUsernames.contains(
        message.sender.username.toLowerCase(),
      )) {
        return;
      }

      // Check for muted words
      final List<String> mutedWords = settings.mutedWords;
      for (final word in mutedWords) {
        if (message.content
            .toLowerCase()
            .split(settings.matchWholeWord ? ' ' : '')
            .contains(word.toLowerCase())) {
          return;
        }
      }

      messageBuffer.add(message);

      // Handle our own sent message confirmation
      if (toSend != null &&
          message.sender.username == auth.user.details?.username) {
        _sendingTimeoutTimer?.cancel();
        _isWaitingForAck = false;
        textController.clear();
        replyingToMessage = null;
        toSend = null;
      }

      // Maintain message limit
      if (!_autoScroll && messageBuffer.length >= _messagesToRemove) {
        _messages.addAll(messageBuffer);
        messageBuffer.clear();
      }

      if (_messages.length >= _messageLimit) {
        _messages = _messages.sublist(_messagesToRemove).asObservable();
      }
    } catch (e) {
      debugPrint('Error parsing chat message: $e');
    }
  }

  /// Handle message deleted event.
  @action
  void _handleMessageDeleted(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final deletedEvent = KickMessageDeletedEvent.fromJson(data);
      final messageId = deletedEvent.message.id;

      // Mark message as deleted in both lists
      for (final msg in _messages) {
        if (msg.id == messageId) {
          msg.isDeleted = true;
          break;
        }
      }
      for (final msg in messageBuffer) {
        if (msg.id == messageId) {
          msg.isDeleted = true;
          break;
        }
      }
    } catch (e) {
      debugPrint('Error handling message deleted: $e');
    }
  }

  /// Handle user banned event.
  @action
  void _handleUserBanned(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final bannedEvent = KickUserBannedEvent.fromJson(data);
      final username = bannedEvent.user.username;

      // Mark all messages from banned user as deleted
      _markUserMessagesDeleted(username);

      // Show notification
      final durationText = switch ((
        bannedEvent.permanent,
        bannedEvent.duration,
      )) {
        (true, _) => 'permanently banned',
        (false, final int duration) => 'timed out for ${duration}s',
        _ => 'banned',
      };
      _addNotice('$username has been $durationText');
    } catch (e) {
      debugPrint('Error handling user banned: $e');
    }
  }

  /// Handle user unbanned event.
  @action
  void _handleUserUnbanned(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final unbannedEvent = KickUserUnbannedEvent.fromJson(data);
      _addNotice('${unbannedEvent.user.username} has been unbanned');
    } catch (e) {
      debugPrint('Error handling user unbanned: $e');
    }
  }

  /// Handle chatroom updated event (slow mode, etc).
  @action
  void _handleChatroomUpdated(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final updatedEvent = KickChatroomUpdatedEvent.fromJson(data);
      chatDetailsStore.updateFromChatroomEvent(updatedEvent);
    } catch (e) {
      debugPrint('Error handling chatroom updated: $e');
    }
  }

  /// Handle chatroom clear event.
  @action
  void _handleChatroomClear() {
    _messages.clear();
    messageBuffer.clear();
    _addNotice('Chat has been cleared by a moderator');
  }

  // ============================================================
  // NEW EVENT HANDLERS (Pinned, Poll, Prediction, Notices)
  // ============================================================

  /// Handle pinned message created event.
  @action
  void _handlePinnedMessageCreated(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      pinnedMessage = KickPinnedMessageEvent.fromJson(data);
      debugPrint('Message pinned: ${pinnedMessage?.message.content}');
    } catch (e) {
      debugPrint('Error handling pinned message: $e');
    }
  }

  /// Handle pinned message deleted event.
  @action
  void _handlePinnedMessageDeleted() {
    pinnedMessage = null;
    isPinnedMessageMinimized = false;
    debugPrint('Pinned message removed');
  }

  /// Handle poll update event.
  @action
  void _handlePollUpdate(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final newPoll = KickPollUpdateEvent.fromJson(data);
      // Reset vote tracking if it's a new poll (compare by title since no id)
      if (activePoll == null || activePoll!.poll.title != newPoll.poll.title) {
        hasVotedOnPoll = false;
        pollVotedOptionIndex = null;
        isPollMinimized = false;
      }
      activePoll = newPoll;
      debugPrint('Poll updated: ${activePoll?.poll.title}');
    } catch (e) {
      debugPrint('Error handling poll update: $e');
    }
  }

  /// Handle poll deleted event.
  @action
  void _handlePollDeleted() {
    activePoll = null;
    hasVotedOnPoll = false;
    pollVotedOptionIndex = null;
    isPollMinimized = false;
    debugPrint('Poll ended/deleted');
  }

  /// Handle prediction created/updated event.
  @action
  void _handlePredictionUpdate(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final newPrediction = KickPredictionEvent.fromJson(data);
      // Reset vote tracking if it's a new prediction
      if (activePrediction == null ||
          activePrediction!.id != newPrediction.id) {
        hasVotedOnPrediction = false;
        predictionVotedOutcomeId = null;
        predictionVoteAmount = null;
        isPredictionMinimized = false;
      }
      activePrediction = newPrediction;
      debugPrint(
        'Prediction updated: ${activePrediction?.title} (${activePrediction?.state})',
      );

      // Clear prediction if it's resolved or cancelled
      if (activePrediction?.isResolved == true ||
          activePrediction?.isCancelled == true) {
        // Keep it visible briefly, then clear
        Future.delayed(const Duration(seconds: 10), () {
          if (activePrediction?.id == newPrediction.id) {
            activePrediction = null;
            hasVotedOnPrediction = false;
            predictionVotedOutcomeId = null;
            predictionVoteAmount = null;
            isPredictionMinimized = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error handling prediction update: $e');
    }
  }

  // ============================================================
  // STREAM INFO UPDATE HANDLERS
  // ============================================================

  /// Handle stream title changed event.
  @action
  void _handleTitleChanged(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      // TitleChanged event: { "title": "New Stream Title" }
      final newTitle = data['title'] as String?;
      if (newTitle != null) {
        streamTitle = newTitle;
        debugPrint('Stream title changed: $newTitle');
      }
    } catch (e) {
      debugPrint('Error handling title changed: $e');
    }
  }

  /// Handle stream category changed event.
  @action
  void _handleCategoryChanged(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      // CategoryChanged event: { "category": { "name": "...", ... } }
      final category = data['category'] as Map<String, dynamic>?;
      final categoryName = category?['name'] as String?;
      if (categoryName != null) {
        streamCategory = categoryName;
        debugPrint('Stream category changed: $categoryName');
      }
    } catch (e) {
      debugPrint('Error handling category changed: $e');
    }
  }

  /// Handle livestream updated event (may include title, category, etc).
  @action
  void _handleLivestreamUpdated(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      // LivestreamUpdated event may contain session_title and category
      final title =
          data['session_title'] as String? ?? data['title'] as String?;
      if (title != null) {
        streamTitle = title;
        debugPrint('Livestream title updated: $title');
      }

      final category = data['category'] as Map<String, dynamic>?;
      final categoryName = category?['name'] as String?;
      if (categoryName != null) {
        streamCategory = categoryName;
        debugPrint('Livestream category updated: $categoryName');
      }
    } catch (e) {
      debugPrint('Error handling livestream updated: $e');
    }
  }

  // ============================================================
  // VOTE ACTION METHODS
  // ============================================================

  /// Vote on the active poll.
  @action
  Future<void> voteOnPoll(int optionIndex) async {
    if (hasVotedOnPoll || activePoll == null) return;
    try {
      await kickApi.voteOnPoll(
        channelSlug: channelSlug,
        optionIndex: optionIndex,
      );
      hasVotedOnPoll = true;
      pollVotedOptionIndex = optionIndex;
    } catch (e) {
      debugPrint('Error voting on poll: $e');
      updateNotification('Failed to vote on poll');
    }
  }

  /// Bet on a prediction outcome.
  @action
  Future<void> betOnPrediction(String outcomeId, int amount) async {
    if (hasVotedOnPrediction || activePrediction == null) return;
    try {
      await kickApi.voteOnPrediction(
        channelSlug: channelSlug,
        outcomeId: outcomeId,
        amount: amount,
      );
      hasVotedOnPrediction = true;
      predictionVotedOutcomeId = outcomeId;
      predictionVoteAmount = amount;
    } catch (e) {
      debugPrint('Error betting on prediction: $e');
      updateNotification('Failed to place bet');
    }
  }

  /// Handle subscription event - show as chat notice.
  @action
  void _handleSubscriptionEvent(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final subEvent = KickSubscriptionEvent.fromJson(data);
      final username = subEvent.user?.username ?? subEvent.username;
      final months = subEvent.months;

      final message = months > 1
          ? '$username resubscribed for $months months!'
          : '$username subscribed!';
      _addNotice(message, noticeType: 'subscription');
    } catch (e) {
      debugPrint('Error handling subscription event: $e');
    }
  }

  /// Handle gifted subscription event - show as chat notice.
  @action
  void _handleGiftedSubscriptionEvent(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final giftEvent = KickGiftedSubscriptionEvent.fromJson(data);
      final gifter = giftEvent.gifter?.username ?? 'Anonymous';
      final count = giftEvent.giftCount;

      final message = count > 1
          ? '$gifter gifted $count subscriptions!'
          : '$gifter gifted a subscription!';
      _addNotice(message, noticeType: 'gift');
    } catch (e) {
      debugPrint('Error handling gifted subscription event: $e');
    }
  }

  /// Handle follow event - show as chat notice.
  @action
  void _handleFollowEvent(KickPusherEvent event, {required bool isFollowing}) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final followEvent = KickChannelFollowEvent.fromJson(data);
      final username = followEvent.user?.username ?? 'Someone';

      if (isFollowing) {
        _addNotice('$username followed!', noticeType: 'follow');
      }
    } catch (e) {
      debugPrint('Error handling follow event: $e');
    }
  }

  /// Handle raid event - show as chat notice.
  @action
  void _handleRaidEvent(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final raidEvent = KickRaidEvent.fromJson(data);
      final raider = raidEvent.host.user?.username ?? 'Someone';
      final viewers = raidEvent.host.viewersCount;
      _addNotice('$raider raided with $viewers viewers!', noticeType: 'raid');
    } catch (e) {
      debugPrint('Error handling raid event: $e');
    }
  }

  /// Handle kicks gifted event - show as chat notice.
  @action
  void _handleKicksGiftedEvent(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final kicksEvent = KickKicksGiftedEvent.fromJson(data);
      final sender = kicksEvent.sender?.username ?? 'Someone';
      final amount = kicksEvent.gift?.amount ?? 0;
      final giftName = kicksEvent.gift?.name ?? 'Kicks';
      _addNotice('$sender sent $amount $giftName!', noticeType: 'kicks');
    } catch (e) {
      debugPrint('Error handling kicks gifted event: $e');
    }
  }

  /// Handle reward redeemed event - show as chat notice.
  @action
  void _handleRewardRedeemedEvent(KickPusherEvent event) {
    final data = event.parsedData;
    if (data == null) return;

    try {
      final rewardEvent = KickRewardRedeemedEvent.fromJson(data);
      final username = rewardEvent.user?.username ?? 'Someone';
      final rewardTitle = rewardEvent.reward.title;
      final userInput = rewardEvent.reward.userInput;

      final message = (userInput != null && userInput.isNotEmpty)
          ? '$username redeemed "$rewardTitle": $userInput'
          : '$username redeemed "$rewardTitle"';
      _addNotice(message, noticeType: 'reward');
    } catch (e) {
      debugPrint('Error handling reward redeemed event: $e');
    }
  }

  // Fetch the assets used in chat including emotes.
  @action
  Future<void> getAssets() async {
    await assetsStore.fetchAssets(
      showKickEmotes: settings.showKickEmotes,
      show7TVEmotes: settings.show7TVEmotes,
    );
  }

  /// Re-enables [_autoScroll] and jumps to the latest message.
  @action
  void resumeScroll() {
    _autoScroll = true;
    scrollController.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollController.jumpTo(0);
    });
  }

  @action
  Future<void> connectToChat({bool isReconnect = false}) async {
    // Ensure chatroomId is available
    if (chatroomId == null || channelId == null) {
      try {
        final channel = await kickApi.getChannel(channelSlug: channelSlug);
        chatroomId = channel.chatroom.id;
        channelId = channel.id;

        // Check if current user is the channel host
        final currentUsername = auth.user.details?.username.toLowerCase();
        if (currentUsername != null &&
            currentUsername == channel.slug.toLowerCase()) {
          isChannelHost = true;
        }
      } catch (e) {
        debugPrint('Failed to get chatroom ID: $e');
        _messages.add(
          KickChatMessage.createNotice(message: 'Failed to load chat info.'),
        );
        return;
      }
    }

    // Check moderator status and follow/subscribe status from /me endpoint
    if (auth.isLoggedIn && !isChannelHost) {
      try {
        final meResponse = await kickApi.getChannelMe(channelSlug: channelSlug);
        if (meResponse != null) {
          isModerator = meResponse.isModerator;
          isFollowingChannel = meResponse.isFollowing;
          isSubscribedToChannel = meResponse.isSubscribed;
        }
      } catch (e) {
        debugPrint('Failed to check moderator status: $e');
      }
    }

    // Fetch chatroom state (modes & restrictions)
    if (!isReconnect) {
      try {
        chatroomState = await kickApi.getChatroomState(channelSlug: channelSlug);
        debugPrint('Chatroom state: slow=${chatroomState.slowMode.enabled}, '
            'followers=${chatroomState.followersMode.enabled}, '
            'subscribers=${chatroomState.subscribersMode.enabled}');
      } catch (e) {
        debugPrint('Failed to fetch chatroom state: $e');
      }
    }

    // Fetch chat history if enabled (only on initial connect)
    if (!isReconnect && settings.showRecentMessages) {
      try {
        final historyJson = await kickApi.getChatHistory(channelId: channelId!);
        final historyMessages = historyJson
            .map((json) {
              final msg = KickChatMessage.fromJson(
                json as Map<String, dynamic>,
              );
              msg.isHistorical = true;
              return msg;
            })
            .toList()
            .reversed // API returns newest first, we want oldest first
            .toList();

        if (historyMessages.isNotEmpty) {
          // Insert history at the beginning (before "Connecting..." message)
          _messages.insertAll(0, historyMessages);
        }
      } catch (e) {
        debugPrint('Failed to load chat history: $e');
      }
    }

    // Cancel existing listener
    _channelListener?.cancel();

    _channel?.sink.close(1000);
    _channel = WebSocketChannel.connect(Uri.parse(kickPusherWsUrl));

    // Only show chat delay countdown on initial connection
    if (!isReconnect && settings.showVideo && settings.chatDelay > 0) {
      _startChatDelayCountdown();
    }

    // Track the current connection to prevent stale delayed callbacks
    final connectionId = DateTime.now().millisecondsSinceEpoch;
    var currentConnectionId = connectionId;

    // Listen for Pusher events
    _channelListener = _channel?.stream.listen(
      (data) {
        final dataStr = data.toString();

        // Apply chat delay if enabled
        if (!settings.showVideo || settings.chatDelay == 0) {
          _handlePusherEvent(dataStr);
        } else {
          final capturedConnectionId = currentConnectionId;
          Future.delayed(Duration(seconds: settings.chatDelay.toInt()), () {
            if (capturedConnectionId == currentConnectionId) {
              _handlePusherEvent(dataStr);
            }
          });
        }
      },
      onError: (error) => debugPrint('Chat error: ${error.toString()}'),
      onDone: () async {
        currentConnectionId = 0;
        _isConnected = false;
        _cancelChatDelayCountdown();
        _chatDelaySyncCompleted = false;

        if (_shouldDisconnect) {
          _sevenTVChannel?.sink.close(1000);
          return;
        }

        if (_retries >= _maxRetries) {
          if (_reconnectMessage != null) {
            final index = _messages.indexOf(_reconnectMessage!);
            if (index != -1) _messages.removeAt(index);
            _reconnectMessage = null;
          }
          _reconnectStartTime = null;

          _messages.add(
            KickChatMessage.createNotice(
              message: 'Chat disconnected. Please check your connection.',
              chatroomId: chatroomId ?? 0,
            ),
          );
          return;
        }

        _retries++;

        if (_retries > 1) {
          final newBackoff = _backoffTime == 0 ? 1 : _backoffTime * 2;
          _backoffTime = newBackoff > 8 ? 8 : newBackoff;
        }

        void updateReconnectMessage(String text) {
          final msg = KickChatMessage.createNotice(
            message: text,
            chatroomId: chatroomId ?? 0,
          );
          if (_reconnectMessage == null) {
            _reconnectStartTime ??= DateTime.now();
            _reconnectMessage = msg;
            _messages.add(_reconnectMessage!);
          } else {
            final index = _messages.indexOf(_reconnectMessage!);
            if (index != -1) {
              _reconnectMessage = msg;
              _messages[index] = _reconnectMessage!;
            } else {
              _reconnectMessage = msg;
              _messages.add(_reconnectMessage!);
            }
          }
        }

        if (_backoffTime > 0) {
          var remainingSeconds = _backoffTime;
          updateReconnectMessage(
            'Reconnecting in ${remainingSeconds}s... (attempt $_retries of $_maxRetries)',
          );

          await Future.doWhile(() async {
            await Future.delayed(const Duration(seconds: 1));

            if (_shouldDisconnect) {
              if (_reconnectMessage != null) {
                final index = _messages.indexOf(_reconnectMessage!);
                if (index != -1) _messages.removeAt(index);
                _reconnectMessage = null;
              }
              _reconnectStartTime = null;
              return false;
            }

            remainingSeconds--;

            if (remainingSeconds > 0) {
              updateReconnectMessage(
                'Reconnecting in ${remainingSeconds}s... (attempt $_retries of $_maxRetries)',
              );
              return true;
            }
            return false;
          });

          if (_shouldDisconnect) return;
        }

        updateReconnectMessage(
          'Reconnecting... (attempt $_retries of $_maxRetries)',
        );

        _channelListener?.cancel();
        connectToChat(isReconnect: true);
      },
    );
  }

  @action
  void addMessages() {
    if (!_autoScroll || messageBuffer.isEmpty) return;

    _messages.addAll(messageBuffer);
    messageBuffer.clear();
  }

  /// Cancels the chat delay countdown.
  @action
  void _cancelChatDelayCountdown() {
    _chatDelayCountdownTimer?.cancel();
    _chatDelayCountdownTimer = null;

    if (_countdownMessage != null) {
      final index = _messages.indexOf(_countdownMessage!);
      if (index != -1) _messages.removeAt(index);
      _countdownMessage = null;
    }
  }

  /// Starts the chat delay countdown.
  @action
  void _startChatDelayCountdown() {
    if (_chatDelaySyncCompleted) return;

    _cancelChatDelayCountdown();

    var remainingSeconds = settings.chatDelay.toInt();
    if (remainingSeconds <= 0) return;

    _countdownMessage = KickChatMessage.createNotice(
      message: 'Chat syncing in ${remainingSeconds}s...',
      chatroomId: chatroomId ?? 0,
    );
    _messages.add(_countdownMessage!);

    _chatDelayCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      remainingSeconds--;

      if (remainingSeconds <= 0) {
        timer.cancel();
        _chatDelaySyncCompleted = true;

        if (_countdownMessage != null) {
          final index = _messages.indexOf(_countdownMessage!);
          if (index != -1) {
            _messages[index] = KickChatMessage.createNotice(
              message: 'Chat synced!',
              chatroomId: chatroomId ?? 0,
            );
          }
          _countdownMessage = null;
        }
        return;
      }

      if (_countdownMessage != null) {
        final index = _messages.indexOf(_countdownMessage!);
        if (index != -1) {
          final updated = KickChatMessage.createNotice(
            message: 'Chat syncing in ${remainingSeconds}s...',
            chatroomId: chatroomId ?? 0,
          );
          _countdownMessage = updated;
          _messages[index] = updated;
        }
      }
    });
  }

  /// Starts the slow mode countdown after sending a message.
  @action
  void _startSlowModeCountdown() {
    _slowModeTimer?.cancel();
    slowModeSecondsRemaining = chatroomState.slowMode.messageInterval;
    lastMessageSentAt = DateTime.now();

    _slowModeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      slowModeSecondsRemaining--;
      if (slowModeSecondsRemaining <= 0) {
        slowModeSecondsRemaining = 0;
        timer.cancel();
      }
    });
  }

  /// Sends a chat message.
  @action
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    if (!auth.isLoggedIn) {
      updateNotification('You must be logged in to chat.');
      return;
    }

    // Check if chat is blocked due to restrictions
    if (isChatBlocked) {
      final reason = chatBlockedReason;
      if (reason != null) {
        updateNotification(reason);
      }
      return;
    }

    // Check slow mode (unless moderator/host)
    if (!isModerator && !isChannelHost && isSlowModeActive) {
      updateNotification('Slow mode: wait ${slowModeSecondsRemaining}s');
      return;
    }

    _isWaitingForAck = true;

    // Process message to format Kick emotes
    var contentToSend = message.trim();
    final words = contentToSend.split(' ');
    final parsedWords = <String>[];

    for (final word in words) {
      final emote = assetsStore.emotes[word];
      // If it's a Kick emote, ensure we send it in the format [emote:id:name]
      if (emote != null && assetsStore.isKick(emote) && emote.id != null) {
        parsedWords.add('[emote:${emote.id}:${emote.name}]');
      } else {
        parsedWords.add(word);
      }
    }
    contentToSend = parsedWords.join(' ');

    try {
      var success = false;
      // Send message via Kick API
      if (chatroomId != null) {
        // Build reply data if replying to a message
        KickReplyData? replyData;
        if (replyingToMessage != null) {
          replyData = KickReplyData(
            messageId: replyingToMessage!.id,
            messageContent: replyingToMessage!.content,
            senderId: replyingToMessage!.sender.id,
            senderUsername: replyingToMessage!.sender.username,
          );
        }

        success = await kickApi.sendChatMessage(
          chatroomId: chatroomId!,
          content: contentToSend,
          replyTo: replyData,
        );
      }

      // Create optimistic message to display
      toSend = KickChatMessage(
        id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        chatroomId: chatroomId ?? 0,
        content: contentToSend,
        type: 'message',
        createdAt: DateTime.now(),
        sender: KickMessageSender(
          id: auth.user.details?.id ?? 0,
          username: auth.user.details?.username ?? '',
          slug: auth.user.details?.slug ?? '',
        ),
      );

      // If the request was successful (200 OK), we assume the message was sent.
      // We clear the input immediately and don't wait for the Pusher event to confirm.
      if (success) {
        _isWaitingForAck = false;
        textController.clear();
        replyingToMessage = null;

        // Start slow mode countdown if enabled (and not mod/host)
        if (!isModerator &&
            !isChannelHost &&
            chatroomState.slowMode.enabled &&
            chatroomState.slowMode.messageInterval > 0) {
          _startSlowModeCountdown();
        }
      }

      // Start timeout timer
      _sendingTimeoutTimer?.cancel();
      _sendingTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (_shouldDisconnect) return;

        if (_isWaitingForAck) {
          _isWaitingForAck = false;
          toSend = null;
          updateNotification(
            'Message may not have been sent. Please try again.',
          );
        }
      });
    } catch (e) {
      _isWaitingForAck = false;
      updateNotification('Failed to send message: $e');
    }
  }

  /// Adds the given [emote] to the chat textfield.
  @action
  void addEmote(Emote emote, {bool autocompleteMode = false}) {
    if (textController.text.isEmpty || textController.text.endsWith(' ')) {
      textController.text += '${emote.name} ';
    } else if (autocompleteMode &&
        _showEmoteAutocomplete &&
        textController.text.endsWith('')) {
      final split = textController.text.split(' ')
        ..removeLast()
        ..add('${emote.name} ');

      textController.text = split.join(' ');
    } else {
      textController.text += ' ${emote.name} ';
    }

    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: textController.text.length),
    );
  }

  /// Updates the notification message.
  @action
  void updateNotification(String notificationMessage) {
    _notificationTimer?.cancel();
    HapticFeedback.lightImpact();
    _notification = notificationMessage;
    _notificationTimer = Timer(
      const Duration(seconds: 5),
      () => _notification = null,
    );
  }

  /// Clears the current notification immediately.
  @action
  void clearNotification() {
    _notificationTimer?.cancel();
    _notification = null;
  }

  /// Updates the sleep timer.
  @action
  void updateSleepTimer({
    required Duration duration,
    required VoidCallback onTimerFinished,
  }) {
    if (sleepTimer != null) cancelSleepTimer();

    timeRemaining = duration;

    sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeRemaining.inSeconds == 0) {
        timer.cancel();
        onTimerFinished();
        return;
      }

      timeRemaining = Duration(seconds: timeRemaining.inSeconds - 1);
    });
  }

  /// Cancels the sleep timer.
  @action
  void cancelSleepTimer() {
    sleepTimer?.cancel();
    timeRemaining = const Duration();
  }

  /// Closes and disposes all the channels and controllers used by the store.
  void dispose() {
    _shouldDisconnect = true;

    _messageBufferTimer?.cancel();
    _notificationTimer?.cancel();
    _sendingTimeoutTimer?.cancel();
    _cancelChatDelayCountdown();
    _slowModeTimer?.cancel();
    sleepTimer?.cancel();

    _channelListener?.cancel();
    _sevenTVChannelListener?.cancel();

    _channel?.sink.close(1000);
    _sevenTVChannel?.sink.close(1000);

    for (final reactionDisposer in reactions) {
      reactionDisposer();
    }

    textFieldFocusNode.dispose();
    textController.dispose();
    scrollController.dispose();

    assetsStore.dispose();
    chatDetailsStore.dispose();
  }

  /// Unfocuses the text field.
  @action
  void unfocusInput() {
    textFieldFocusNode.unfocus();
  }

  /// Requests focus for the text field.
  @action
  void safeRequestFocus() {
    textFieldFocusNode.requestFocus();
  }
}
