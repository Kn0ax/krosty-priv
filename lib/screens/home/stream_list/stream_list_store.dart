import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:krosty/apis/base_api_client.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:mobx/mobx.dart';

part 'stream_list_store.g.dart';

class ListStore = ListStoreBase with _$ListStore;

abstract class ListStoreBase with Store {
  /// The authentication store.
  final AuthStore authStore;

  final SettingsStore settingsStore;

  /// Kick API service class for making requests.
  final KickApi kickApi;

  /// The type of list that this store is handling.
  final ListType listType;

  /// The category slug to use when fetching streams if the [listType] is [ListType.category].
  final String? categorySlug;

  /// The scroll controller used for handling scroll to top (if provided).
  final ScrollController? scrollController;

  /// The current page for pagination (featured/category only).
  int? _currentPage;

  /// The last page number (for knowing when there are no more results).
  int? _lastPage;

  /// Cursor for offline channels pagination.
  int _offlineChannelsCursor = 0;
  bool _hasMoreOfflineChannels = true;

  /// The last time the streams were refreshed/updated.
  var lastTimeRefreshed = DateTime.now();

  /// Returns whether or not there are more streams and loading status for pagination.
  @computed
  bool get hasMore {
    if (isLoading) return false;
    if (listType == ListType.followed) {
      // Live streams from /user/livestreams don't have pagination
      return false;
    }
    return _lastPage != null && (_currentPage ?? 1) < _lastPage!;
  }

  /// Whether there are more offline channels to load.
  @computed
  bool get hasMoreOfflineChannels =>
      !_isOfflineChannelsLoading && _hasMoreOfflineChannels;

  @computed
  bool get isLoading =>
      _isAllStreamsLoading ||
      _isCategoryDetailsLoading ||
      _isOfflineChannelsLoading;

  /// The list of the fetched streams (for non-followed tabs and live followed).
  @readonly
  var _allStreams = ObservableList<KickLivestreamItem>();

  /// The list of offline followed channels (for followed tab).
  @readonly
  var _offlineFollowedChannels = ObservableList<KickFollowedChannel>();

  @readonly
  bool _isAllStreamsLoading = false;

  @readonly
  bool _isOfflineChannelsLoading = false;

  @readonly
  KickCategory? _categoryDetails;

  @readonly
  var _isCategoryDetailsLoading = false;

  /// Whether or not the scroll to top button is visible.
  @observable
  var showJumpButton = false;

  /// Whether the offline channels section is expanded.
  @observable
  var isOfflineChannelsExpanded = false;

  /// The list of the fetched streams.
  @computed
  ObservableList<KickLivestreamItem> get streams => _allStreams;

  /// Live streams (for followed tab, same as streams).
  @computed
  List<KickLivestreamItem> get liveStreams => _allStreams;

  /// Offline followed channels (for followed tab).
  @computed
  List<KickFollowedChannel> get offlineChannels {
    if (listType != ListType.followed) return [];
    return _offlineFollowedChannels;
  }

  /// The error message to show if any. Will be non-null if there is an error.
  @readonly
  String? _error;

  ListStoreBase({
    required this.authStore,
    required this.settingsStore,
    required this.kickApi,
    required this.listType,
    this.categorySlug,
    this.scrollController,
  }) {
    if (scrollController != null) {
      scrollController!.addListener(() {
        if (scrollController!.position.atEdge ||
            scrollController!.position.outOfRange) {
          showJumpButton = false;
        } else {
          showJumpButton = true;
        }
      });
    }

    if (listType == ListType.category && categorySlug != null) {
      _getCategoryDetails();
    }

    getStreams();
  }

