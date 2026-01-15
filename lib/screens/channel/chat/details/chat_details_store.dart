import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_message.dart';
import 'package:mobx/mobx.dart';

part 'chat_details_store.g.dart';

class ChatDetailsStore = ChatDetailsStoreBase with _$ChatDetailsStore;

/// Kick chatroom state (slow mode, followers only, etc).
class KickRoomState {
  final bool slowMode;
  final bool subscribersMode;
  final bool followersMode;
  final bool emotesMode;
  final int messageInterval;
  final int followingMinDuration;

  const KickRoomState({
    this.slowMode = false,
    this.subscribersMode = false,
    this.followersMode = false,
    this.emotesMode = false,
    this.messageInterval = 0,
    this.followingMinDuration = 0,
  });

  KickRoomState copyWith({
    bool? slowMode,
    bool? subscribersMode,
    bool? followersMode,
    bool? emotesMode,
    int? messageInterval,
    int? followingMinDuration,
  }) {
    return KickRoomState(
      slowMode: slowMode ?? this.slowMode,
      subscribersMode: subscribersMode ?? this.subscribersMode,
      followersMode: followersMode ?? this.followersMode,
      emotesMode: emotesMode ?? this.emotesMode,
      messageInterval: messageInterval ?? this.messageInterval,
      followingMinDuration: followingMinDuration ?? this.followingMinDuration,
    );
  }
}

abstract class ChatDetailsStoreBase with Store {
  final KickApi kickApi;

  final String channelSlug;

  /// The scroll controller for handling the scroll to top button.
  final scrollController = ScrollController();

  /// The text controller for handling filtering the chatters.
  final textController = TextEditingController();

  /// The focus node for the textfield used for handling hiding/showing the cancel button.
  final textFieldFocusNode = FocusNode();

  /// The rules and modes being used in the chat.
  @observable
  var roomState = const KickRoomState();

  @observable
  var showJumpButton = false;

  /// The current text being used to filter the chatters.
  /// Changing this will automatically update [filteredUsers].
  @readonly
  var _filterText = '';

  /// The list and types of chatters in the chat room.
  /// Limited to prevent unbounded memory growth during long sessions.
  static const _maxChatUsers = 1000;
  final chatUsers = SplayTreeSet<String>();

  /// Add a user to the chat users set with capacity management.
  void addChatUser(String username) {
    if (chatUsers.length >= _maxChatUsers && !chatUsers.contains(username)) {
      // Remove oldest entry (first in sorted order)
      chatUsers.remove(chatUsers.first);
    }
    chatUsers.add(username);
  }

  @computed
  Iterable<String> get filteredUsers =>
      chatUsers.where((user) => user.contains(_filterText));

  ChatDetailsStoreBase({required this.kickApi, required this.channelSlug}) {
    scrollController.addListener(() {
      if (scrollController.position.atEdge ||
          scrollController.position.outOfRange) {
        showJumpButton = false;
      } else {
        showJumpButton = true;
      }
    });

    textController.addListener(() => _filterText = textController.text);
  }

  /// Update room state from a chatroom updated event.
  @action
  void updateFromChatroomEvent(KickChatroomUpdatedEvent event) {
    roomState = roomState.copyWith(
      slowMode: event.slowMode,
      subscribersMode: event.subscribersMode,
      followersMode: event.followersMode,
      emotesMode: event.emotesMode,
      messageInterval: event.messageInterval,
      followingMinDuration: event.followingMinDuration,
    );
  }

  void dispose() {
    scrollController.dispose();
    textController.dispose();
    textFieldFocusNode.dispose();
    chatUsers.clear();
  }
}
