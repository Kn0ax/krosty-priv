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

  /// The current page/cursor for pagination.
  /// For featured/category streams: page-based (1, 2, 3...)
  /// For followed streams: cursor-based (null for first, then value from response)
  int? _currentPage;
  int? _cursor;

  /// The last page number (for knowing when there are no more results).
  int? _lastPage;
  bool _hasMoreCursor = true;

  /// The last time the streams were refreshed/updated.
  var lastTimeRefreshed = DateTime.now();

  /// Returns whether or not there are more streams and loading status for pagination.
  @computed
  bool get hasMore {
    if (isLoading) return false;
    if (listType == ListType.followed) {
      return _hasMoreCursor;
    }
    return _lastPage != null && (_currentPage ?? 1) < _lastPage!;
  }

  @computed
  bool get isLoading => _isAllStreamsLoading || _isCategoryDetailsLoading;

  /// The list of the fetched streams.
  @readonly
  var _allStreams = ObservableList<KickLivestreamItem>();

  @readonly
  bool _isAllStreamsLoading = false;

  @readonly
  KickCategory? _categoryDetails;

  @readonly
  var _isCategoryDetailsLoading = false;

  /// Whether or not the scroll to top button is visible.
  @observable
  var showJumpButton = false;

  /// The list of the fetched streams (no filtering for now - Kick user model may differ).
  @computed
  ObservableList<KickLivestreamItem> get streams => _allStreams;

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
      final KickLivestreamsResponse response;
      switch (listType) {
        case ListType.followed:
          response = await kickApi.getFollowedLivestreams(cursor: _cursor);
          break;
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

      final isFirstLoad = listType == ListType.followed
          ? _cursor == null
          : (_currentPage ?? 1) == 1;

      if (isFirstLoad) {
        _allStreams = response.data.asObservable();
      } else {
        _allStreams.addAll(response.data);
      }

      // Update pagination state
      if (listType == ListType.followed) {
        // Cursor-based: check if we got data, if empty or less than expected, no more
        _hasMoreCursor = response.data.isNotEmpty;
        // The cursor for next page would be provided in response, 
        // typically the last item's ID or a specific cursor field
        if (response.data.isNotEmpty) {
          _cursor = (_cursor ?? 0) + response.data.length;
        }
      } else {
        // Page-based
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

  /// Resets the page/cursor and then fetches the streams.
  @action
  Future<void> refreshStreams() async {
    _currentPage = null;
    _cursor = null;
    _lastPage = null;
    _hasMoreCursor = true;
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
