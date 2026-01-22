import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/widgets/blurred_container.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class UserActionsModal extends StatefulWidget {
  final AuthStore authStore;
  final String name;
  final String userLogin;
  final String userId;
  final bool showPinOption;
  final bool? isPinned;

  const UserActionsModal({
    super.key,
    required this.authStore,
    required this.name,
    required this.userLogin,
    required this.userId,
    this.showPinOption = false,
    this.isPinned,
  });

  @override
  State<UserActionsModal> createState() => _UserActionsModalState();
}

class _UserActionsModalState extends State<UserActionsModal> {
  bool? _isFollowing;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.authStore.isLoggedIn) {
      _checkFollowStatus();
    }
  }

  Future<void> _checkFollowStatus() async {
    final isFollowing = await widget.authStore.user.isFollowing(
      channelSlug: widget.userLogin,
    );
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowing == null) return;

    setState(() => _isLoading = true);

    final bool success;
    if (_isFollowing!) {
      success = await widget.authStore.user.unfollow(
        channelSlug: widget.userLogin,
      );
    } else {
      success = await widget.authStore.user.follow(
        channelSlug: widget.userLogin,
      );
    }

    if (mounted) {
      setState(() {
        // Only toggle follow state if the API call succeeded
        if (success) {
          _isFollowing = !_isFollowing!;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: false,
      shrinkWrap: true,
      children: [
        if (widget.showPinOption)
          ListTile(
            leading: const Icon(Icons.push_pin_outlined),
            title: Text(
              '${widget.isPinned == true ? 'Unpin' : 'Pin'} ${widget.name}',
            ),
            onTap: () {
              if (widget.isPinned == true) {
                context.read<SettingsStore>().pinnedChannelIds = [
                  ...context.read<SettingsStore>().pinnedChannelIds
                    ..remove(widget.userId),
                ];
              } else {
                context.read<SettingsStore>().pinnedChannelIds = [
                  ...context.read<SettingsStore>().pinnedChannelIds,
                  widget.userId,
                ];
              }

              Navigator.pop(context);
            },
          ),
        if (widget.authStore.isLoggedIn)
          ListTile(
            leading: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isFollowing == true
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    color: _isFollowing == true ? Colors.red : null,
                  ),
            title: Text(
              _isFollowing == true
                  ? 'Unfollow ${widget.name}'
                  : 'Follow ${widget.name}',
            ),
            onTap: _isLoading ? null : _toggleFollow,
          ),
        if (widget.authStore.isLoggedIn)
          ListTile(
            leading: const Icon(Icons.block_rounded),
            onTap: () => widget.authStore
                .showBlockDialog(
                  context,
                  targetUser: widget.name,
                  targetUserId: widget.userId,
                )
                .then((_) {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }),
            title: Text('Block ${widget.name}'),
          ),
        ListTile(
          leading: const Icon(Icons.outlined_flag_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                final theme = Theme.of(context);

                return Scaffold(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  extendBody: true,
                  extendBodyBehindAppBar: true,
                  appBar: AppBar(
                    centerTitle: false,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness:
                          theme.brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark,
                    ),
                    leading: IconButton(
                      tooltip: 'Back',
                      icon: Icon(Icons.adaptive.arrow_back_rounded),
                      onPressed: Navigator.of(context).pop,
                    ),
                    title: Text('Report ${widget.name}'),
                  ),
                  body: Stack(
                    children: [
                      // WebView content
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top:
                                MediaQuery.of(context).padding.top +
                                kToolbarHeight,
                          ),
                          child: WebViewWidget(
                            controller: WebViewController()
                              ..setJavaScriptMode(JavaScriptMode.unrestricted)
                              ..loadRequest(
                                Uri.parse(
                                  'https://kick.com/${widget.userLogin}/report',
                                ),
                              )
                              ..setNavigationDelegate(
                                NavigationDelegate(
                                  onWebResourceError: (error) {
                                    debugPrint(
                                      'WebView error: ${error.description}',
                                    );
                                  },
                                ),
                              ),
                          ),
                        ),
                      ),
                      // Blurred app bar overlay
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: BlurredContainer(
                          gradientDirection: GradientDirection.up,
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top,
                            left: MediaQuery.of(context).padding.left,
                            right: MediaQuery.of(context).padding.right,
                          ),
                          child: const SizedBox(height: kToolbarHeight),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          title: Text('Report ${widget.name}'),
        ),
      ],
    );
  }
}
