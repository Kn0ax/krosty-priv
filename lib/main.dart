import 'dart:async';
import 'dart:convert';

import 'package:advanced_in_app_review/advanced_in_app_review.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:krosty/apis/dio_client.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/apis/kick_auth_interceptor.dart';
import 'package:krosty/apis/seventv_api.dart';
import 'package:krosty/cache_manager.dart';
import 'package:krosty/firebase_options.dart';
import 'package:krosty/screens/channel/channel.dart';
import 'package:krosty/screens/home/home.dart';
import 'package:krosty/screens/onboarding/onboarding_intro.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/stores/global_assets_store.dart';
import 'package:krosty/theme.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/widgets/alert_message.dart';
import 'package:mobx/mobx.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Flutter's image cache for better memory management on Android
  // Limit to 100 images and 100MB to prevent memory pressure
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;

  CustomCacheManager.removeOrphanedCacheFiles();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();

  final firstRun = prefs.getBool('first_run') ?? true;

  // Workaround for clearing stored tokens on uninstall.
  // If first time running app, will clear all tokens in the secure storage.
  // Run non-blocking to avoid ANR on slow Android devices (especially Android 14).
  if (firstRun) {
    debugPrint('Clearing secure storage...');
    const storage = FlutterSecureStorage();

    // Don't block - run in background after app starts.
    // This is safe because first run means no active session depends on this data.
    unawaited(
      storage.deleteAll().catchError((e) {
        debugPrint('Error clearing secure storage: $e');
      }),
    );
  }

  await initUtils();

  // With the shared preferences instance, obtain the existing user settings if it exists.
  // If default settings don't exist, use an empty JSON string to use the default values.
  final userSettings = prefs.getString('settings') ?? '{}';

  // Initialize a settings store from the settings JSON string.
  final settingsStore = SettingsStore.fromJson(jsonDecode(userSettings));

  // Create a MobX reaction that will save the settings on disk every time they are changed.
  autorun((_) => prefs.setString('settings', jsonEncode(settingsStore)));

  /// Initialize API services with a common Dio client.
  /// This will prevent every request from creating a new client instance.
  final dioClient = DioClient.createClient();

  // Create API services
  final kickApiService = KickApi(dioClient);
  final sevenTVApiService = SevenTVApi(dioClient);

  // Create global assets store (shared cache for global emotes)
  final globalAssetsStore = GlobalAssetsStore(
    kickApi: kickApiService,
    sevenTVApi: sevenTVApiService,
  );

  // Create and initialize the authentication store
  final authStore = AuthStore(kickApi: kickApiService);

  // Add the Kick auth interceptor to the Dio client after AuthStore creation
  dioClient.interceptors.add(KickAuthInterceptor(authStore));

  await authStore.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthStore>.value(value: authStore),
        Provider<SettingsStore>.value(value: settingsStore),
        Provider<KickApi>.value(value: kickApiService),
        Provider<SevenTVApi>.value(value: sevenTVApiService),
        Provider<GlobalAssetsStore>.value(value: globalAssetsStore),
      ],
      child: MyApp(firstRun: firstRun),
    ),
  );
}

// Navigator key for sleep timer. Allows navigation popping without context.
final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  final bool firstRun;

  const MyApp({super.key, this.firstRun = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();

    AdvancedInAppReview()
        .setMinDaysBeforeRemind(7)
        .setMinDaysAfterInstall(1)
        .setMinLaunchTimes(5)
        .setMinSecondsBeforeShowDialog(3)
        .monitor();

    _initDeepLinks();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final settingsStore = context.read<SettingsStore>();
        final themes = FrostyThemes(
          colorSchemeSeed: Color(settingsStore.accentColor),
        );

        return Provider<FrostyThemes>(
          create: (_) => themes,
          child: MaterialApp(
            title: 'Krosty',
            theme: themes.light,
            darkTheme: themes.dark,
            themeMode: settingsStore.themeType == ThemeType.system
                ? ThemeMode.system
                : settingsStore.themeType == ThemeType.light
                ? ThemeMode.light
                : ThemeMode.dark,
            home: widget.firstRun ? const OnboardingIntro() : const Home(),
            navigatorKey: navigatorKey,
          ),
        );
      },
    );
  }

  Future<void> _initDeepLinks() async {
    try {
      // Handle links when app is already open
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        handleDeepLink(uri);
      });

      // Handle the initial link if app was opened from a link.
      // Add timeout to prevent indefinite blocking on certain Android lifecycle states.
      final initialLink = await _appLinks.getInitialLink().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (initialLink != null) {
        handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Failed to initialize deep links: $e');
    }
  }

  Future<void> handleDeepLink(Uri uri) async {
    final failureSnackbar = SnackBar(
      content: AlertMessage(
        message: 'Unable to navigate to \'$uri\'',
        centered: false,
        trailingIcon: Icons.open_in_browser_rounded,
        // Fallback, allow user to open URL outside app
        onTrailingIconPressed: () async {
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView, // Force browser
          );
        },
      ),
    );

    // Handle channel links
    if (uri.pathSegments.isNotEmpty) {
      final channelName = uri.pathSegments.first;

      try {
        final kickApi = context.read<KickApi>();

        final channel = await kickApi.getChannel(channelSlug: channelName);

        final route = MaterialPageRoute(
          builder: (context) => VideoChat(
            userId: channel.id.toString(),
            userName: channel.displayName,
            userLogin: channel.slug,
          ),
        );

        if (navigatorKey.currentState == null) return;

        WidgetsBinding.instance.addPostFrameCallback(
          (_) => navigatorKey.currentState?.push(route),
        );
      } catch (e) {
        // If we get here, there was most likely an error with the Kick API call and/or this isn't really a channel link
        debugPrint('Failed to open link $uri due to error: $e');

        if (navigatorKey.currentContext == null) return;
        ScaffoldMessenger.of(
          navigatorKey.currentContext!,
        ).showSnackBar(failureSnackbar);
      }
    }
    // TODO: Here we can implement handlers for other types of links
    else {
      // If we get here, it's a link format that we're unable to handle
      if (navigatorKey.currentContext == null) return;
      ScaffoldMessenger.of(
        navigatorKey.currentContext!,
      ).showSnackBar(failureSnackbar);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
}
