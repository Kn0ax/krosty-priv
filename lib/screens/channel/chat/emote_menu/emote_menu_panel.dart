import 'package:flutter/material.dart';
import 'package:krosty/models/emotes.dart';
import 'package:krosty/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/widgets/frosty_page_view.dart';

class EmoteMenuPanel extends StatelessWidget {
  final ChatStore chatStore;
  final List<Emote>? emotes;

  const EmoteMenuPanel({
    super.key,
    required this.chatStore,
    this.emotes,
  });

  @override
  Widget build(BuildContext context) {
    if (emotes == null || emotes!.isEmpty) {
      return const Center(
        child: Text('No emotes available'),
      );
    }

    final globalEmotes = emotes!
        .where(
          (emote) =>
              emote.type == EmoteType.kickGlobal ||
              emote.type == EmoteType.sevenTVGlobal,
        )
        .toList();

    final channelEmotes = emotes!
        .where(
          (emote) =>
              emote.type == EmoteType.kickChannel ||
              emote.type == EmoteType.sevenTVChannel,
        )
        .toList();

    return FrostyPageView(
      headers: [if (channelEmotes.isNotEmpty) 'Channel', 'Global'],
      children: [
        if (channelEmotes.isNotEmpty)
          EmoteMenuSection(chatStore: chatStore, emotes: channelEmotes),
        EmoteMenuSection(chatStore: chatStore, emotes: globalEmotes),
      ],
    );
  }
}
