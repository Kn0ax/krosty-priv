import 'package:flutter/material.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/home/top/categories/category_streams.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/utils/context_extensions.dart';
import 'package:krosty/widgets/live_indicator.dart';
import 'package:krosty/widgets/profile_picture.dart';
import 'package:krosty/widgets/uptime.dart';
import 'package:intl/intl.dart';

class StreamInfoBar extends StatelessWidget {
  final KickLivestreamItem? streamInfo;
  final KickChannel? offlineChannelInfo;
  final bool showCategory;
  final bool tappableCategory;
  final bool showUptime;
  final bool showViewerCount;
  final bool showOfflineIndicator;
  final EdgeInsets padding;
  final TooltipTriggerMode tooltipTriggerMode;
  final Color? textColor;
  final bool isCompact;
  final bool isInSharedChatMode;
  final bool isOffline;
  final bool showTextShadows;
  final String? displayName;

  const StreamInfoBar({
    super.key,
    this.streamInfo,
    this.offlineChannelInfo,
    this.showCategory = true,
    this.tappableCategory = true,
    this.showUptime = true,
    this.showViewerCount = true,
    this.showOfflineIndicator = true,
    this.padding = EdgeInsets.zero,
    this.tooltipTriggerMode = TooltipTriggerMode.tap,
    this.textColor,
    this.isCompact = false,
    this.isInSharedChatMode = false,
    this.isOffline = false,
    this.showTextShadows = true,
    this.displayName,
  });

  static const _iconShadow = [
    Shadow(
      offset: Offset(0, 1),
      blurRadius: 4,
      color: Color.fromRGBO(0, 0, 0, 0.3),
    ),
  ];

  static const _textShadow = [
    Shadow(
      offset: Offset(0, 1),
      blurRadius: 4,
      color: Color.fromRGBO(0, 0, 0, 0.3),
    ),
  ];

