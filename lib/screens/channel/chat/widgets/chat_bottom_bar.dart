import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/constants.dart';
import 'package:krosty/models/kick_message_renderer.dart';
import 'package:krosty/screens/channel/chat/details/chat_details.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/utils/context_extensions.dart';
import 'package:krosty/utils/modal_bottom_sheet.dart';
import 'package:krosty/widgets/blurred_container.dart';
import 'package:krosty/widgets/chat_input/emote_text_span_builder.dart';
import 'package:krosty/widgets/krosty_cached_network_image.dart';

class ChatBottomBar extends StatelessWidget {
  final ChatStore chatStore;

  /// Callback to add a new chat tab.
  /// Passes this to ChatDetails to show "Add chat" option.
  final VoidCallback onAddChat;

  const ChatBottomBar({
    super.key,
    required this.chatStore,
    required this.onAddChat,
  });

  @override
  Widget build(BuildContext context) {
    final isEmotesEnabled =
        chatStore.settings.showKickEmotes || chatStore.settings.show7TVEmotes;

    final emoteMenuButton = isEmotesEnabled
        ? Tooltip(
            message: 'Emote menu',
            preferBelow: false,
            child: IconButton(
              color: chatStore.assetsStore.showEmoteMenu
                  ? Theme.of(context).colorScheme.secondary
                  : null,
              icon: Icon(
                chatStore.assetsStore.showEmoteMenu
                    ? Icons.emoji_emotions_rounded
                    : Icons.emoji_emotions_outlined,
              ),
              onPressed: () {
                chatStore.unfocusInput();
                chatStore.assetsStore.showEmoteMenu =
                    !chatStore.assetsStore.showEmoteMenu;
              },
            ),
          )
        : null;

    return Observer(
      builder: (context) {
        final matchingEmotes = chatStore.matchingEmotes;
        final matchingChatters = chatStore.matchingChatters;

        final isFullscreenOverlay =
            chatStore.settings.fullScreen && context.isLandscape;

        // Check if chat delay is active (for indicator only, doesn't block input)
        final hasChatDelay =
            chatStore.settings.showVideo && chatStore.settings.chatDelay > 0;

        const loginTooltipMessage = 'Log in to chat';

        final isCollapsedMode =
            !chatStore.expandChat &&
            chatStore.settings.chatWidth < 0.3 &&
            chatStore.settings.showVideo &&
            context.isLandscape;

        final sendOrMoreButton = TextFieldTapRegion(
          child:
              chatStore.showSendButton &&
                  (chatStore.settings.chatWidth >= 0.3 ||
                      chatStore.expandChat ||
                      context.isPortrait)
              ? Observer(
                  builder: (context) {
                    final canSend = chatStore.auth.isLoggedIn &&
                        !chatStore.isWaitingForAck &&
                        chatStore.isConnected &&
                        !chatStore.isChatBlocked &&
                        !chatStore.isSlowModeActive;

                    String getTooltip() {
                      if (chatStore.isWaitingForAck) return 'Sending...';
                      if (chatStore.isChatBlocked) {
                        return chatStore.chatBlockedReason ?? 'Chat blocked';
                      }
                      if (chatStore.isSlowModeActive) {
                        return 'Slow mode (${chatStore.slowModeSecondsRemaining}s)';
                      }
                      return 'Send';
                    }

                    return IconButton(
                      tooltip: getTooltip(),
                      icon: chatStore.isWaitingForAck
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : chatStore.isSlowModeActive
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(Icons.send_rounded),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '${chatStore.slowModeSecondsRemaining}',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Icon(Icons.send_rounded),
                      onPressed: canSend
                          ? () => chatStore.sendMessage(
                                chatStore.textController.text,
                              )
                          : null,
                    );
                  },
                )
              : IconButton(
                  icon: Icon(Icons.adaptive.more_rounded),
                  tooltip: 'More',
                  onPressed: () => showModalBottomSheetWithProperFocus(
                    isScrollControlled: true,
                    context: context,
                    builder: (_) => ChatDetails(
                      chatDetailsStore: chatStore.chatDetailsStore,
                      chatStore: chatStore,
                      userLogin: chatStore.channelSlug,
                      onAddChat: onAddChat,
                    ),
                  ),
                ),
        );

        final bottomBarContent = Column(
          children: [
            if (chatStore.replyingToMessage != null) ...[
              const Divider(),
              TextFieldTapRegion(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                        width: 4,
                      ),
                    ),
                  ),
                  // Left: 8px so text aligns at 12px (4px border + 8px padding)
                  // Right: 4px to give close button some breathing room
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: chatStore.replyingToMessage!.content,
                          preferBelow: false,
                          child: Text.rich(
                            TextSpan(
                              children: chatStore.replyingToMessage!
                                  .generateSpan(
                                    context,
                                    assetsStore: chatStore.assetsStore,
                                    emoteScale: chatStore.settings.emoteScale,
                                    badgeScale: chatStore.settings.badgeScale,
                                    launchExternal:
                                        chatStore.settings.launchUrlExternal,
                                    timestamp: chatStore.settings.timestampType,
                                  ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.defaultTextStyle.copyWith(
                              fontSize: chatStore.settings.fontSize,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel reply',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => chatStore.replyingToMessage = null,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Wrap autocomplete sections with TextFieldTapRegion so taps
            // on them don't trigger TextField's onTapOutside callback.
            if (chatStore.settings.autocomplete &&
                chatStore.showEmoteAutocomplete &&
                matchingEmotes.isNotEmpty) ...[
              const Divider(),
              TextFieldTapRegion(
                child: SizedBox(
                  height: 50,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: matchingEmotes.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) => InkWell(
                      onTap: () => chatStore.addEmote(
                        matchingEmotes[index],
                        autocompleteMode: true,
                      ),
                      onLongPress: () {
                        HapticFeedback.lightImpact();

                        showEmoteDetailsBottomSheet(
                          context,
                          emote: matchingEmotes[index],
                          launchExternal: chatStore.settings.launchUrlExternal,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Center(
                          child: KrostyCachedNetworkImage(
                            imageUrl: matchingEmotes[index].url,
                            useFade: false,
                            height:
                                matchingEmotes[index].height?.toDouble() ??
                                defaultEmoteSize,
                            width: matchingEmotes[index].width?.toDouble(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (chatStore.settings.autocomplete &&
                chatStore.showMentionAutocomplete &&
                matchingChatters.isNotEmpty) ...[
              const Divider(),
              TextFieldTapRegion(
                child: SizedBox(
                  height: 50,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: matchingChatters.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) => TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        final split = chatStore.textController.text.split(' ')
                          ..removeLast()
                          ..add('@${matchingChatters[index]} ');

                        chatStore.textController.text = split.join(' ');
                        chatStore.textController.selection =
                            TextSelection.fromPosition(
                              TextPosition(
                                offset: chatStore.textController.text.length,
                              ),
                            );
                      },
                      child: Text(matchingChatters[index]),
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
              child: Row(
                children: [
                  if (isCollapsedMode)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Builder(
                          builder: (context) {
                            final isDisabled = !chatStore.auth.isLoggedIn;

                            return GestureDetector(
                              onTap: isDisabled
                                  ? () {
                                      chatStore.updateNotification(
                                        loginTooltipMessage,
                                      );
                                    }
                                  : null,
                              child: IconButton(
                                tooltip: 'Enter a message',
                                onPressed: isDisabled
                                    ? null
                                    : () {
                                        chatStore.expandChat = true;
                                        chatStore.safeRequestFocus();
                                      },
                                icon: const Icon(Icons.edit),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Observer(
                        builder: (context) {
                          final isLoggedIn = chatStore.auth.isLoggedIn;
                          final isWaitingForAck = chatStore.isWaitingForAck;
                          final isConnected = chatStore.isConnected;
                          final hasConnected = chatStore.hasConnected;
                          final isChatBlocked = chatStore.isChatBlocked;
                          final chatBlockedReason = chatStore.chatBlockedReason;
                          final isSlowModeActive = chatStore.isSlowModeActive;
                          final slowModeSeconds =
                              chatStore.slowModeSecondsRemaining;
                          final isEnabled = isLoggedIn &&
                              !isWaitingForAck &&
                              isConnected &&
                              !isChatBlocked;

                          String getHintText() {
                            if (!isLoggedIn) return loginTooltipMessage;
                            if (!isConnected) {
                              return hasConnected
                                  ? 'Chat disconnected'
                                  : 'Connecting...';
                            }
                            if (chatBlockedReason != null) {
                              return chatBlockedReason;
                            }
                            if (isWaitingForAck) return 'Sending...';
                            if (isSlowModeActive) {
                              return 'Slow mode (${slowModeSeconds}s)';
                            }
                            if (chatStore.replyingToMessage != null) {
                              return 'Reply';
                            }
                            if (hasChatDelay) {
                              return 'Chat (${chatStore.settings.chatDelay.toInt()}s delay)';
                            }
                            return 'Chat';
                          }

                          return GestureDetector(
                            onTap: !isLoggedIn
                                ? () {
                                    chatStore.updateNotification(
                                      loginTooltipMessage,
                                    );
                                  }
                                : isChatBlocked && chatBlockedReason != null
                                    ? () {
                                        chatStore.updateNotification(
                                          chatBlockedReason,
                                        );
                                      }
                                    : null,
                            child: ExtendedTextField(
                              textInputAction: TextInputAction.send,
                              focusNode: chatStore.textFieldFocusNode,
                              minLines: 1,
                              maxLines: 3,
                              enabled: isEnabled,
                              specialTextSpanBuilder: EmoteTextSpanBuilder(
                                emoteToObject:
                                    chatStore.assetsStore.emoteToObject,
                                userEmoteToObject:
                                    chatStore.assetsStore.userEmoteToObject,
                                emoteSize:
                                    chatStore.settings.emoteScale *
                                    defaultEmoteSize,
                              ),
                              decoration: InputDecoration(
                                prefixIcon:
                                    chatStore.settings.emoteMenuButtonOnLeft
                                        ? emoteMenuButton
                                        : null,
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 8,
                                  children: [
                                    if (!chatStore
                                            .settings.emoteMenuButtonOnLeft &&
                                        emoteMenuButton != null)
                                      emoteMenuButton,
                                  ],
                                ),
                                hintMaxLines: 1,
                                hintText: getHintText(),
                              ),
                              controller: chatStore.textController,
                              onSubmitted: chatStore.sendMessage,
                              onTapOutside: (_) {
                                chatStore.textFieldFocusNode.unfocus();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  if (isCollapsedMode)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: sendOrMoreButton,
                      ),
                    )
                  else
                    sendOrMoreButton,
                ],
              ),
            ),
          ],
        );

        // Don't add bottom padding when:
        // - Emote menu is open: The emote menu provides its own bottom boundary
        // - In horizontal landscape mode: System is in immersive mode and home
        //   indicator is on the side (left/right), not the content bottom.
        //   SafeArea handles left/right insets for the notch.
        // Note: landscapeForceVerticalChat uses portrait layout in landscape
        // orientation with normal (non-immersive) system UI, so it still needs
        // bottom padding.
        final isHorizontalLandscape =
            context.isLandscape &&
            !chatStore.settings.landscapeForceVerticalChat;
        final needsBottomPadding =
            !chatStore.assetsStore.showEmoteMenu && !isHorizontalLandscape;

        return isFullscreenOverlay
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: needsBottomPadding
                      ? MediaQuery.of(context).padding.bottom
                      : 0,
                ),
                child: bottomBarContent,
              )
            : BlurredContainer(
                gradientDirection: GradientDirection.down,
                padding: EdgeInsets.only(
                  bottom: needsBottomPadding
                      ? MediaQuery.of(context).padding.bottom
                      : 0,
                ),
                child: bottomBarContent,
              );
      },
    );
  }
}
