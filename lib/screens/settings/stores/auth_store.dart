import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/kick_api.dart';
import 'package:frosty/main.dart';
import 'package:frosty/screens/settings/stores/user_store.dart';
import 'package:frosty/widgets/frosty_dialog.dart';
import 'package:mobx/mobx.dart';
import 'package:webview_flutter/webview_flutter.dart';

part 'auth_store.g.dart';

class AuthStore = AuthBase with _$AuthStore;

abstract class AuthBase with Store {
  /// Secure storage to store auth data.
  static const _storage = FlutterSecureStorage();

  /// Storage keys for Kick authentication.
  static const _xsrfTokenKey = 'kick_xsrf_token';
  static const _sessionTokenKey = 'kick_session_token';
  static const _userDataKey = 'kick_user_data';

  /// The Kick API service for making requests.
  final KickApi kickApi;

  /// Timer used to retry authentication when offline or on transient failures.
  Timer? _reconnectTimer;

  /// Retry count for reconnection attempts.
  var _reconnectAttempts = 0;

  /// Maximum number of reconnection attempts before giving up.
  static const _maxReconnectAttempts = 5;

  /// The MobX store containing information relevant to the current user.
  final UserStore user;

  /// XSRF token for Kick API requests.
  @readonly
  String? _xsrfToken;

  /// Session token (kick_session cookie).
  @readonly
  String? _sessionToken;

  /// Whether the user is logged in or not.
  @readonly
  var _isLoggedIn = false;

  /// Connection state for UI feedback.
  @readonly
  var _connectionState = ConnectionState.none;

  /// Authentication headers for Kick API requests.
  @computed
  Map<String, String> get headersKick {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (_xsrfToken != null) {
      headers['X-XSRF-TOKEN'] = _xsrfToken!;
    }

    if (_sessionToken != null) {
      headers['Cookie'] = 'kick_session=$_sessionToken';
    }

    return headers;
  }

  /// Error flag that will be non-null and contain an error message if login failed.
  @readonly
  String? _error;

  AuthBase({required this.kickApi}) : user = UserStore(kickApi: kickApi);

  /// Initialize by checking for stored session.
  @action
  Future<void> init() async {
    try {
      _connectionState = ConnectionState.waiting;

      // Read stored tokens
      _xsrfToken = await _storage.read(key: _xsrfTokenKey);
      _sessionToken = await _storage.read(key: _sessionTokenKey);

      if (_sessionToken != null && _xsrfToken != null) {
        // Try to validate session by fetching user info
        try {
          await user.init();
          if (user.details != null) {
            _isLoggedIn = true;
            _connectionState = ConnectionState.done;
            _stopReconnectLoop();
          } else {
            // Session invalid, clear tokens
            await _clearStoredTokens();
            _connectionState = ConnectionState.done;
          }
        } on ApiException catch (e) {
          debugPrint('Session validation failed: $e');
          if (e.statusCode == 401) {
            await _clearStoredTokens();
          } else {
            // Network error, start reconnect loop
            _startReconnectLoop();
          }
          _connectionState = ConnectionState.done;
        }
      } else {
        _connectionState = ConnectionState.done;
      }

      _error = null;
    } catch (e) {
      debugPrint('Auth init error: $e');
      _error = e.toString();
      _connectionState = ConnectionState.done;
    }
  }

