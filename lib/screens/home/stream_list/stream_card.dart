import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/channel/channel.dart';
import 'package:krosty/screens/home/top/categories/category_streams.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/theme.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/utils/modal_bottom_sheet.dart';
import 'package:krosty/widgets/blurred_container.dart';
import 'package:krosty/widgets/frosty_cached_network_image.dart';
import 'package:krosty/widgets/frosty_photo_view_dialog.dart';
import 'package:krosty/widgets/skeleton_loader.dart';
import 'package:krosty/widgets/uptime.dart';
import 'package:krosty/widgets/user_actions_modal.dart';
import 'package:provider/provider.dart';

/// A tappable card widget that displays a stream's thumbnail and details.
class StreamCard extends StatelessWidget {
  final KickLivestreamItem streamInfo;
  final bool showThumbnail;
  final bool showCategory;
  final bool showPinOption;
  final bool? isPinned;

  const StreamCard({
    super.key,
    required this.streamInfo,
    required this.showThumbnail,
    this.showCategory = true,
    this.showPinOption = false,
    this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a unique cache key for the thumbnail URL that updates every 5 minutes.
    // This ensures the image is refreshed periodically to reflect the latest content.
    final time = DateTime.now();
    final cacheKey =
        '${streamInfo.thumbnailUrl}-${time.day}-${time.hour}-${time.minute ~/ 5}';

    // Append width and height query parameters to get lower quality thumbnails
    final thumbnailUrl = streamInfo.thumbnailUrl ?? '';

    final thumbnail = AspectRatio(
      aspectRatio: 16 / 9,
      child: FrostyCachedNetworkImage(
        imageUrl: thumbnailUrl,
        cacheKey: cacheKey,
        placeholder: (context, url) => const SkeletonLoader(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        useOldImageOnUrlChange: true,
      ),
    );

    final streamerName = getReadableName(
      streamInfo.channelDisplayName,
      streamInfo.channelSlug,
    );

    final streamTitle = streamInfo.streamTitle.trim();
    final category = streamInfo.categoryName.isNotEmpty
        ? streamInfo.categoryName
        : 'No Category';

    const subFontSize = 14.0;

    final fontColor = DefaultTextStyle.of(context).style.color;

    final imageSection = ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          GestureDetector(
            onLongPress: () => showDialog(
              context: context,
              builder: (context) => FrostyPhotoViewDialog(
                imageUrl: streamInfo.thumbnailUrl ?? '',
                cacheKey: cacheKey,
              ),
            ),
            child: thumbnail,
          ),
          Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
            clipBehavior: Clip.antiAlias,
            child: BlurredContainer(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              sigmaX: 8.0, // Less blur for subtlety
              sigmaY: 8.0, // Less blur for subtlety
              forceDarkMode: true,
              child: Uptime(
                startTime: streamInfo.uptimeStartTime ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context
                      .watch<FrostyThemes>()
                      .dark
                      .colorScheme
                      .onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final streamInfoSection = Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Row(
            spacing: 4,
            children: [
              // Use profile picture from stream data, fallback to default Kick avatar
              ClipOval(
                child: FrostyCachedNetworkImage(
                  width: 20,
                  height: 20,
                  imageUrl: streamInfo.channelProfilePic?.isNotEmpty == true
                      ? streamInfo.channelProfilePic!
                      : 'https://files.kick.com/images/profile_image/default2.jpeg',
                  placeholder: (context, url) => Container(
                    width: 20,
                    height: 20,
                    color: Theme.of(context).colorScheme.surfaceContainer,
                  ),
                ),
              ),
              Flexible(
                child: Tooltip(
                  message: streamerName,
                  preferBelow: false,
                  child: Text(
                    streamerName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: fontColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Tooltip(
            message: streamTitle,
            preferBelow: false,
            child: Text(
              streamTitle,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: subFontSize,
                color: fontColor?.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (showCategory) ...[
            InkWell(
              onTap: streamInfo.categoryName.isNotEmpty
                  ? () {
                      final cat =
                          streamInfo.category ?? streamInfo.categories?.first;
                      if (cat != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CategoryStreams(category: cat),
                          ),
                        );
                      }
                    }
                  : null,
              child: Tooltip(
                message: category,
                preferBelow: false,
                child: Text(
                  category,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: subFontSize,
                    color: fontColor?.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ],
          Text(
            '${NumberFormat().format(streamInfo.viewerCount ?? 0)} viewers',
            style: TextStyle(
              fontSize: subFontSize,
              color: fontColor?.withValues(alpha: 0.8),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoChat(
            userId: (streamInfo.channelId ?? 0).toString(),
            userName: streamInfo.channelDisplayName,
            userLogin: streamInfo.channelSlug,
          ),
        ),
      ),
      onLongPress: () {
        HapticFeedback.mediumImpact();

        showModalBottomSheetWithProperFocus(
          context: context,
          builder: (context) => UserActionsModal(
            authStore: context.read<AuthStore>(),
            name: streamerName,
            userLogin: streamInfo.channelSlug,
            userId: (streamInfo.channelId ?? 0).toString(),
            showPinOption: showPinOption,
            isPinned: isPinned,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: showThumbnail
              ? 16 + MediaQuery.of(context).padding.left
              : 4 + MediaQuery.of(context).padding.left,
          right: showThumbnail
              ? 16 + MediaQuery.of(context).padding.right
              : 4 + MediaQuery.of(context).padding.right,
        ),
        child: Row(
          children: [
            if (showThumbnail) Flexible(child: imageSection),
            Flexible(flex: 2, child: streamInfoSection),
          ],
        ),
      ),
    );
  }
}
