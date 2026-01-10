import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:krosty/apis/base_api_client.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/main.dart';
import 'package:krosty/screens/settings/stores/user_store.dart';
import 'package:krosty/widgets/frosty_dialog.dart';
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

  /// Timer for periodically checking cookies during login flow.
  Timer? _cookieCheckTimer;

  /// Flag to track if login button has been auto-clicked.
  var _loginButtonClicked = false;

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

    debugPrint(
      '🏗️ Building headers - sessionToken: ${_sessionToken != null ? "SET (${_sessionToken!.substring(0, 10)}...)" : "NULL"}, xsrfToken: ${_xsrfToken != null ? "SET" : "NULL"}',
    );

    // Use Bearer token authorization (matching Moblin's implementation)
    if (_sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
      debugPrint('✅ Added Authorization header');
    } else {
      debugPrint('⚠️ No session token available for Authorization header');
    }

    // Also include XSRF token for state-changing operations
    if (_xsrfToken != null) {
      headers['X-XSRF-TOKEN'] = _xsrfToken!;
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
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Use platform-specific user agents to allow Google OAuth sign-in.
      // Google blocks OAuth in embedded WebViews (error 403: disallowed_useragent)
      // by detecting WebView markers. These standard browser UAs work around that.
      ..setUserAgent(
        Platform.isIOS
            ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1'
            : 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36',
      );

    // Reset state for new login flow
    _loginButtonClicked = false;
    _stopCookieCheckTimer();

    return webViewController
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            debugPrint('🔐 [AUTH] ' + 'Navigation request: ${request.url}');
            return _handleNavigation(request: request, routeAfter: routeAfter);
          },
          onWebResourceError: (error) {
            debugPrint(
              '🔐 [AUTH] ' +
                  'WebView error: ${error.description} (${error.errorCode})',
            );
          },
          onPageStarted: (url) {
            debugPrint('🔐 [AUTH] ' + 'Page started loading: $url');
          },
          onPageFinished: (url) async {
            debugPrint('🔐 [AUTH] ' + 'Page finished loading: $url');

            // Auto-click login button if we're on the login page
            if (url.contains('kick.com/login') && !_loginButtonClicked) {
              debugPrint(
                '🔐 [AUTH] ' + 'On login page, attempting auto-click...',
              );
              await _autoClickLoginButton(webViewController);
            }
            // Start periodic cookie checking once page is loaded
            if (url.contains('kick.com')) {
              _startCookieCheckTimer(webViewController, routeAfter);
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

  /// Auto-click the login button to advance to the login form.
  /// Inspired by Moblin's approach for better UX.
  Future<void> _autoClickLoginButton(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult('''
        (async function() {
          try {
            // Wait for 200ms for the page to load
            await new Promise(resolve => setTimeout(resolve, 200));
            var loginButton = document.querySelector('[data-testid="login"]');
            if (loginButton) {
              loginButton.click();
              return true;
            }
            return false;
          } catch (error) {
            return false;
          }
        })();
      ''');

      final clicked = result.toString().toLowerCase() == 'true';
      if (clicked) {
        _loginButtonClicked = true;
        debugPrint('Auto-clicked login button');
      }
    } catch (e) {
      debugPrint('Failed to auto-click login button: $e');
    }
  }

  /// Start periodic timer to check for authentication cookies.
  /// Checks every 1 second, inspired by Moblin's implementation.
  void _startCookieCheckTimer(
    WebViewController controller,
    Widget? routeAfter,
  ) {
    // Stop any existing timer
    _stopCookieCheckTimer();

    _cookieCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _checkForAuthCookies(controller, routeAfter);
    });
  }

  /// Stop the periodic cookie check timer.
  void _stopCookieCheckTimer() {
    _cookieCheckTimer?.cancel();
    _cookieCheckTimer = null;
  }

  /// Check for authentication cookies in the WebView.
  Future<void> _checkForAuthCookies(
    WebViewController controller,
    Widget? routeAfter,
  ) async {
    try {
      // Get cookies from document.cookie
      final result = await controller.runJavaScriptReturningResult(
        'document.cookie',
      );

      final cookieString = result.toString();
      // Remove quotes if present (JS returns quoted string)
      final cleanCookies = cookieString.replaceAll('"', '');

      // Check for auth cookies
      final hasSessionToken = cleanCookies.contains('session_token=');
      final hasKickSession = cleanCookies.contains('kick_session=');

      if (hasSessionToken || hasKickSession) {
        debugPrint('🔐 [AUTH] ✅ Found auth cookie! Parsing...');

        // Parse and store cookies
        await _parseCookies(cleanCookies);

        // Validate session by fetching user info
        if (_sessionToken != null) {
          try {
            await user.init();

            if (user.details != null) {
              _isLoggedIn = true;
              _error = null;
              _stopCookieCheckTimer();

              debugPrint(
                '🔐 [AUTH] ✅ SUCCESS! User authenticated: ${user.details!.username}',
              );

              // Navigate away from login
              if (routeAfter != null) {
                navigatorKey.currentState?.pop();
                navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (context) => routeAfter),
                );
              } else {
                navigatorKey.currentState?.pop();
              }
            } else {
              debugPrint(
                '🔐 [AUTH] ❌ User details is null after init - API call may have failed',
              );
            }
          } catch (e, stack) {
            debugPrint('🔐 [AUTH] ❌ Error during user.init(): $e');
            debugPrint('🔐 [AUTH] Stack trace: $stack');
          }
        }
      }
    } catch (e, stack) {
      debugPrint('🔐 [AUTH] ❌ Cookie check error: $e');
      debugPrint('🔐 [AUTH] Stack: $stack');
      // Continue checking, don't stop on errors
    }
  }

  /// Extract cookies from WebView after successful login.
  /// This is now a fallback method, with periodic checking being primary.
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
      final cleanJson = jsonStr.startsWith('"') ? jsonDecode(jsonStr) : jsonStr;
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
      final trimmed = cookie.trim();
      if (trimmed.isEmpty) continue;

      final equalsIndex = trimmed.indexOf('=');
      if (equalsIndex == -1) continue;

      final name = trimmed.substring(0, equalsIndex).trim();
      final value = trimmed.substring(equalsIndex + 1).trim();

      if (name == 'XSRF-TOKEN') {
        try {
          _xsrfToken = Uri.decodeComponent(value);
          await _storage.write(key: _xsrfTokenKey, value: _xsrfToken);
        } catch (e) {
          debugPrint('🔐 [AUTH] ❌ Failed to decode XSRF token: $e');
        }
      } else if (name == 'session_token') {
        try {
          _sessionToken = Uri.decodeComponent(value);
          await _storage.write(key: _sessionTokenKey, value: _sessionToken);
        } catch (e) {
          debugPrint('🔐 [AUTH] ❌ Failed to decode session_token: $e');
        }
      } else if (name == 'kick_session') {
        try {
          _sessionToken = Uri.decodeComponent(value);
          await _storage.write(key: _sessionTokenKey, value: _sessionToken);
        } catch (e) {
          debugPrint('🔐 [AUTH] ❌ Failed to decode kick_session: $e');
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
      _stopCookieCheckTimer();

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
                MaterialPageRoute(builder: (context) => _buildLoginScreen()),
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
    return showDialog(
      context: context,
      builder: (context) => FrostyDialog(
        title: 'Block User',
        message: 'Are you sure you want to block $targetUser?',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final success = await kickApi.blockUser(username: targetUser);
                if (success) {
                  // Refresh global blocked list
                  await user.fetchBlockedUsers();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Blocked $targetUser')),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to block $targetUser')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Block'),
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
enum ConnectionState { none, waiting, active, done }