  TextStyle _getBaseTextStyle(
    BuildContext context,
    double fontSize,
    FontWeight fontWeight,
  ) {
    return context.textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
          shadows: showTextShadows ? _textShadow : null,
        ) ??
        const TextStyle();
  }

  TextStyle _getSecondaryTextStyle(BuildContext context, double fontSize) {
    return context.textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color:
              textColor?.withValues(alpha: 0.7) ??
              context.bodySmallColor?.withValues(alpha: 0.7),
          shadows: showTextShadows ? _textShadow : null,
        ) ??
        const TextStyle();
  }

  @override
  Widget build(BuildContext context) {
    final streamTitle = isOffline
        ? (offlineChannelInfo?.user.username.trim() ?? '')
        : (streamInfo?.streamTitle ?? '').trim();
    final streamerName = isOffline
        ? getReadableName(
            offlineChannelInfo?.user.username ?? displayName ?? '',
            offlineChannelInfo?.user.slug ?? '',
          )
        : getReadableName(
            streamInfo?.channelDisplayName ?? '',
            streamInfo?.channelSlug ?? '',
          );
    final secondLineSize = isCompact ? 13.0 : 14.0;

    return Padding(
      padding: padding,
      child: Row(
        spacing: 8,
        children: [
          Container(
            decoration: isInSharedChatMode
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  )
                : null,
            child: Padding(
              padding: isInSharedChatMode
                  ? const EdgeInsets.all(1.5)
                  : EdgeInsets.zero,
              child: ProfilePicture(
                userLogin: isOffline
                    ? (offlineChannelInfo?.user.slug.isNotEmpty == true
                        ? offlineChannelInfo?.user.slug ?? ''
                        : displayName ?? '')
                    : (streamInfo?.channelSlug ?? ''),
                profileUrl: isOffline
                    ? offlineChannelInfo?.profilePicUrl
                    : streamInfo?.channelProfilePic,
                radius: 16,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Streamer name + stream title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  spacing: 4,
                  children: [
                    Tooltip(
                      message: streamerName,
                      triggerMode: tooltipTriggerMode,
                      child: Text(
                        streamerName,
                        style: _getBaseTextStyle(context, 14, FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (streamTitle.isNotEmpty) ...[
                      Flexible(
                        child: Tooltip(
                          message: streamTitle,
                          triggerMode: tooltipTriggerMode,
                          child: Text(
                            streamTitle,
                            style: _getSecondaryTextStyle(context, 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Bottom row: Live indicator, uptime, viewer count, game name or Offline text
                if (isOffline ||
                    (!isOffline && showUptime) ||
                    (!isOffline && showViewerCount) ||
                    (showCategory &&
                        (isOffline
                            ? (offlineChannelInfo
                                      ?.recentCategories
                                      ?.isNotEmpty ??
                                  false)
                            : (streamInfo?.categoryName.isNotEmpty ??
                                  false)))) ...[
                  Row(
                    children: [
                      if (isOffline && showOfflineIndicator) ...[
                        Text(
                          'Offline',
                          style: _getSecondaryTextStyle(
                            context,
                            secondLineSize,
                          ),
                        ),
                      ],
                      if (isOffline &&
                          showCategory &&
                          (offlineChannelInfo?.recentCategories?.isNotEmpty ??
                              false)) ...[
                        if (showOfflineIndicator) const SizedBox(width: 8),
                        Icon(
                          Icons.gamepad,
                          size: secondLineSize,
                          color: (textColor ?? context.bodySmallColor)
                              ?.withValues(alpha: 0.7),
                          shadows: _iconShadow,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Tooltip(
                            message:
                                offlineChannelInfo
                                    ?.recentCategories
                                    ?.first
                                    .name ??
                                '',
                            triggerMode: tooltipTriggerMode,
                            child: Text(
                              offlineChannelInfo
                                      ?.recentCategories
                                      ?.first
                                      .name ??
                                  '',
                              style: _getSecondaryTextStyle(
                                context,
                                secondLineSize,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ] else ...[
                        if (!isOffline && (showUptime || showViewerCount)) ...[
                          const LiveIndicator(),
                          const SizedBox(width: 6),
                        ],
                        if (!isOffline && showUptime) ...[
                          Uptime(
                            startTime:
                                streamInfo?.uptimeStartTime ??
                                DateTime.now().toIso8601String(),
                            style: _getBaseTextStyle(
                              context,
                              secondLineSize,
                              FontWeight.w500,
                            ),
                          ),
                          if (!isOffline && showViewerCount)
                            const SizedBox(width: 8),
                        ],
                        if (!isOffline && showViewerCount) ...[
                          Icon(
                            Icons.visibility,
                            size: secondLineSize,
                            color: textColor ?? context.bodySmallColor,
                            shadows: _iconShadow,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            NumberFormat().format(streamInfo?.viewerCount ?? 0),
                            style: _getBaseTextStyle(
                              context,
                              secondLineSize,
                              FontWeight.w500,
                            ),
                          ),
                        ],
                        if (!isOffline &&
                            showCategory &&
                            (streamInfo?.categoryName.isNotEmpty ?? false) &&
                            (showUptime || showViewerCount)) ...[
                          const SizedBox(width: 8),
                        ],
                        if (!isOffline &&
                            showCategory &&
                            (streamInfo?.categoryName.isNotEmpty ?? false)) ...[
                          Icon(
                            Icons.gamepad,
                            size: secondLineSize,
                            color: textColor ?? context.bodySmallColor,
                            shadows: _iconShadow,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Tooltip(
                              message: streamInfo?.categoryName ?? '',
                              triggerMode: tooltipTriggerMode,
                              child: tappableCategory
                                  ? GestureDetector(
                                      onDoubleTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CategoryStreams(
                                            categorySlug:
                                                streamInfo
                                                    ?.categories
                                                    ?.first
                                                    .slug ??
                                                '',
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        streamInfo?.categoryName ?? '',
                                        style: _getBaseTextStyle(
                                          context,
                                          secondLineSize,
                                          FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : Text(
                                      streamInfo?.categoryName ?? '',
                                      style: _getBaseTextStyle(
                                        context,
                                        secondLineSize,
                                        FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
