import 'package:flutter/material.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_user.dart';
import 'package:mobx/mobx.dart';

part 'user_store.g.dart';

class UserStore = UserStoreBase with _$UserStore;

abstract class UserStoreBase with Store {
  final KickApi kickApi;

  /// The current user's info.
  @readonly
  KickUser? _details;

  /// The user's list of followed channels.
  @readonly
  var _followedChannels = ObservableList<String>();

  /// The user's list of blocked usernames (for chat filtering).
  @readonly
  var _blockedUsernames = ObservableSet<String>();

  ReactionDisposer? _disposeReaction;

  UserStoreBase({required this.kickApi});

  @action
  Future<void> init() async {
    try {
      // Get and update the current user's info.
      _details = await kickApi.getCurrentUser();

      // Fetch blocked users for chat filtering
      await fetchBlockedUsers();

      debugPrint('User initialized: ${_details?.username}');
    } catch (e) {
      debugPrint('Failed to initialize user: $e');
      _details = null;
    }
  }

  /// Fetch blocked users and update the local list.
  @action
  Future<void> fetchBlockedUsers() async {
    try {
      final blocked = await kickApi.getSilencedUsers();
      _blockedUsernames.clear();
      _blockedUsernames.addAll(blocked.map((u) => u.username.toLowerCase()));
    } catch (e) {
      debugPrint('Failed to fetch blocked users: $e');
    }
  }

  /// Check if the user is following a specific channel.
  Future<bool> isFollowing({required String channelSlug}) async {
    try {
      return await kickApi.isFollowing(channelSlug: channelSlug);
    } catch (e) {
      debugPrint('Failed to check follow status: $e');
      return false;
    }
  }

  /// Follow a channel.
  @action
  Future<bool> follow({required String channelSlug}) async {
    try {
      final success = await kickApi.followChannel(channelSlug: channelSlug);
      if (success) {
        _followedChannels.add(channelSlug);
      }
      return success;
    } catch (e) {
      debugPrint('Failed to follow channel: $e');
      return false;
    }
  }

  /// Unfollow a channel.
  @action
  Future<bool> unfollow({required String channelSlug}) async {
    try {
      final success = await kickApi.unfollowChannel(channelSlug: channelSlug);
      if (success) {
        _followedChannels.remove(channelSlug);
      }
      return success;
    } catch (e) {
      debugPrint('Failed to unfollow channel: $e');
      return false;
    }
  }

  @action
  void dispose() {
    _details = null;
    _followedChannels.clear();
    _blockedUsernames.clear();
    if (_disposeReaction != null) _disposeReaction!();
  }
}
