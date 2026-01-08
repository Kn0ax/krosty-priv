import 'package:flutter/material.dart';
import 'package:frosty/apis/kick_api.dart';
import 'package:frosty/models/kick_user.dart';
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

  ReactionDisposer? _disposeReaction;

  UserStoreBase({required this.kickApi});

  @action
  Future<void> init() async {
    try {
      // Get and update the current user's info.
      _details = await kickApi.getCurrentUser();

      debugPrint('User initialized: ${_details?.username}');
    } catch (e) {
      debugPrint('Failed to initialize user: $e');
      _details = null;
    }
  }

  /// Check if the user is following a specific channel.
  Future<bool> isFollowing({required int channelId}) async {
    try {
      return await kickApi.isFollowing(channelId: channelId);
    } catch (e) {
      debugPrint('Failed to check follow status: $e');
      return false;
    }
  }

  /// Follow a channel.
  @action
  Future<bool> follow({required int channelId}) async {
    try {
      final success = await kickApi.followChannel(channelId: channelId);
      if (success) {
        _followedChannels.add(channelId.toString());
      }
      return success;
    } catch (e) {
      debugPrint('Failed to follow channel: $e');
      return false;
    }
  }

  /// Unfollow a channel.
  @action
  Future<bool> unfollow({required int channelId}) async {
    try {
      final success = await kickApi.unfollowChannel(channelId: channelId);
      if (success) {
        _followedChannels.remove(channelId.toString());
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
    if (_disposeReaction != null) _disposeReaction!();
  }
}
