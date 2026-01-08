// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocked_users_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$BlockedUsersStore on _BlockedUsersStore, Store {
  late final _$blockedUsersAtom = Atom(
    name: '_BlockedUsersStore.blockedUsers',
    context: context,
  );

  @override
  ObservableList<KickSilencedUser> get blockedUsers {
    _$blockedUsersAtom.reportRead();
    return super.blockedUsers;
  }

  @override
  set blockedUsers(ObservableList<KickSilencedUser> value) {
    _$blockedUsersAtom.reportWrite(value, super.blockedUsers, () {
      super.blockedUsers = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_BlockedUsersStore.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_BlockedUsersStore.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$fetchBlockedUsersAsyncAction = AsyncAction(
    '_BlockedUsersStore.fetchBlockedUsers',
    context: context,
  );

  @override
  Future<void> fetchBlockedUsers() {
    return _$fetchBlockedUsersAsyncAction.run(() => super.fetchBlockedUsers());
  }

  late final _$blockUserAsyncAction = AsyncAction(
    '_BlockedUsersStore.blockUser',
    context: context,
  );

  @override
  Future<bool> blockUser(String username) {
    return _$blockUserAsyncAction.run(() => super.blockUser(username));
  }

  late final _$unblockUserAsyncAction = AsyncAction(
    '_BlockedUsersStore.unblockUser',
    context: context,
  );

  @override
  Future<bool> unblockUser(int userId) {
    return _$unblockUserAsyncAction.run(() => super.unblockUser(userId));
  }

  @override
  String toString() {
    return '''
blockedUsers: ${blockedUsers},
isLoading: ${isLoading},
errorMessage: ${errorMessage}
    ''';
  }
}
