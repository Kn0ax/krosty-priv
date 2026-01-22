import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/screens/channel/chat/emote_menu/emote_menu_panel.dart';
import 'package:krosty/screens/channel/chat/emote_menu/recent_emotes_panel.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/screens/channel/chat/widgets/chat_bottom_bar.dart';
import 'package:krosty/screens/channel/chat/widgets/chat_message.dart';
import 'package:krosty/screens/channel/chat/widgets/dismissible_panel.dart';
import 'package:krosty/screens/channel/chat/widgets/pinned_message_panel.dart';
import 'package:krosty/screens/channel/chat/widgets/poll_panel.dart';
import 'package:krosty/screens/channel/chat/widgets/prediction_panel.dart';
import 'package:krosty/screens/channel/video/video_store.dart';
import 'package:krosty/utils/context_extensions.dart';
import 'package:krosty/widgets/krosty_page_view.dart';
import 'package:krosty/widgets/krosty_scrollbar.dart';

class Chat extends StatelessWidget {
  final ChatStore chatStore;
  final EdgeInsetsGeometry? listPadding;

  /// Callback to add a new chat tab.
  /// Passes this to ChatBottomBar for the ChatDetails menu.
  final VoidCallback onAddChat;

  /// Optional video store for VOD playback.
  final VideoStore? videoStore;

