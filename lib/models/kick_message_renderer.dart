import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:krosty/constants.dart';
import 'package:krosty/models/emotes.dart';
import 'package:krosty/models/kick_message.dart';
import 'package:krosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/utils.dart' as utils;
import 'package:krosty/widgets/frosty_cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

/// Regex for matching emoji characters.
final regexEmoji = RegExp(
  r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]',
  unicode: true,
);

/// Extension on KickChatMessage for rendering chat messages.
extension KickMessageRenderer on KickChatMessage {
  /// Generate widget spans for rendering this chat message.
  List<InlineSpan> generateSpan(
    BuildContext context, {
    TextStyle? style,
    required ChatAssetsStore assetsStore,
    required double badgeScale,
    required double emoteScale,
    required bool launchExternal,
    void Function()? onTapName,
    void Function(String)? onTapPingedUser,
    void Function()? onTapDeletedMessage,
    bool showMessage = true,
    TimestampType timestamp = TimestampType.disabled,
  }) {
    final emoteToObject = assetsStore.emotes;
    final badgeSize = defaultBadgeSize * badgeScale;
    final emoteSize = defaultEmoteSize * emoteScale;

    final span = <InlineSpan>[];

    // Add timestamp if enabled
    _addTimestamp(span, style, timestamp);

    // Add historical message indicator
    if (isHistorical) {
      span.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Tooltip(
            message: 'Historical message',
            preferBelow: false,
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(
              Icons.history_rounded,
              size: badgeSize,
              color:
                  Theme.of(context).iconTheme.color?.withValues(alpha: 0.5) ??
                  Colors.grey.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
      span.add(const TextSpan(text: ' '));
    }

    // Add Kick badges
    _addKickBadges(context, span, badgeSize, launchExternal, assetsStore);

    // Add username
    _addUsername(span, context, onTapName);

    // Add message content
    if (isSystemMessage) {
      span.add(TextSpan(text: ' $content', style: style));
    } else {
      _addMessageContent(
        context,
        span,
        emoteToObject,
        emoteSize,
        emoteScale,
        showMessage && !isDeleted,
        launchExternal,
        style,
        onTapPingedUser,
        onTapDeletedMessage,
        content,
      );
    }

    return span;
  }

  /// Add timestamp to span.
  void _addTimestamp(
    List<InlineSpan> span,
    TextStyle? style,
    TimestampType timestamp,
  ) {
    if (timestamp == TimestampType.disabled) return;

    final timeText = timestamp == TimestampType.twentyFour
        ? '${DateFormat.Hm().format(createdAt)} '
        : '${DateFormat('h:mm').format(createdAt)} ';

    span.add(
      TextSpan(
        text: timeText,
        style: style?.copyWith(
          color: style.color?.withValues(alpha: 0.5),
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  /// Add Kick badges to span.
  void _addKickBadges(
    BuildContext context,
    List<InlineSpan> span,
    double badgeSize,
    bool launchExternal,
    ChatAssetsStore assetsStore,
  ) {
    for (final badge in senderBadges) {
      final badgeWidget = _createKickBadgeWidget(badge, badgeSize, assetsStore);
      if (badgeWidget != null) {
        span.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
              message: _getBadgeTooltip(badge.type),
              preferBelow: false,
              triggerMode: TooltipTriggerMode.tap,
              child: badgeWidget,
            ),
          ),
        );
        span.add(const TextSpan(text: ' '));
      }
    }
  }

  /// Create a badge widget for Kick badges.
  Widget? _createKickBadgeWidget(
    KickBadgeInfo badge,
    double size,
    ChatAssetsStore assetsStore,
  ) {
    // Handle subscriber badges with channel-specific images
    if (badge.type == 'subscriber' && badge.count != null) {
      final subBadgeUrl = assetsStore.getSubscriberBadgeUrl(badge.count!);
      if (subBadgeUrl != null) {
        return FrostyCachedNetworkImage(
          imageUrl: subBadgeUrl,
          width: size,
          height: size,
        );
      }
      // Fallback to star icon if no custom badge
      return Icon(Icons.star, size: size, color: _getBadgeColor(badge.type));
    }

    final badgeAsset = _getBadgeAsset(badge.type);

    // Use kickicons for known badge types
    if (badgeAsset != null) {
      return Image.asset(badgeAsset, width: size, height: size);
    }

    // Fallback to icon
    final iconData = _getBadgeIcon(badge.type);
    final color = _getBadgeColor(badge.type);

    if (iconData != null) {
      return Icon(iconData, size: size, color: color);
    }

    // For custom badges with text
    if (badge.text != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color ?? Colors.grey,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          badge.text!,
          style: TextStyle(
            fontSize: size * 0.6,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return null;
  }

  String? _getBadgeAsset(String type) {
    switch (type) {
      case 'broadcaster':
        return 'assets/icons/badges/kick-broadcaster.png';
      case 'moderator':
        return 'assets/icons/badges/kick-moderator.png';
      case 'vip':
        return 'assets/icons/badges/kick-vip.png';
      case 'verified':
        return 'assets/icons/badges/kick-verified.png';
      case 'og':
        return 'assets/icons/badges/kick-og.png';
      case 'founder':
        return 'assets/icons/badges/kick-founder.png';
      case 'staff':
        return 'assets/icons/badges/kick-staff.png';
      case 'sub_gifter':
        return 'assets/icons/badges/kick-sub_gifter.png';
      default:
        return null;
    }
  }

  IconData? _getBadgeIcon(String type) {
    switch (type) {
      case 'subscriber':
        return Icons.star;
      default:
        return null;
    }
  }

  Color? _getBadgeColor(String type) {
    switch (type) {
      case 'broadcaster':
        return Colors.red;
      case 'moderator':
        return const Color(0xFF00AD03);
      case 'vip':
        return Colors.purple;
      case 'verified':
        return Colors.blue;
      case 'subscriber':
        return kickBrandColor;
      case 'og':
        return Colors.orange;
      case 'founder':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getBadgeTooltip(String type) {
    switch (type) {
      case 'broadcaster':
        return 'Broadcaster';
      case 'moderator':
        return 'Moderator';
      case 'vip':
        return 'VIP';
      case 'verified':
        return 'Verified';
      case 'subscriber':
        return 'Subscriber';
      case 'og':
        return 'OG';
      case 'founder':
        return 'Founder';
      default:
        return type;
    }
  }

  /// Add username to span.
  void _addUsername(
    List<InlineSpan> span,
    BuildContext context,
    void Function()? onTapName,
  ) {
    if (isSystemMessage) return;

    var color = parseHexColor(senderColor);
    color = utils.adjustChatNameColor(context, color);

    span.add(
      TextSpan(
        text: senderName,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
        recognizer: TapGestureRecognizer()..onTap = onTapName,
      ),
    );

    span.add(const TextSpan(text: ': '));
  }

  /// Add message content with emotes.
  void _addMessageContent(
    BuildContext context,
    List<InlineSpan> span,
    Map<String, Emote> emoteToObject,
    double emoteSize,
    double emoteScale,
    bool showMessage,
    bool launchExternal,
    TextStyle? textStyle,
    void Function(String)? onTapPingedUser,
    void Function()? onTapDeletedMessage,
    String messageContent,
  ) {
    if (!showMessage) {
      span.add(
        TextSpan(
          text: '<message deleted>',
          style: onTapDeletedMessage != null
              ? textStyle?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                )
              : textStyle?.copyWith(
                  color: textStyle.color?.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
          recognizer: onTapDeletedMessage != null
              ? (TapGestureRecognizer()..onTap = onTapDeletedMessage)
              : null,
        ),
      );
      return;
    }

    // Split message into words and process each
    final messageWords = messageContent.split(' ');

    for (var i = 0; i < messageWords.length; i++) {
      final word = messageWords[i];
      if (word.isEmpty) continue;

      var emote = emoteToObject[word];

      // Handle [emote:id:name] format for Kick emotes (especially from other channels)
      if (emote == null) {
        final kickEmoteMatch = RegExp(
          r'^\[emote:(\d+):([^\]]+)\]$',
        ).firstMatch(word);
        if (kickEmoteMatch != null) {
          final id = kickEmoteMatch.group(1);
          final name = kickEmoteMatch.group(2);

          if (name != null) {
            // Check if we have it by name
            emote = emoteToObject[name];

            // If not found, create a dynamic emote object
            if (emote == null && id != null) {
              emote = Emote(
                id: id,
                name: name,
                zeroWidth: false,
                url: 'https://files.kick.com/emotes/$id/fullsize',
                type: EmoteType
                    .kickChannel, // Assumption for external channel emotes
              );
            }
          }
        }
      }

      // Check if word is an emote
      if (emote != null) {
        // Handle zero-width emotes stacking
        if (emote.zeroWidth && i > 0) {
          _addZeroWidthEmoteStack(
            context,
            span,
            messageWords,
            i,
            emote,
            emoteToObject,
            emoteSize,
            emoteScale,
            launchExternal,
          );
        } else {
          span.add(
            _createEmoteSpan(
              context,
              emote: emote,
              height: emote.height != null
                  ? emote.height! * emoteScale
                  : emoteSize,
              width: emote.width != null ? emote.width! * emoteScale : null,
              launchExternal: launchExternal,
            ),
          );
        }
        span.add(const TextSpan(text: ' '));
        continue;
      }

      // Check if word is an emoji
      if (regexEmoji.hasMatch(word)) {
        span.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Text(
              word,
              style: textStyle?.copyWith(fontSize: emoteSize - 5),
            ),
          ),
        );
        span.add(const TextSpan(text: ' '));
        continue;
      }

      // Check if word is a mention
      if (word.startsWith('@')) {
        final username = word.substring(1);
        span.add(
          TextSpan(
            text: word,
            style: textStyle?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            recognizer: onTapPingedUser != null && username.isNotEmpty
                ? (TapGestureRecognizer()
                    ..onTap = () => onTapPingedUser(username))
                : null,
          ),
        );
        span.add(const TextSpan(text: ' '));
        continue;
      }

      // Check if word is a link
      if (regexLink.hasMatch(word)) {
        span.add(
          TextSpan(
            text: word,
            style: textStyle?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final url = word.startsWith('http') ? word : 'https://$word';
                launchUrl(
                  Uri.parse(url),
                  mode: launchExternal
                      ? LaunchMode.externalApplication
                      : LaunchMode.inAppWebView,
                );
              },
          ),
        );
        span.add(const TextSpan(text: ' '));
        continue;
      }

      // Regular text
      span.add(TextSpan(text: '$word ', style: textStyle));
    }
  }

  /// Handle zero-width emote stacking.
  void _addZeroWidthEmoteStack(
    BuildContext context,
    List<InlineSpan> span,
    List<String> words,
    int index,
    Emote startEmote,
    Map<String, Emote> emoteToObject,
    double emoteSize,
    double emoteScale,
    bool launchExternal,
  ) {
    // Collect consecutive zero-width emotes
    final emoteStack = <Emote>[startEmote];
    var checkIndex = index - 1;

    while (checkIndex >= 0) {
      final prevWord = words[checkIndex];
      final prevEmote = emoteToObject[prevWord];
      if (prevEmote != null && prevEmote.zeroWidth) {
        emoteStack.insert(0, prevEmote);
        checkIndex--;
      } else {
        break;
      }
    }

    // Get the base emote (last non-zero-width emote before the stack)
    Emote? baseEmote;
    if (checkIndex >= 0) {
      baseEmote = emoteToObject[words[checkIndex]];
    }

    // Build the stacked widget
    final children = <Widget>[];

    if (baseEmote != null && !baseEmote.zeroWidth) {
      children.add(
        FrostyCachedNetworkImage(
          imageUrl: baseEmote.url,
          height: baseEmote.height != null
              ? baseEmote.height! * emoteScale
              : emoteSize,
          width: baseEmote.width != null ? baseEmote.width! * emoteScale : null,
          useFade: false,
        ),
      );
    }

    for (final emote in emoteStack) {
      children.add(
        FrostyCachedNetworkImage(
          imageUrl: emote.url,
          height: emote.height != null ? emote.height! * emoteScale : emoteSize,
          width: emote.width != null ? emote.width! * emoteScale : null,
          useFade: false,
        ),
      );
    }

    span.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Tooltip(
          message: emoteStack.map((e) => e.name).join(' + '),
          preferBelow: false,
          triggerMode: TooltipTriggerMode.tap,
          child: Stack(alignment: Alignment.center, children: children),
        ),
      ),
    );
  }

  /// Create emote span widget.
  WidgetSpan _createEmoteSpan(
    BuildContext context, {
    required Emote emote,
    required double height,
    required double? width,
    required bool launchExternal,
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: InkWell(
        onTap: () => showEmoteDetailsBottomSheet(
          context,
          emote: emote,
          launchExternal: launchExternal,
        ),
        child: FrostyCachedNetworkImage(
          imageUrl: emote.url,
          height: height,
          width: width,
          useFade: false,
        ),
      ),
    );
  }
}

/// Show emote details bottom sheet.
void showEmoteDetailsBottomSheet(
  BuildContext context, {
  required Emote emote,
  required bool launchExternal,
}) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostyCachedNetworkImage(imageUrl: emote.url, height: 96),
            const SizedBox(height: 16),
            Text(emote.name, style: Theme.of(context).textTheme.titleLarge),
            if (emote.realName != null && emote.realName != emote.name)
              Text(
                'Original: ${emote.realName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              emote.type.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            if (emote.ownerDisplayName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'By: ${emote.ownerDisplayName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: emote.name));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied "${emote.name}"')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(emote.url),
                    mode: launchExternal
                        ? LaunchMode.externalApplication
                        : LaunchMode.inAppWebView,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
