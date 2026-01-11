import 'package:flutter/material.dart';
import 'package:krosty/models/emotes.dart';
import 'package:krosty/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/widgets/frosty_page_view.dart';

/// Emote menu panel that shows emotes in categorized subtabs.
/// Detects whether it's displaying Kick or 7TV emotes based on the passed
/// emotes list, then shows appropriate subtabs:
/// - Kick: Channel / Global / [SubChannel1] / [SubChannel2] / ...
/// - 7TV: Channel / Global
class EmoteMenuPanel extends StatelessWidget {
  final ChatStore chatStore;
  final List<Emote>? emotes;

  const EmoteMenuPanel({super.key, required this.chatStore, this.emotes});

  @override
  Widget build(BuildContext context) {
    if (emotes == null || emotes!.isEmpty) {
      return const Center(child: Text('No emotes available'));
    }

    final assetsStore = chatStore.assetsStore;

    // Detect if this is a Kick panel or 7TV panel based on passed emotes
    final isKickPanel = emotes!.any(
      (e) => e.type == EmoteType.kickGlobal || e.type == EmoteType.kickChannel,
    );

    if (isKickPanel) {
      // Build Kick subtabs: Channel / Global / [SubChannel1] / [SubChannel2] / ...
      final kickChannelEmotes = assetsStore.kickChannelEmotesList;
      final kickGlobalEmotes = assetsStore.kickGlobalEmotesList;
      final userSubEmotesByChannel = assetsStore.userSubEmotesByChannel;

      final headers = <String>[];
      final children = <Widget>[];

      // 1. Channel emotes (current channel)
      if (kickChannelEmotes.isNotEmpty) {
        headers.add('Channel');
        children.add(
          EmoteMenuSection(chatStore: chatStore, emotes: kickChannelEmotes),
        );
      }

      // 2. Global emotes
      if (kickGlobalEmotes.isNotEmpty) {
        headers.add('Global');
        children.add(
          EmoteMenuSection(chatStore: chatStore, emotes: kickGlobalEmotes),
        );
      }

      // 3. User's subscribed channel emotes (each channel as separate tab)
      // Skip the current channel - it's already shown in "Channel" tab
      final currentChannelSlug = chatStore.channelSlug.toLowerCase();
      for (final entry in userSubEmotesByChannel.entries) {
        final channelName = entry.key;
        final channelEmotes = entry.value;
        // Skip if this is the current channel (case-insensitive comparison)
        if (channelName.toLowerCase() == currentChannelSlug) {
          continue;
        }
        if (channelEmotes.isNotEmpty) {
          headers.add(channelName);
          children.add(
            EmoteMenuSection(chatStore: chatStore, emotes: channelEmotes),
          );
        }
      }

      if (children.isEmpty) {
        return const Center(child: Text('No Kick emotes available'));
      }

      // If only one category has emotes, show it directly without tabs
      if (children.length == 1) {
        return children.first;
      }

      return FrostyPageView(headers: headers, children: children);
    } else {
      // Build 7TV subtabs: Channel / Global
      final sevenTVChannelEmotes = assetsStore.sevenTVChannelEmotesList;
      final sevenTVGlobalEmotes = assetsStore.sevenTVGlobalEmotesList;

      final headers = <String>[];
      final children = <Widget>[];

      if (sevenTVChannelEmotes.isNotEmpty) {
        headers.add('Channel');
        children.add(
          EmoteMenuSection(chatStore: chatStore, emotes: sevenTVChannelEmotes),
        );
      }
      if (sevenTVGlobalEmotes.isNotEmpty) {
        headers.add('Global');
        children.add(
          EmoteMenuSection(chatStore: chatStore, emotes: sevenTVGlobalEmotes),
        );
      }

      if (children.isEmpty) {
        return const Center(child: Text('No 7TV emotes available'));
      }

      // If only one category has emotes, show it directly without tabs
      if (children.length == 1) {
        return children.first;
      }

      return FrostyPageView(headers: headers, children: children);
    }
  }
}
