// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$UserStore on UserStoreBase, Store {
  late final _$_detailsAtom = Atom(
    name: 'UserStoreBase._details',
    context: context,
  );

  KickUser? get details {
    _$_detailsAtom.reportRead();
    return super._details;
  }

  @override
  KickUser? get _details => details;

  @override
  set _details(KickUser? value) {
    _$_detailsAtom.reportWrite(value, super._details, () {
      super._details = value;
    });
  }

  late final _$_followedChannelsAtom = Atom(
    name: 'UserStoreBase._followedChannels',
    context: context,
  );

  ObservableList<String> get followedChannels {
    _$_followedChannelsAtom.reportRead();
    return super._followedChannels;
  }

  @override
  ObservableList<String> get _followedChannels => followedChannels;

  @override
  set _followedChannels(ObservableList<String> value) {
    _$_followedChannelsAtom.reportWrite(value, super._followedChannels, () {
      super._followedChannels = value;
    });
  }

  late final _$_blockedUsernamesAtom = Atom(
    name: 'UserStoreBase._blockedUsernames',
    context: context,
  );

  ObservableSet<String> get blockedUsernames {
    _$_blockedUsernamesAtom.reportRead();
    return super._blockedUsernames;
  }

  @override
  ObservableSet<String> get _blockedUsernames => blockedUsernames;

  @override
  set _blockedUsernames(ObservableSet<String> value) {
    _$_blockedUsernamesAtom.reportWrite(value, super._blockedUsernames, () {
      super._blockedUsernames = value;
    });
  }

  late final _$initAsyncAction = AsyncAction(
    'UserStoreBase.init',
    context: context,
  );

  @override
  Future<void> init() {
    return _$initAsyncAction.run(() => super.init());
  }

  late final _$fetchBlockedUsersAsyncAction = AsyncAction(
    'UserStoreBase.fetchBlockedUsers',
    context: context,
  );

  @override
  Future<void> fetchBlockedUsers() {
    return _$fetchBlockedUsersAsyncAction.run(() => super.fetchBlockedUsers());
  }

  late final _$followAsyncAction = AsyncAction(
    'UserStoreBase.follow',
    context: context,
  );

  @override
  Future<bool> follow({required String channelSlug}) {
    return _$followAsyncAction.run(
      () => super.follow(channelSlug: channelSlug),
    );
  }

  late final _$unfollowAsyncAction = AsyncAction(
    'UserStoreBase.unfollow',
    context: context,
  );

  @override
  Future<bool> unfollow({required String channelSlug}) {
    return _$unfollowAsyncAction.run(
      () => super.unfollow(channelSlug: channelSlug),
    );
  }

  late final _$UserStoreBaseActionController = ActionController(
    name: 'UserStoreBase',
    context: context,
  );

  @override
  void dispose() {
    final _$actionInfo = _$UserStoreBaseActionController.startAction(
      name: 'UserStoreBase.dispose',
    );
    try {
      return super.dispose();
    } finally {
      _$UserStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
