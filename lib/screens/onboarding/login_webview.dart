import 'package:flutter/material.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/widgets/frosty_app_bar.dart';
import 'package:krosty/widgets/frosty_dialog.dart';
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
      appBar: FrostyAppBar(
        title: const Text('Connect with Kick'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_rounded),
            onPressed: () => showDialog(
              context: context,
              builder: (context) {
                return FrostyDialog(
                  title: 'Login Help',
                  message:
                      'If you encounter any issues during login, try clearing your browser cache or using a different browser. Once logged in, you can return to the app.',
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