  /// Fetches the streams based on the type and current page/cursor.
  @action
  Future<void> getStreams() async {
    _isAllStreamsLoading = true;

    try {
      if (listType == ListType.followed) {
        // Use /api/v1/user/livestreams for live streams with full details
        final liveStreams = await kickApi.getFollowedLivestreams();
        _allStreams = liveStreams.asObservable();

        // Also fetch offline channels if not already loaded
        if (_offlineFollowedChannels.isEmpty) {
          _loadOfflineChannels();
        }
      } else {
        // For top/category, use the standard response
        final KickLivestreamsResponse response;
        switch (listType) {
          case ListType.followed:
            // This case is handled above
            throw StateError('Unreachable');
          case ListType.top:
            response = await kickApi.getFeaturedLivestreams(
              page: _currentPage ?? 1,
            );
            break;
          case ListType.category:
            response = await kickApi.getLivestreamsByCategory(
              categorySlug: categorySlug!,
              page: _currentPage ?? 1,
            );
            break;
        }

        final isFirstLoad = (_currentPage ?? 1) == 1;

        if (isFirstLoad) {
          _allStreams = response.data.asObservable();
        } else {
          _allStreams.addAll(response.data);
        }

        // Page-based pagination
        _lastPage = response.lastPage;
        _currentPage = (_currentPage ?? 1) + 1;
      }

      _error = null;
    } on SocketException {
      _error = 'Unable to connect to Kick';
      debugPrint('Streams SocketException: No internet connection');
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Streams ApiException: $e');
    } catch (e) {
      _error = 'Something went wrong loading streams';
      debugPrint('Streams error: $e');
    }

    _isAllStreamsLoading = false;
  }

  /// Loads offline channels from /api/v2/channels/followed-page
  @action
  Future<void> _loadOfflineChannels() async {
    if (_isOfflineChannelsLoading || !_hasMoreOfflineChannels) return;

    _isOfflineChannelsLoading = true;

    try {
      final response = await kickApi.getFollowedChannelsPage(
        cursor: _offlineChannelsCursor,
      );

      // Filter to only offline channels
      final offlineChannels = response.channels
          .where((c) => !c.isLive)
          .toList();

      if (_offlineChannelsCursor == 0) {
        _offlineFollowedChannels = offlineChannels.asObservable();
      } else {
        _offlineFollowedChannels.addAll(offlineChannels);
      }

      // Update pagination
      if (response.nextCursor != null) {
        _offlineChannelsCursor = response.nextCursor!;
      } else {
        _hasMoreOfflineChannels = false;
      }
    } catch (e) {
      debugPrint('Failed to load offline channels: $e');
    }

    _isOfflineChannelsLoading = false;
  }

  /// Loads more offline channels (called when scrolling).
  @action
  Future<void> loadMoreOfflineChannels() async {
    await _loadOfflineChannels();
  }

  /// Resets the page/cursor and then fetches the streams.
  @action
  Future<void> refreshStreams() async {
    _currentPage = null;
    _lastPage = null;
    _offlineChannelsCursor = 0;
    _hasMoreOfflineChannels = true;
    _offlineFollowedChannels.clear();
    await getStreams();
  }

  @action
  Future<void> _getCategoryDetails() async {
    if (categorySlug == null) return;

    _isCategoryDetailsLoading = true;

    try {
      _categoryDetails = await kickApi.getCategory(categorySlug: categorySlug!);
    } catch (e) {
      debugPrint('Failed to get category details: $e');
    }

    _isCategoryDetailsLoading = false;
  }

  /// Checks the last time the streams were refreshed and updates them if it has been more than 5 minutes.
  void checkLastTimeRefreshedAndUpdate() {
    final now = DateTime.now();
    final difference = now.difference(lastTimeRefreshed);

    if (difference.inMinutes >= 5) refreshStreams();

    lastTimeRefreshed = now;
  }

  void dispose() {
    scrollController?.dispose();
  }
}

/// The possible types of lists that can be displayed.
///
/// [ListType.followed] is the list of streams that the user is following.
/// [ListType.top] is the list of top/featured streams.
/// [ListType.category] is the list of streams under a category.
enum ListType { followed, top, category }
