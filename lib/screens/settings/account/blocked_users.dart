import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/screens/settings/account/blocked_users_store.dart';
import 'package:krosty/widgets/krosty_dialog.dart';
import 'package:provider/provider.dart';

class BlockedUsers extends StatefulWidget {
  const BlockedUsers({super.key});

  @override
  State<BlockedUsers> createState() => _BlockedUsersState();
}

class _BlockedUsersState extends State<BlockedUsers> {
  late final BlockedUsersStore _store;
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store = BlockedUsersStore(context.read<KickApi>());
    _store.fetchBlockedUsers();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _showBlockUserDialog() {
    _usernameController.clear();
    showDialog(
      context: context,
      builder: (context) => KrostyDialog(
        title: 'Block User',
        message: 'Enter the username of the user you want to block.',
        content: TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.alternate_email),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (_usernameController.text.isNotEmpty) {
                final success = await _store.blockUser(_usernameController.text);
                if (context.mounted && success) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showBlockUserDialog,
        child: const Icon(Icons.add),
      ),
      body: Observer(
        builder: (context) {
          if (_store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_store.blockedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No blocked users',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: _store.blockedUsers.length,
            itemBuilder: (context, index) {
              final user = _store.blockedUsers[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(user.username),
                trailing: TextButton(
                  onPressed: () => _store.unblockUser(user.id),
                  child: const Text('Unblock'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
