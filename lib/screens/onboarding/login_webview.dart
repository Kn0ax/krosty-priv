import 'package:flutter/material.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/widgets/krosty_app_bar.dart';
import 'package:krosty/widgets/krosty_dialog.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Reusable WebView widget for Kick OAuth login flow
class LoginWebView extends StatefulWidget {
  /// Optional widget to navigate to after successful login
  final Widget? routeAfter;

  const LoginWebView({super.key, this.routeAfter});

  @override
  State<LoginWebView> createState() => _LoginWebViewState();
}

class _LoginWebViewState extends State<LoginWebView> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Hide loading indicator after initial delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authStore = context.read<AuthStore>();
    final controller = authStore.createAuthWebViewController(
      routeAfter: widget.routeAfter,
    );

    return Scaffold(
      appBar: KrostyAppBar(
        title: const Text('Connect with Kick'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_rounded),
            onPressed: () => showDialog(
              context: context,
              builder: (context) {
                return KrostyDialog(
                  title: 'Login Help',
                  message:
                      'We need you to login to Kick to retrive your app token. Unfortunately, Kick does not provide an API for this, so we need to use a WebView to login. If you encounter any issues during login, try without a VPN or clear app data. Once logged in, you can return to the app.',
                  actions: [
                    TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (_isLoading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading Kick login...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