  /// Create WebViewController for Kick login.
  /// Uses fresh WebView to let user login to Kick normally,
  /// then extracts session cookies for API access.
  WebViewController createAuthWebViewController({Widget? routeAfter}) {
    final webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    return webViewController
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              _handleNavigation(request: request, routeAfter: routeAfter),
          onWebResourceError: (error) {
            debugPrint('Auth WebView error: ${error.description}');
          },
          onPageFinished: (url) async {
            // Check if we're on the main Kick page after login
            if (url.contains('kick.com') && !url.contains('/login')) {
              await _extractCookiesFromWebView(webViewController, routeAfter);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://kick.com/login'));
  }

  /// Handle navigation in the auth WebView.
  FutureOr<NavigationDecision> _handleNavigation({
    required NavigationRequest request,
    Widget? routeAfter,
  }) {
    // Allow all navigation within Kick domain
    if (request.url.contains('kick.com')) {
      return NavigationDecision.navigate;
    }

    // Allow OAuth providers (Google, Apple, etc.)
    if (request.url.contains('accounts.google.com') ||
        request.url.contains('appleid.apple.com')) {
      return NavigationDecision.navigate;
    }

    // Block external navigation
    return NavigationDecision.prevent;
  }

  /// Extract cookies from WebView after successful login.
  Future<void> _extractCookiesFromWebView(
    WebViewController controller,
    Widget? routeAfter,
  ) async {
    try {
      // Execute JavaScript to get cookies and check if logged in
      final result = await controller.runJavaScriptReturningResult('''
        (function() {
          // Check if user is logged in by looking for user data
          const userDataScript = document.querySelector('script[id="__NEXT_DATA__"]');
          let userData = null;

          if (userDataScript) {
            try {
              const data = JSON.parse(userDataScript.textContent);
              if (data.props?.pageProps?.user || data.props?.initialState?.user) {
                userData = data.props?.pageProps?.user || data.props?.initialState?.user;
              }
            } catch (e) {}
          }

          // Get cookies
          const cookies = document.cookie;

          return JSON.stringify({
            cookies: cookies,
            userData: userData,
            loggedIn: userData !== null
          });
        })()
      ''');

      final jsonStr = result.toString();
      // Remove quotes if present (JavaScript returns quoted string)
      final cleanJson =
          jsonStr.startsWith('"') ? jsonDecode(jsonStr) : jsonStr;
      final data = jsonDecode(cleanJson is String ? cleanJson : jsonStr);

      if (data['loggedIn'] == true) {
        // Parse cookies
        final cookieString = data['cookies'] as String? ?? '';
        await _parseCookies(cookieString);

        // Store user data if available
        if (data['userData'] != null) {
          await _storage.write(
            key: _userDataKey,
            value: jsonEncode(data['userData']),
          );
        }

        // Initialize user store
        await user.init();

        if (user.details != null) {
          _isLoggedIn = true;
          _error = null;

          // Navigate away from login
          if (routeAfter != null) {
            navigatorKey.currentState?.pop();
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (context) => routeAfter),
            );
          } else {
            navigatorKey.currentState?.pop();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to extract cookies: $e');
    }
  }

  /// Parse and store cookies from cookie string.
  Future<void> _parseCookies(String cookieString) async {
    final cookies = cookieString.split(';');

    for (final cookie in cookies) {
      final parts = cookie.trim().split('=');
      if (parts.length >= 2) {
        final name = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();

        if (name == 'XSRF-TOKEN') {
          _xsrfToken = Uri.decodeComponent(value);
          await _storage.write(key: _xsrfTokenKey, value: _xsrfToken);
        } else if (name == 'kick_session') {
          _sessionToken = value;
          await _storage.write(key: _sessionTokenKey, value: _sessionToken);
        }
      }
    }
  }

  /// Login with extracted tokens (called after WebView login).
  @action
  Future<void> loginWithTokens({
    required String xsrfToken,
    required String sessionToken,
  }) async {
    try {
      _xsrfToken = xsrfToken;
      _sessionToken = sessionToken;

      // Store tokens
      await _storage.write(key: _xsrfTokenKey, value: xsrfToken);
      await _storage.write(key: _sessionTokenKey, value: sessionToken);

      // Initialize user
      await user.init();

      if (user.details != null) {
        _isLoggedIn = true;
        _stopReconnectLoop();
      }
    } catch (e) {
      debugPrint('Login failed: $e');
      _error = e.toString();
    }
  }

  /// Logs out the current user.
  @action
  Future<void> logout() async {
    try {
      _stopReconnectLoop();

      // Clear stored tokens
      await _clearStoredTokens();

      // Clear user info
      user.dispose();

      // Reset state
      _isLoggedIn = false;

      debugPrint('Successfully logged out');
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  /// Handle 401 Unauthorized responses.
  @action
  Future<void> handleUnauthorized() async {
    if (!_isLoggedIn) return;

    // Clear session and prompt re-login
    await _clearStoredTokens();
    _isLoggedIn = false;

    // Show login dialog
    _showLoginRequiredDialog();
  }

  /// Clear all stored tokens.
  Future<void> _clearStoredTokens() async {
    _xsrfToken = null;
    _sessionToken = null;
    await _storage.delete(key: _xsrfTokenKey);
    await _storage.delete(key: _sessionTokenKey);
    await _storage.delete(key: _userDataKey);
  }

  /// Show dialog prompting user to login.
  void _showLoginRequiredDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => FrostyDialog(
        title: 'Session Expired',
        message: 'Your session has expired. Please log in again.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login screen
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => _buildLoginScreen(),
                ),
              );
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  /// Build login screen with WebView.
  Widget _buildLoginScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to Kick')),
      body: WebViewWidget(controller: createAuthWebViewController()),
    );
  }

  /// Shows a dialog for blocking/unblocking users.
  Future<void> showBlockDialog(
    BuildContext context, {
    required String targetUser,
    required String targetUserId,
  }) {
    // TODO: Implement blocking for Kick
    // Kick's blocking API may differ from Twitch
    return showDialog(
      context: context,
      builder: (context) => FrostyDialog(
        title: 'Block User',
        message: 'Blocking is not yet implemented for Kick.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startReconnectLoop() {
    if (_reconnectTimer != null) return;
    _reconnectAttempts = 0;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        _reconnectAttempts++;
        if (_reconnectAttempts > _maxReconnectAttempts) {
          await logout();
          return;
        }

        // Check if we still have tokens
        final storedSession = await _storage.read(key: _sessionTokenKey);
        if (storedSession == null) {
          _stopReconnectLoop();
          return;
        }

        // Try to validate session
        await user.init();
        if (user.details != null) {
          _isLoggedIn = true;
          _error = null;
          _stopReconnectLoop();
        }
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          await logout();
        }
        // Otherwise continue trying
      } catch (e) {
        debugPrint('Reconnect loop error: $e');
      }
    });
  }

  void _stopReconnectLoop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }
}

/// Connection state enum for UI feedback.
enum ConnectionState {
  none,
  waiting,
  active,
  done,
}
