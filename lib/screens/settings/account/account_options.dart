import 'package:flutter/material.dart';
import 'package:krosty/screens/channel/channel.dart';
import 'package:krosty/screens/settings/account/blocked_users.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/widgets/settings_tile_route.dart';
import 'package:krosty/widgets/krosty_dialog.dart';
import 'package:krosty/widgets/krosty_scrollbar.dart';

class AccountOptions extends StatelessWidget {
  final AuthStore authStore;

  const AccountOptions({super.key, required this.authStore});

  Future<void> _showLogoutDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => KrostyDialog(
        title: 'Log out',
        message: 'Are you sure you want to log out?',
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              authStore.logout();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KrostyScrollbar(
      child: ListView(
        shrinkWrap: true,
        primary: false,
        children: [
          SettingsTileRoute(
            leading: const Icon(Icons.person_rounded),
            title: 'My channel',
            useScaffold: false,
            child: VideoChat(
              userId: authStore.user.details!.id.toString(),
              userName: authStore.user.details!.displayName,
              userLogin: authStore.user.details!.username,
            ),
          ),
          SettingsTileRoute(
            leading: const Icon(Icons.block_rounded),
            title: 'Blocked users',
            child: const BlockedUsers(),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Log out'),
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }
}
