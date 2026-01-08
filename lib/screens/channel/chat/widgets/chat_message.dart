import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/constants.dart';
import 'package:krosty/models/kick_message.dart';
import 'package:krosty/models/kick_message_renderer.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/screens/channel/chat/widgets/chat_user_modal.dart';
import 'package:krosty/utils/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';

/// A widget that displays a single Kick chat message.
class ChatMessage extends StatelessWidget {
  final KickChatMessage message;
  final ChatStore chatStore;
  final bool isModal;
  final bool showReplyHeader;
  final bool isInReplyThread;

  const ChatMessage({
    super.key,
    required this.message,
    required this.chatStore,
    this.isModal = false,
    this.showReplyHeader = true,
    this.isInReplyThread = false,
  });

  void onTapName(BuildContext context) {
    if (isModal) return;

    // Ignore if tapping own username
    final currentUser = chatStore.auth.user.details?.username;
    if (message.sender.username == currentUser) return;

    showModalBottomSheetWithProperFocus(
      isScrollControlled: true,
      context: context,
      builder: (context) => ChatUserModal(
        chatStore: chatStore,
        username: message.sender.username,
        userId: message.sender.id.toString(),
        displayName: message.sender.username,
      ),
    );
  }

  void onTapPingedUser(BuildContext context, {required String nickname}) {
    if (isModal) return;

    final kickApi = context.read<KickApi>();
    kickApi.getChannel(channelSlug: nickname).then((channel) {
      if (context.mounted) {
        showModalBottomSheetWithProperFocus(
          isScrollControlled: true,
          context: context,
          builder: (context) => ChatUserModal(
            chatStore: chatStore,
            username: channel.slug,
            userId: channel.user.id.toString(),
            displayName: channel.user?.username ?? channel.slug,
          ),
        );
      }
    }).catchError((_) {
      // User not found, just ignore
    });
  }

  Future<void> copyMessage() async {
    await Clipboard.setData(ClipboardData(text: message.content));
    chatStore.updateNotification('Message copied');
  }

