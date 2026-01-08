import 'package:dio/dio.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';

/// Interceptor that automatically adds Kick authorization headers to API requests.
class KickAuthInterceptor extends Interceptor {
  final AuthStore _authStore;

  KickAuthInterceptor(this._authStore);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add auth headers if user is logged in and request is to Kick API
    if (_shouldAddKickHeaders(options.uri)) {
      final kickHeaders = _authStore.headersKick;
      options.headers.addAll(kickHeaders);
    }
    handler.next(options);
  }

  /// Check if the request URL requires Kick authentication headers.
  bool _shouldAddKickHeaders(Uri uri) {
    final url = uri.toString();

    // Add auth to kick.com API calls
    if (url.contains('kick.com/api')) {
      return true;
    }

    // Add auth to official Kick API
    if (url.contains('api.kick.com')) {
      return true;
    }

    // Add auth to Kick OAuth endpoints
    if (url.contains('id.kick.com/oauth')) {
      return true;
    }

    return false;
  }
}

/// Interceptor that handles 401 Unauthorized responses for Kick API.
class KickUnauthorizedInterceptor extends Interceptor {
  final AuthStore _authStore;
  bool _isShowingLoginDialog = false;

  KickUnauthorizedInterceptor(this._authStore);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token validation requests should propagate the error
      if (err.requestOptions.uri.path.endsWith('/validate') ||
          err.requestOptions.uri.path.endsWith('/token')) {
        handler.next(err);
        return;
      }

      // For other 401 errors, trigger re-authentication
      if (!_isShowingLoginDialog) {
        _isShowingLoginDialog = true;
        _authStore.handleUnauthorized().then((_) {
          _isShowingLoginDialog = false;
        });
      }

      // Don't propagate the error - we're handling it
      return;
    }

    handler.next(err);
  }
}
