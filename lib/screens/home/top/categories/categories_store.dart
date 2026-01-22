import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:krosty/apis/base_api_client.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:mobx/mobx.dart';

part 'categories_store.g.dart';

class CategoriesStore = CategoriesStoreBase with _$CategoriesStore;

abstract class CategoriesStoreBase with Store {
  /// The authentication store.
  final AuthStore authStore;

  /// Kick API service class for making requests.
  final KickApi kickApi;

  /// The pagination page for the categories.
  int _page = 1;

  /// The last time the categories were refreshed/updated.
  var lastTimeRefreshed = DateTime.now();

  /// The loading status for pagination.
  @readonly
  bool _isLoading = false;

  /// The current visible categories, sorted by total viewers.
  @readonly
  var _categories = ObservableList<KickCategory>();

  /// The error message to show if any. Will be non-null if there is an error.
  @readonly
  String? _error;

  /// Returns whether or not there are more streams and loading status for pagination.
  @computed
  bool get hasMore => _isLoading == false; // Assuming infinite scroll or until empty list

  CategoriesStoreBase({required this.authStore, required this.kickApi}) {
    getCategories();
  }

  // Fetches the top categories based on the current page.
  @action
  Future<void> getCategories() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final result = await kickApi.getTopCategories(
        page: _page,
      );

      final newCategories = result.data;

      if (_page == 1) {
        _categories = ObservableList.of(newCategories);
      } else {
        _categories.addAll(newCategories);
      }
      
      if (newCategories.isNotEmpty) {
        _page++;
      }

      _error = null;
    } on SocketException {
      _error = 'Unable to connect to Kick';
      debugPrint('Categories SocketException: No internet connection');
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Categories ApiException: $e');
    } catch (e) {
      _error = 'Something went wrong loading categories';
      debugPrint('Categories error: $e');
    }

    _isLoading = false;
  }

  /// Resets the cursor and then fetches the categories.
  @action
  Future<void> refreshCategories() {
    _page = 1;
    return getCategories();
  }

  /// Checks the last time the categories were refreshed and updates them if it has been more than 5 minutes.
  void checkLastTimeRefreshedAndUpdate() {
    final now = DateTime.now();
    final difference = now.difference(lastTimeRefreshed);

    if (difference.inMinutes >= 5) refreshCategories();

    lastTimeRefreshed = now;
  }
}