  void onLongPressMessage(BuildContext context, TextStyle defaultTextStyle) {
    HapticFeedback.lightImpact();

    if (message.isSystemMessage) {
      copyMessage();
      return;
    }

    showModalBottomSheetWithProperFocus(
      context: context,
      isScrollControlled: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        primary: false,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text.rich(
              TextSpan(
                children: message.generateSpan(
                  context,
                  assetsStore: chatStore.assetsStore,
                  emoteScale: chatStore.settings.emoteScale,
                  badgeScale: chatStore.settings.badgeScale,
                  launchExternal: chatStore.settings.launchUrlExternal,
                  timestamp: chatStore.settings.timestampType,
                ),
                style: defaultTextStyle,
              ),
            ),
          ),
          const Divider(indent: 12, endIndent: 12),
          ListTile(
            onTap: () {
              copyMessage();
              Navigator.pop(context);
            },
            leading: const Icon(Icons.copy),
            title: const Text('Copy message'),
          ),
          ListTile(
            onTap: () async {
              await copyMessage();

              final hasChatDelay =
                  chatStore.settings.showVideo &&
                  chatStore.settings.chatDelay > 0;

              if (hasChatDelay) {
                chatStore.updateNotification(
                  'Chatting is disabled due to message delay (${chatStore.settings.chatDelay.toInt()}s)',
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
                return;
              }

              chatStore.textController.text = message.content;
              chatStore.safeRequestFocus();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            leading: const Icon(Icons.content_paste),
            title: const Text('Copy message and paste'),
          ),
          ListTile(
            onTap: () {
              chatStore.replyingToMessage = message;
              chatStore.safeRequestFocus();
              Navigator.pop(context);
            },
            leading: const Icon(Icons.reply),
            title: const Text('Reply to message'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final messageHeaderIconSize =
        defaultBadgeSize * chatStore.settings.badgeScale;
    final messageHeaderTextColor = defaultTextStyle.color?.withValues(
      alpha: 0.5,
    );
    const messageHeaderFontWeight = FontWeight.w600;

    return Observer(
      builder: (context) {
        Color? highlightColor;
        final Widget renderMessage;

        // System messages (notices, connection status, etc.)
        if (message.isSystemMessage) {
          final noticeStyle = TextStyle(
            color: messageHeaderTextColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          );
          renderMessage = Text(message.content, style: noticeStyle);
        }
        // Deleted messages
        else if (message.isDeleted) {
          final showDeleted = chatStore.settings.showDeletedMessages ||
              chatStore.revealedMessageIds.contains(message.id);

          renderMessage = Opacity(
            opacity: 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                const Text(
                  'Message deleted',
                  style: TextStyle(fontWeight: messageHeaderFontWeight),
                ),
                Text.rich(
                  TextSpan(
                    children: message.generateSpan(
                      context,
                      onTapName: () => onTapName(context),
                      assetsStore: chatStore.assetsStore,
                      emoteScale: chatStore.settings.emoteScale,
                      badgeScale: chatStore.settings.badgeScale,
                      showMessage: showDeleted,
                      onTapDeletedMessage: () {
                        chatStore.revealMessage(message.id);
                      },
                      launchExternal: chatStore.settings.launchUrlExternal,
                      timestamp: chatStore.settings.timestampType,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        // Regular messages
        else {
          final messageSpan = Text.rich(
            TextSpan(
              children: message.generateSpan(
                context,
                onTapName: () => onTapName(context),
                onTapPingedUser: (nickname) =>
                    onTapPingedUser(context, nickname: nickname),
                style: defaultTextStyle,
                assetsStore: chatStore.assetsStore,
                emoteScale: chatStore.settings.emoteScale,
                badgeScale: chatStore.settings.badgeScale,
                launchExternal: chatStore.settings.launchUrlExternal,
                timestamp: chatStore.settings.timestampType,
              ),
            ),
          );

          // Check if the message is a reply
          Widget? messageHeaderIcon;
          Widget? messageHeader;

          if (message.isReply && showReplyHeader) {
            final replyTo = message.replyTo;
            messageHeaderIcon = Icon(
              Icons.chat_rounded,
              size: messageHeaderIconSize,
              color: messageHeaderTextColor,
            );
            messageHeader = Text.rich(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              TextSpan(
                children: [
                  TextSpan(
                    text: message.metadata?.originalSender?.username ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: messageHeaderTextColor,
                    ),
                  ),
                  TextSpan(
                    text: ': ${replyTo?.content ?? ''}',
                    style: TextStyle(color: messageHeaderTextColor),
                  ),
                ],
              ),
            );
          }

          if (messageHeader != null) {
            renderMessage = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                if (messageHeaderIcon != null)
                  Row(
                    spacing: 4,
                    children: [
                      messageHeaderIcon,
                      Flexible(child: messageHeader),
                    ],
                  )
                else
                  messageHeader,
                messageSpan,
              ],
            );
          } else {
            renderMessage = messageSpan;
          }
        }

        // Check if this is a reply message in reply thread context for indentation
        final isReplyInThread = isInReplyThread && message.isReply;

        // Add reply icon for messages in reply thread
        final messageWithIcon = isReplyInThread
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                    child: Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 16,
                      color: messageHeaderTextColor,
                    ),
                  ),
                  Expanded(child: renderMessage),
                ],
              )
            : renderMessage;

        final paddedMessage = Padding(
          padding: EdgeInsets.only(
            top: chatStore.settings.messageSpacing / 2,
            bottom: chatStore.settings.messageSpacing / 2,
            left: isReplyInThread ? 16 : (highlightColor == null ? 12 : 0),
            right: highlightColor == null ? 12 : 0,
          ),
          child: messageWithIcon,
        );

        // Add a divider above the message if dividers are enabled.
        final dividedMessage = chatStore.settings.showChatMessageDividers
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [paddedMessage, const Divider()],
              )
            : paddedMessage;

        // Color the message if the color has been set.
        final coloredMessage = highlightColor == null
            ? dividedMessage
            : Container(
                padding: const EdgeInsets.only(left: 8, right: 12),
                decoration: BoxDecoration(
                  color: highlightColor.withValues(alpha: 0.1),
                  border: Border(
                    left: BorderSide(color: highlightColor, width: 4),
                  ),
                ),
                child: dividedMessage,
              );

        final finalMessage = InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            if (chatStore.assetsStore.showEmoteMenu) {
              chatStore.assetsStore.showEmoteMenu = false;
            }
          },
          onLongPress: () => onLongPressMessage(context, defaultTextStyle),
          child: coloredMessage,
        );

        return finalMessage;
      },
    );
  }
}
