// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ChatStore on ChatStoreBase, Store {
  Computed<List<KickChatMessage>>? _$renderMessagesComputed;

  @override
  List<KickChatMessage> get renderMessages =>
      (_$renderMessagesComputed ??= Computed<List<KickChatMessage>>(
        () => super.renderMessages,
        name: 'ChatStoreBase.renderMessages',
      )).value;
  Computed<List<Emote>>? _$matchingEmotesComputed;

  @override
  List<Emote> get matchingEmotes =>
      (_$matchingEmotesComputed ??= Computed<List<Emote>>(
        () => super.matchingEmotes,
        name: 'ChatStoreBase.matchingEmotes',
      )).value;
  Computed<List<String>>? _$matchingChattersComputed;

  @override
  List<String> get matchingChatters =>
      (_$matchingChattersComputed ??= Computed<List<String>>(
        () => super.matchingChatters,
        name: 'ChatStoreBase.matchingChatters',
      )).value;
  Computed<double>? _$bottomBarHeightComputed;

  @override
  double get bottomBarHeight => (_$bottomBarHeightComputed ??= Computed<double>(
    () => super.bottomBarHeight,
    name: 'ChatStoreBase.bottomBarHeight',
  )).value;

  late final _$streamTitleAtom = Atom(
    name: 'ChatStoreBase.streamTitle',
    context: context,
  );

  @override
  String? get streamTitle {
    _$streamTitleAtom.reportRead();
    return super.streamTitle;
  }

  @override
  set streamTitle(String? value) {
    _$streamTitleAtom.reportWrite(value, super.streamTitle, () {
      super.streamTitle = value;
    });
  }

  late final _$streamCategoryAtom = Atom(
    name: 'ChatStoreBase.streamCategory',
    context: context,
  );

  @override
  String? get streamCategory {
    _$streamCategoryAtom.reportRead();
    return super.streamCategory;
  }

  @override
  set streamCategory(String? value) {
    _$streamCategoryAtom.reportWrite(value, super.streamCategory, () {
      super.streamCategory = value;
    });
  }

  late final _$timeRemainingAtom = Atom(
    name: 'ChatStoreBase.timeRemaining',
    context: context,
  );

  @override
  Duration get timeRemaining {
    _$timeRemainingAtom.reportRead();
    return super.timeRemaining;
  }

  @override
  set timeRemaining(Duration value) {
    _$timeRemainingAtom.reportWrite(value, super.timeRemaining, () {
      super.timeRemaining = value;
    });
  }

  late final _$_notificationAtom = Atom(
    name: 'ChatStoreBase._notification',
    context: context,
  );

  String? get notification {
    _$_notificationAtom.reportRead();
    return super._notification;
  }

  @override
  String? get _notification => notification;

  @override
  set _notification(String? value) {
    _$_notificationAtom.reportWrite(value, super._notification, () {
      super._notification = value;
    });
  }

  late final _$_messagesAtom = Atom(
    name: 'ChatStoreBase._messages',
    context: context,
  );

  ObservableList<KickChatMessage> get messages {
    _$_messagesAtom.reportRead();
    return super._messages;
  }

  @override
  ObservableList<KickChatMessage> get _messages => messages;

  @override
  set _messages(ObservableList<KickChatMessage> value) {
    _$_messagesAtom.reportWrite(value, super._messages, () {
      super._messages = value;
    });
  }

  late final _$_autoScrollAtom = Atom(
    name: 'ChatStoreBase._autoScroll',
    context: context,
  );

  bool get autoScroll {
    _$_autoScrollAtom.reportRead();
    return super._autoScroll;
  }

  @override
  bool get _autoScroll => autoScroll;

  @override
  set _autoScroll(bool value) {
    _$_autoScrollAtom.reportWrite(value, super._autoScroll, () {
      super._autoScroll = value;
    });
  }

  late final _$_inputTextAtom = Atom(
    name: 'ChatStoreBase._inputText',
    context: context,
  );

  String get inputText {
    _$_inputTextAtom.reportRead();
    return super._inputText;
  }

  @override
  String get _inputText => inputText;

  @override
  set _inputText(String value) {
    _$_inputTextAtom.reportWrite(value, super._inputText, () {
      super._inputText = value;
    });
  }

  late final _$_showSendButtonAtom = Atom(
    name: 'ChatStoreBase._showSendButton',
    context: context,
  );

  bool get showSendButton {
    _$_showSendButtonAtom.reportRead();
    return super._showSendButton;
  }

  @override
  bool get _showSendButton => showSendButton;

  @override
  set _showSendButton(bool value) {
    _$_showSendButtonAtom.reportWrite(value, super._showSendButton, () {
      super._showSendButton = value;
    });
  }

  late final _$_showEmoteAutocompleteAtom = Atom(
    name: 'ChatStoreBase._showEmoteAutocomplete',
    context: context,
  );

  bool get showEmoteAutocomplete {
    _$_showEmoteAutocompleteAtom.reportRead();
    return super._showEmoteAutocomplete;
  }

  @override
  bool get _showEmoteAutocomplete => showEmoteAutocomplete;

  @override
  set _showEmoteAutocomplete(bool value) {
    _$_showEmoteAutocompleteAtom.reportWrite(
      value,
      super._showEmoteAutocomplete,
      () {
        super._showEmoteAutocomplete = value;
      },
    );
  }

  late final _$_showMentionAutocompleteAtom = Atom(
    name: 'ChatStoreBase._showMentionAutocomplete',
    context: context,
  );

  bool get showMentionAutocomplete {
    _$_showMentionAutocompleteAtom.reportRead();
    return super._showMentionAutocomplete;
  }

  @override
  bool get _showMentionAutocomplete => showMentionAutocomplete;

  @override
  set _showMentionAutocomplete(bool value) {
    _$_showMentionAutocompleteAtom.reportWrite(
      value,
      super._showMentionAutocomplete,
      () {
        super._showMentionAutocomplete = value;
      },
    );
  }

  late final _$_isWaitingForAckAtom = Atom(
    name: 'ChatStoreBase._isWaitingForAck',
    context: context,
  );

  bool get isWaitingForAck {
    _$_isWaitingForAckAtom.reportRead();
    return super._isWaitingForAck;
  }

  @override
  bool get _isWaitingForAck => isWaitingForAck;

  @override
  set _isWaitingForAck(bool value) {
    _$_isWaitingForAckAtom.reportWrite(value, super._isWaitingForAck, () {
      super._isWaitingForAck = value;
    });
  }

  late final _$_isConnectedAtom = Atom(
    name: 'ChatStoreBase._isConnected',
    context: context,
  );

  bool get isConnected {
    _$_isConnectedAtom.reportRead();
    return super._isConnected;
  }

  @override
  bool get _isConnected => isConnected;

  @override
  set _isConnected(bool value) {
    _$_isConnectedAtom.reportWrite(value, super._isConnected, () {
      super._isConnected = value;
    });
  }

  late final _$_hasConnectedAtom = Atom(
    name: 'ChatStoreBase._hasConnected',
    context: context,
  );

  bool get hasConnected {
    _$_hasConnectedAtom.reportRead();
    return super._hasConnected;
  }

  @override
  bool get _hasConnected => hasConnected;

  @override
  set _hasConnected(bool value) {
    _$_hasConnectedAtom.reportWrite(value, super._hasConnected, () {
      super._hasConnected = value;
    });
  }

  late final _$expandChatAtom = Atom(
    name: 'ChatStoreBase.expandChat',
    context: context,
  );

  @override
  bool get expandChat {
    _$expandChatAtom.reportRead();
    return super.expandChat;
  }

  @override
  set expandChat(bool value) {
    _$expandChatAtom.reportWrite(value, super.expandChat, () {
      super.expandChat = value;
    });
  }

  late final _$replyingToMessageAtom = Atom(
    name: 'ChatStoreBase.replyingToMessage',
    context: context,
  );

  @override
  KickChatMessage? get replyingToMessage {
    _$replyingToMessageAtom.reportRead();
    return super.replyingToMessage;
  }

  @override
  set replyingToMessage(KickChatMessage? value) {
    _$replyingToMessageAtom.reportWrite(value, super.replyingToMessage, () {
      super.replyingToMessage = value;
    });
  }

  late final _$pinnedMessageAtom = Atom(
    name: 'ChatStoreBase.pinnedMessage',
    context: context,
  );

  @override
  KickPinnedMessageEvent? get pinnedMessage {
    _$pinnedMessageAtom.reportRead();
    return super.pinnedMessage;
  }

  @override
  set pinnedMessage(KickPinnedMessageEvent? value) {
    _$pinnedMessageAtom.reportWrite(value, super.pinnedMessage, () {
      super.pinnedMessage = value;
    });
  }

  late final _$activePollAtom = Atom(
    name: 'ChatStoreBase.activePoll',
    context: context,
  );

  @override
  KickPollUpdateEvent? get activePoll {
    _$activePollAtom.reportRead();
    return super.activePoll;
  }

  @override
  set activePoll(KickPollUpdateEvent? value) {
    _$activePollAtom.reportWrite(value, super.activePoll, () {
      super.activePoll = value;
    });
  }

  late final _$activePredictionAtom = Atom(
    name: 'ChatStoreBase.activePrediction',
    context: context,
  );

  @override
  KickPredictionEvent? get activePrediction {
    _$activePredictionAtom.reportRead();
    return super.activePrediction;
  }

  @override
  set activePrediction(KickPredictionEvent? value) {
    _$activePredictionAtom.reportWrite(value, super.activePrediction, () {
      super.activePrediction = value;
    });
  }

  late final _$hasVotedOnPollAtom = Atom(
    name: 'ChatStoreBase.hasVotedOnPoll',
    context: context,
  );

  @override
  bool get hasVotedOnPoll {
    _$hasVotedOnPollAtom.reportRead();
    return super.hasVotedOnPoll;
  }

  @override
  set hasVotedOnPoll(bool value) {
    _$hasVotedOnPollAtom.reportWrite(value, super.hasVotedOnPoll, () {
      super.hasVotedOnPoll = value;
    });
  }

  late final _$pollVotedOptionIndexAtom = Atom(
    name: 'ChatStoreBase.pollVotedOptionIndex',
    context: context,
  );

  @override
  int? get pollVotedOptionIndex {
    _$pollVotedOptionIndexAtom.reportRead();
    return super.pollVotedOptionIndex;
  }

  @override
  set pollVotedOptionIndex(int? value) {
    _$pollVotedOptionIndexAtom.reportWrite(
      value,
      super.pollVotedOptionIndex,
      () {
        super.pollVotedOptionIndex = value;
      },
    );
  }

  late final _$hasVotedOnPredictionAtom = Atom(
    name: 'ChatStoreBase.hasVotedOnPrediction',
    context: context,
  );

  @override
  bool get hasVotedOnPrediction {
    _$hasVotedOnPredictionAtom.reportRead();
    return super.hasVotedOnPrediction;
  }

  @override
  set hasVotedOnPrediction(bool value) {
    _$hasVotedOnPredictionAtom.reportWrite(
      value,
      super.hasVotedOnPrediction,
      () {
        super.hasVotedOnPrediction = value;
      },
    );
  }

  late final _$predictionVotedOutcomeIdAtom = Atom(
    name: 'ChatStoreBase.predictionVotedOutcomeId',
    context: context,
  );

  @override
  String? get predictionVotedOutcomeId {
    _$predictionVotedOutcomeIdAtom.reportRead();
    return super.predictionVotedOutcomeId;
  }

  @override
  set predictionVotedOutcomeId(String? value) {
    _$predictionVotedOutcomeIdAtom.reportWrite(
      value,
      super.predictionVotedOutcomeId,
      () {
        super.predictionVotedOutcomeId = value;
      },
    );
  }

  late final _$predictionVoteAmountAtom = Atom(
    name: 'ChatStoreBase.predictionVoteAmount',
    context: context,
  );

  @override
  int? get predictionVoteAmount {
    _$predictionVoteAmountAtom.reportRead();
    return super.predictionVoteAmount;
  }

  @override
  set predictionVoteAmount(int? value) {
    _$predictionVoteAmountAtom.reportWrite(
      value,
      super.predictionVoteAmount,
      () {
        super.predictionVoteAmount = value;
      },
    );
  }

  late final _$isPinnedMessageMinimizedAtom = Atom(
    name: 'ChatStoreBase.isPinnedMessageMinimized',
    context: context,
  );

  @override
  bool get isPinnedMessageMinimized {
    _$isPinnedMessageMinimizedAtom.reportRead();
    return super.isPinnedMessageMinimized;
  }

  @override
  set isPinnedMessageMinimized(bool value) {
    _$isPinnedMessageMinimizedAtom.reportWrite(
      value,
      super.isPinnedMessageMinimized,
      () {
        super.isPinnedMessageMinimized = value;
      },
    );
  }

  late final _$isPollMinimizedAtom = Atom(
    name: 'ChatStoreBase.isPollMinimized',
    context: context,
  );

  @override
  bool get isPollMinimized {
    _$isPollMinimizedAtom.reportRead();
    return super.isPollMinimized;
  }

  @override
  set isPollMinimized(bool value) {
    _$isPollMinimizedAtom.reportWrite(value, super.isPollMinimized, () {
      super.isPollMinimized = value;
    });
  }

  late final _$isPredictionMinimizedAtom = Atom(
    name: 'ChatStoreBase.isPredictionMinimized',
    context: context,
  );

  @override
  bool get isPredictionMinimized {
    _$isPredictionMinimizedAtom.reportRead();
    return super.isPredictionMinimized;
  }

  @override
  set isPredictionMinimized(bool value) {
    _$isPredictionMinimizedAtom.reportWrite(
      value,
      super.isPredictionMinimized,
      () {
        super.isPredictionMinimized = value;
      },
    );
  }

  late final _$voteOnPollAsyncAction = AsyncAction(
    'ChatStoreBase.voteOnPoll',
    context: context,
  );

  @override
  Future<void> voteOnPoll(int optionIndex) {
    return _$voteOnPollAsyncAction.run(() => super.voteOnPoll(optionIndex));
  }

  late final _$betOnPredictionAsyncAction = AsyncAction(
    'ChatStoreBase.betOnPrediction',
    context: context,
  );

  @override
  Future<void> betOnPrediction(String outcomeId, int amount) {
    return _$betOnPredictionAsyncAction.run(
      () => super.betOnPrediction(outcomeId, amount),
    );
  }

  late final _$getAssetsAsyncAction = AsyncAction(
    'ChatStoreBase.getAssets',
    context: context,
  );

  @override
  Future<void> getAssets() {
    return _$getAssetsAsyncAction.run(() => super.getAssets());
  }

  late final _$connectToChatAsyncAction = AsyncAction(
    'ChatStoreBase.connectToChat',
    context: context,
  );

  @override
  Future<void> connectToChat({bool isReconnect = false}) {
    return _$connectToChatAsyncAction.run(
      () => super.connectToChat(isReconnect: isReconnect),
    );
  }

  late final _$sendMessageAsyncAction = AsyncAction(
    'ChatStoreBase.sendMessage',
    context: context,
  );

  @override
  Future<void> sendMessage(String message) {
    return _$sendMessageAsyncAction.run(() => super.sendMessage(message));
  }

  late final _$ChatStoreBaseActionController = ActionController(
    name: 'ChatStoreBase',
    context: context,
  );

  @override
  void revealMessage(String id) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.revealMessage',
    );
    try {
      return super.revealMessage(id);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handlePusherEvent(String rawData) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handlePusherEvent',
    );
    try {
      return super._handlePusherEvent(rawData);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _onConnected() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._onConnected',
    );
    try {
      return super._onConnected();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleChatMessage(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleChatMessage',
    );
    try {
      return super._handleChatMessage(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleMessageDeleted(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleMessageDeleted',
    );
    try {
      return super._handleMessageDeleted(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleUserBanned(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleUserBanned',
    );
    try {
      return super._handleUserBanned(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleUserUnbanned(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleUserUnbanned',
    );
    try {
      return super._handleUserUnbanned(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleChatroomUpdated(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleChatroomUpdated',
    );
    try {
      return super._handleChatroomUpdated(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleChatroomClear() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleChatroomClear',
    );
    try {
      return super._handleChatroomClear();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handlePinnedMessageCreated(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handlePinnedMessageCreated',
    );
    try {
      return super._handlePinnedMessageCreated(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handlePinnedMessageDeleted() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handlePinnedMessageDeleted',
    );
    try {
      return super._handlePinnedMessageDeleted();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handlePollUpdate(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handlePollUpdate',
    );
    try {
      return super._handlePollUpdate(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handlePollDeleted() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handlePollDeleted',
    );
    try {
      return super._handlePollDeleted();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handlePredictionUpdate(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handlePredictionUpdate',
    );
    try {
      return super._handlePredictionUpdate(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleTitleChanged(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleTitleChanged',
    );
    try {
      return super._handleTitleChanged(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleCategoryChanged(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleCategoryChanged',
    );
    try {
      return super._handleCategoryChanged(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleLivestreamUpdated(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleLivestreamUpdated',
    );
    try {
      return super._handleLivestreamUpdated(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleSubscriptionEvent(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleSubscriptionEvent',
    );
    try {
      return super._handleSubscriptionEvent(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleGiftedSubscriptionEvent(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleGiftedSubscriptionEvent',
    );
    try {
      return super._handleGiftedSubscriptionEvent(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleFollowEvent(KickPusherEvent event, {required bool isFollowing}) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleFollowEvent',
    );
    try {
      return super._handleFollowEvent(event, isFollowing: isFollowing);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleRaidEvent(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleRaidEvent',
    );
    try {
      return super._handleRaidEvent(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleKicksGiftedEvent(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleKicksGiftedEvent',
    );
    try {
      return super._handleKicksGiftedEvent(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _handleRewardRedeemedEvent(KickPusherEvent event) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._handleRewardRedeemedEvent',
    );
    try {
      return super._handleRewardRedeemedEvent(event);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void resumeScroll() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.resumeScroll',
    );
    try {
      return super.resumeScroll();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void addMessages() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.addMessages',
    );
    try {
      return super.addMessages();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _cancelChatDelayCountdown() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._cancelChatDelayCountdown',
    );
    try {
      return super._cancelChatDelayCountdown();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _startChatDelayCountdown() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase._startChatDelayCountdown',
    );
    try {
      return super._startChatDelayCountdown();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void addEmote(Emote emote, {bool autocompleteMode = false}) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.addEmote',
    );
    try {
      return super.addEmote(emote, autocompleteMode: autocompleteMode);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void updateNotification(String notificationMessage) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.updateNotification',
    );
    try {
      return super.updateNotification(notificationMessage);
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearNotification() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.clearNotification',
    );
    try {
      return super.clearNotification();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void updateSleepTimer({
    required Duration duration,
    required VoidCallback onTimerFinished,
  }) {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.updateSleepTimer',
    );
    try {
      return super.updateSleepTimer(
        duration: duration,
        onTimerFinished: onTimerFinished,
      );
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void cancelSleepTimer() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.cancelSleepTimer',
    );
    try {
      return super.cancelSleepTimer();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void unfocusInput() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.unfocusInput',
    );
    try {
      return super.unfocusInput();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void safeRequestFocus() {
    final _$actionInfo = _$ChatStoreBaseActionController.startAction(
      name: 'ChatStoreBase.safeRequestFocus',
    );
    try {
      return super.safeRequestFocus();
    } finally {
      _$ChatStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
streamTitle: ${streamTitle},
streamCategory: ${streamCategory},
timeRemaining: ${timeRemaining},
expandChat: ${expandChat},
replyingToMessage: ${replyingToMessage},
pinnedMessage: ${pinnedMessage},
activePoll: ${activePoll},
activePrediction: ${activePrediction},
hasVotedOnPoll: ${hasVotedOnPoll},
pollVotedOptionIndex: ${pollVotedOptionIndex},
hasVotedOnPrediction: ${hasVotedOnPrediction},
predictionVotedOutcomeId: ${predictionVotedOutcomeId},
predictionVoteAmount: ${predictionVoteAmount},
isPinnedMessageMinimized: ${isPinnedMessageMinimized},
isPollMinimized: ${isPollMinimized},
isPredictionMinimized: ${isPredictionMinimized},
renderMessages: ${renderMessages},
matchingEmotes: ${matchingEmotes},
matchingChatters: ${matchingChatters},
bottomBarHeight: ${bottomBarHeight}
    ''';
  }
}