  const Chat({
    super.key,
    required this.chatStore,
    this.listPadding,
    required this.onAddChat,
    this.videoStore,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return Column(
          children: [
            Expanded(
              child: Stack(
                alignment: AlignmentDirectional.bottomCenter,
                children: [
                  // Wrap only the message list with GestureDetector
                  // so taps on ChatBottomBar don't trigger unfocus
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (chatStore.assetsStore.showEmoteMenu) {
                        chatStore.assetsStore.showEmoteMenu = false;
                      } else if (chatStore.textFieldFocusNode.hasFocus) {
                        chatStore.unfocusInput();
                      }
                    },
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: chatStore.settings.messageScale.textScaler,
                      ),
                      child: DefaultTextStyle(
                        style: context.defaultTextStyle.copyWith(
                          fontSize: chatStore.settings.fontSize,
                        ),
                        child: Builder(
                          builder: (context) {
                            // Don't add bottom padding in horizontal landscape
                            // (immersive mode with home indicator on side).
                            // landscapeForceVerticalChat uses portrait layout
                            // with normal system UI, so still needs padding.
                            final isHorizontalLandscape =
                                context.isLandscape &&
                                !chatStore.settings.landscapeForceVerticalChat;
                            final bottomPadding =
                                chatStore.assetsStore.showEmoteMenu ||
                                    isHorizontalLandscape
                                ? 0.0
                                : MediaQuery.of(context).padding.bottom;

                            return KrostyScrollbar(
                              controller: chatStore.scrollController,
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top,
                                bottom:
                                    chatStore.bottomBarHeight + bottomPadding,
                              ),
                              child: Observer(
                                builder: (context) {
                                  final messages = chatStore.renderMessages;
                                  return ListView.builder(
                                    reverse: true,
                                    padding: (listPadding ?? EdgeInsets.zero)
                                        .add(
                                          EdgeInsets.only(
                                            bottom:
                                                chatStore.bottomBarHeight +
                                                bottomPadding,
                                          ),
                                        ),
                                    addAutomaticKeepAlives: false,
                                    addRepaintBoundaries: false,
                                    controller: chatStore.scrollController,
                                    itemCount: messages.length,
                                    // Estimate item extent for better scroll performance
                                    itemExtent: null,
                                    cacheExtent: 1500,
                                    itemBuilder: (context, index) {
                                      // Reverse index for correct display
                                      final message =
                                          messages[messages.length - 1 - index];

                                      // Ensure we are passing a KickChatMessage
                                      return ChatMessage(
                                        key: ValueKey(message.id),
                                        message: message,
                                        chatStore: chatStore,
                                      );
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // Prevents accidental chat scrolling when swiping down from the top edge
                  // to access system UI (Notification Center/Control Center) in landscape mode.
                  if (context.isLandscape)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 24,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragStart: (_) {},
                      ),
                    ),

                  // Event panels (pinned message, poll, prediction)
                  Positioned(
                    top: MediaQuery.of(context).padding.top,
                    left: 0,
                    right: 0,
                    child: Observer(
                      builder: (_) {
                        final colorScheme = Theme.of(context).colorScheme;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pinned message panel
                            if (chatStore.pinnedMessage != null)
                              DismissiblePanel(
                                isMinimized: chatStore.isPinnedMessageMinimized,
                                minimizedIcon: const Icon(
                                  Icons.push_pin,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                minimizedColor: colorScheme.primary,
                                onDismiss: () =>
                                    chatStore.isPinnedMessageMinimized = true,
                                onRestore: () =>
                                    chatStore.isPinnedMessageMinimized = false,
                                child: PinnedMessagePanel(
                                  pinnedMessage: chatStore.pinnedMessage!,
                                ),
                              ),

                            // Poll panel
                            if (chatStore.activePoll != null)
                              DismissiblePanel(
                                isMinimized: chatStore.isPollMinimized,
                                minimizedIcon: const Icon(
                                  Icons.poll_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                minimizedColor: colorScheme.secondary,
                                onDismiss: () =>
                                    chatStore.isPollMinimized = true,
                                onRestore: () =>
                                    chatStore.isPollMinimized = false,
                                child: PollPanel(
                                  poll: chatStore.activePoll!,
                                  hasVoted:
                                      chatStore.hasVotedOnPoll ||
                                      chatStore.activePoll!.poll.hasVoted,
                                  selectedOptionIndex:
                                      chatStore.pollVotedOptionIndex,
                                  onVote: chatStore.auth.isLoggedIn
                                      ? chatStore.voteOnPoll
                                      : null,
                                ),
                              ),

                            // Prediction panel
                            if (chatStore.activePrediction != null)
                              DismissiblePanel(
                                isMinimized: chatStore.isPredictionMinimized,
                                minimizedIcon: const Icon(
                                  Icons.trending_up_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                minimizedColor: colorScheme.tertiary,
                                onDismiss: () =>
                                    chatStore.isPredictionMinimized = true,
                                onRestore: () =>
                                    chatStore.isPredictionMinimized = false,
                                child: PredictionPanel(
                                  prediction: chatStore.activePrediction!,
                                  userVotedOutcomeId:
                                      chatStore.predictionVotedOutcomeId,
                                  userVoteAmount:
                                      chatStore.predictionVoteAmount,
                                  onBet:
                                      chatStore.auth.isLoggedIn &&
                                          chatStore
                                              .activePrediction!
                                              .isActive &&
                                          !chatStore.hasVotedOnPrediction
                                      ? chatStore.betOnPrediction
                                      : null,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ChatBottomBar(
                      chatStore: chatStore,
                      onAddChat: onAddChat,
                      videoStore: videoStore,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final isHorizontalLandscape =
                          context.isLandscape &&
                          !chatStore.settings.landscapeForceVerticalChat;
                      return AnimatedPadding(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.only(
                          left: 4,
                          top: 4,
                          right: 4,
                          bottom:
                              chatStore.bottomBarHeight +
                              (chatStore.assetsStore.showEmoteMenu ||
                                      isHorizontalLandscape
                                  ? 0
                                  : MediaQuery.of(context).padding.bottom),
                        ),
                        child: Observer(
                          builder: (_) => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: chatStore.autoScroll
                                ? null
                                : ElevatedButton.icon(
                                    onPressed: chatStore.resumeScroll,
                                    icon: const Icon(
                                      Icons.arrow_downward_rounded,
                                    ),
                                    label: Text(
                                      chatStore.messageBuffer.isNotEmpty
                                          ? '${chatStore.messageBuffer.length} new ${chatStore.messageBuffer.length == 1 ? 'message' : 'messages'}'
                                          : 'Resume scroll',
                                      style: const TextStyle(
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              curve: Curves.ease,
              duration: const Duration(milliseconds: 200),
              height: chatStore.assetsStore.showEmoteMenu
                  ? context.screenHeight / (context.isPortrait ? 3 : 2)
                  : 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: chatStore.assetsStore.showEmoteMenu
                    ? ClipRect(
                        child: Column(
                          children: [
                            const Divider(),
                            Expanded(
                              child: KrostyPageView(
                                headers: [
                                  'Recent',
                                  if (chatStore.settings.showKickEmotes) 'Kick',
                                  if (chatStore.settings.show7TVEmotes) '7TV',
                                ],
                                children: [
                                  RecentEmotesPanel(chatStore: chatStore),
                                  if (chatStore.settings.showKickEmotes)
                                    EmoteMenuPanel(
                                      chatStore: chatStore,
                                      emotes: chatStore.assetsStore.emotesList
                                          .where(
                                            (e) =>
                                                chatStore.assetsStore.isKick(e),
                                          )
                                          .toList(),
                                    ),
                                  if (chatStore.settings.show7TVEmotes)
                                    EmoteMenuPanel(
                                      chatStore: chatStore,
                                      emotes: chatStore.assetsStore.emotesList
                                          .where(
                                            (e) =>
                                                chatStore.assetsStore.is7TV(e),
                                          )
                                          .toList(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
