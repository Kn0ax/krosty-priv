import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/constants.dart';
import 'package:krosty/models/kick_message_renderer.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/utils/context_extensions.dart';
import 'package:krosty/widgets/alert_message.dart';
import 'package:krosty/widgets/krosty_cached_network_image.dart';
import 'package:krosty/widgets/krosty_dialog.dart';
import 'package:provider/provider.dart';

class RecentEmotesPanel extends StatelessWidget {
  final ChatStore chatStore;

  const RecentEmotesPanel({super.key, required this.chatStore});

  Future<void> _showClearDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => KrostyDialog(
        title: 'Clear recent emotes',
        message: 'Are you sure you want to clear your recent emotes?',
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              chatStore.assetsStore.recentEmotes.clear();
              chatStore.updateNotification('Recent emotes cleared');

              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: CustomScrollView(
            slivers: [
              if (chatStore.assetsStore.recentEmotes.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AlertMessage(message: 'No recent emotes'),
                )
              else
                SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: context.isPortrait
                        ? 8
                        : context.read<SettingsStore>().showVideo
                        ? 6
                        : 16,
                  ),
                  itemBuilder: (context, index) {
                    final emote = chatStore.assetsStore.recentEmotes[index];
                    final validEmotes = [
                      ...chatStore.assetsStore.emoteToObject.values,
                      ...chatStore.assetsStore.userEmoteToObject.values,
                    ];
                    final matchingEmotes = validEmotes.where(
                      (existingEmote) =>
                          existingEmote.name == emote.name &&
                          existingEmote.type == emote.type,
                    );

                    return InkWell(
                      onTap: matchingEmotes.isNotEmpty
                          ? () => chatStore.addEmote(emote)
                          : null,
                      onLongPress: () {
                        HapticFeedback.lightImpact();

                        showEmoteDetailsBottomSheet(
                          context,
                          emote: emote,
                          launchExternal: chatStore.settings.launchUrlExternal,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: KrostyCachedNetworkImage(
                            imageUrl: matchingEmotes.isNotEmpty
                                ? matchingEmotes.first.url
                                : emote.url,
                            color: matchingEmotes.isNotEmpty
                                ? null
                                : const Color.fromRGBO(255, 255, 255, 0.5),
                            colorBlendMode: matchingEmotes.isNotEmpty
                                ? null
                                : BlendMode.modulate,
                            height:
                                emote.height?.toDouble() ?? defaultEmoteSize,
                            width: emote.width?.toDouble(),
                          ),
                        ),
                      ),
                    );
                  },
                  itemCount: chatStore.assetsStore.recentEmotes.length,
                ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _showClearDialog(context),
                          icon: const Icon(Icons.clear_all_rounded),
                          label: const Text('Clear recent emotes'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
