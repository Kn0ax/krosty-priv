import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/constants.dart';
import 'package:krosty/models/emotes.dart';
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

  /// Handle Pusher WebSocket events.
  @action
  void _handlePusherEvent(String rawData) {
    try {
      final json = jsonDecode(rawData) as Map<String, dynamic>;
      final event = KickPusherEvent.fromJson(json);

      switch (event.event) {
        case KickPusherEventTypes.connectionEstablished:
          debugPrint('Pusher connected');
          _subscribeToChatroom();
          break;

        case KickPusherEventTypes.subscriptionSucceeded:
          debugPrint('Subscribed to chatroom $chatroomId');
          _onConnected();
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

        case KickPusherEventTypes.error:
          debugPrint('Pusher error: ${event.data}');
          break;

        default:
          debugPrint('Unhandled Pusher event: ${event.event}');
      }
    } catch (e) {
      debugPrint('Error handling Pusher event: $e');
    }
  }

  /// Subscribe to the chatroom channel.
  void _subscribeToChatroom() {
    final subscribePayload = jsonEncode({
      'event': 'pusher:subscribe',
      'data': {'channel': 'chatrooms.$chatroomId.v2'},
    });
    _channel?.sink.add(subscribePayload);
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
      final duration = bannedEvent.duration;
      final permanent = bannedEvent.permanent;

      // Mark all messages from banned user as deleted
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

      // Show notification
      final durationText = permanent
          ? 'permanently banned'
          : duration != null
          ? 'timed out for ${duration}s'
          : 'banned';
      messageBuffer.add(
        KickChatMessage.createNotice(
          message: '$username has been $durationText',
          chatroomId: chatroomId ?? 0,
        ),
      );
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
      messageBuffer.add(
        KickChatMessage.createNotice(
          message: '${unbannedEvent.user.username} has been unbanned',
          chatroomId: chatroomId ?? 0,
        ),
      );
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
    _messages.add(
      KickChatMessage.createNotice(
        message: 'Chat has been cleared by a moderator',
        chatroomId: chatroomId ?? 0,
      ),
    );
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
      } catch (e) {
        debugPrint('Failed to get chatroom ID: $e');
        _messages.add(
          KickChatMessage.createNotice(
            message: 'Failed to load chat info.',
            chatroomId: 0,
          ),
        );
        return;
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

  /// Sends a chat message.
  @action
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    if (!auth.isLoggedIn) {
      updateNotification('You must be logged in to chat.');
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
        success = await kickApi.sendChatMessage(
          chatroomId: chatroomId!,
          content: contentToSend,
          replyToMessageId: replyingToMessage?.id,
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
