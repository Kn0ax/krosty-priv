import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/models/kick_message.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/screens/channel/chat/widgets/chat_message.dart';
import 'package:krosty/widgets/krosty_scrollbar.dart';
import 'package:krosty/widgets/section_header.dart';

class ReplyThread extends StatelessWidget {
  final KickChatMessage selectedMessage;
  final ChatStore chatStore;

  const ReplyThread({
    super.key,
    required this.selectedMessage,
    required this.chatStore,
  });

  @override
  Widget build(BuildContext context) {
    // Find the parent message being replied to
    final parentMessageId = selectedMessage.replyTo?.id;
    final replyParent = parentMessageId != null
        ? chatStore.messages.firstWhereOrNull(
            (message) => message.id == parentMessageId,
          )
        : null;

    final replyDisplayName = selectedMessage.metadata?.originalSender?.username;
    final replyBody = selectedMessage.replyTo?.content;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Observer(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(chatStore.settings.messageScale),
            ),
            child: DefaultTextStyle(
              style: DefaultTextStyle.of(
                context,
              ).style.copyWith(fontSize: chatStore.settings.fontSize),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SectionHeader(
                    'Replies',
                    isFirst: true,
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                  ),
                  if (replyParent != null)
                    ChatMessage(message: replyParent, chatStore: chatStore)
                  else if (replyDisplayName != null && replyBody != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text(
                        '$replyDisplayName: $replyBody',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  Flexible(
                    child: KrostyScrollbar(
                      child: ListView(
                        primary: false,
                        children: chatStore.messages
                            .where(
                              (message) =>
                                  message.replyTo?.id == parentMessageId,
                            )
                            .map(
                              (message) => ChatMessage(
                                isModal: true,
                                showReplyHeader: false,
                                isInReplyThread: true,
                                message: message,
                                chatStore: chatStore,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
