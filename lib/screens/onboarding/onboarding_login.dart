import 'package:flutter/material.dart';
import 'package:krosty/screens/onboarding/login_webview.dart';
import 'package:krosty/screens/onboarding/onboarding_scaffold.dart';
import 'package:krosty/screens/onboarding/onboarding_setup.dart';

class OnboardingLogin extends StatelessWidget {
  const OnboardingLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      header: 'Log in',
      subtitle:
          'Sign in to enable chat, view followed streams, and access more features.',
      disclaimer:
          'Connect your Kick account to unlock the full app experience. Your credentials are handled securely.',
      buttonText: 'Connect with Kick',
      buttonIcon: const Icon(Icons.login),
      skipRoute: const OnboardingSetup(),
      route: LoginWebView(routeAfter: const OnboardingSetup()),
    );
  }
}
