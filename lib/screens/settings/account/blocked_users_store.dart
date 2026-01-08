import 'package:flutter/material.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_silenced_user.dart';
import 'package:mobx/mobx.dart';

part 'blocked_users_store.g.dart';

class BlockedUsersStore = _BlockedUsersStore with _$BlockedUsersStore;

abstract class _BlockedUsersStore with Store {
  final KickApi _kickApi;

  _BlockedUsersStore(this._kickApi);

  @observable
  ObservableList<KickSilencedUser> blockedUsers = ObservableList<KickSilencedUser>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @action
  Future<void> fetchBlockedUsers() async {
    isLoading = true;
    errorMessage = null;
    try {
      final users = await _kickApi.getSilencedUsers();
      blockedUsers.clear();
      blockedUsers.addAll(users);
    } catch (e) {
      errorMessage = 'Failed to fetch blocked users';
      debugPrint('Error fetching blocked users: $e');
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> blockUser(String username) async {
    try {
      final success = await _kickApi.blockUser(username: username);
      if (success) {
        await fetchBlockedUsers(); // Refresh list
        return true;
      } else {
        errorMessage = 'Failed to block user';
        return false;
      }
    } catch (e) {
      errorMessage = 'Error blocking user';
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  @action
  Future<bool> unblockUser(int userId) async {
    try {
      final success = await _kickApi.unblockUser(userId: userId);
      if (success) {
        blockedUsers.removeWhere((u) => u.id == userId);
        return true;
      } else {
        errorMessage = 'Failed to unblock user';
        return false;
      }
    } catch (e) {
      errorMessage = 'Error unblocking user';
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }
}
