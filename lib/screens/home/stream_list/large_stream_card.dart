import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/channel/channel.dart';
import 'package:krosty/screens/channel/video/stream_info_bar.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/utils/modal_bottom_sheet.dart';
import 'package:krosty/widgets/frosty_cached_network_image.dart';
import 'package:krosty/widgets/skeleton_loader.dart';
import 'package:krosty/widgets/user_actions_modal.dart';
import 'package:provider/provider.dart';

class LargeStreamCard extends StatelessWidget {
  final KickLivestreamItem streamInfo;
  final bool showThumbnail;
  final bool showCategory;
  final bool showPinOption;
  final bool? isPinned;

  const LargeStreamCard({
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

    final thumbnailUrl = streamInfo.thumbnailUrl != null
        ? '${streamInfo.thumbnailUrl}'
        : '';

    final thumbnail = SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: FrostyCachedNetworkImage(
            imageUrl: thumbnailUrl,
            cacheKey: cacheKey,
            placeholder: (context, url) => const SkeletonLoader(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            useOldImageOnUrlChange: true,
          ),
        ),
      ),
    );

    final streamerName = getReadableName(
      streamInfo.channelDisplayName,
      streamInfo.channelSlug,
    );

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoChat(
            userId: streamInfo.channelId.toString(),
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
            userId: streamInfo.channelId.toString(),
            showPinOption: showPinOption,
            isPinned: isPinned,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(
          top: showThumbnail ? 12 : 4,
          bottom: showThumbnail ? 12 : 4,
          left: 16 + MediaQuery.of(context).padding.left,
          right: 16 + MediaQuery.of(context).padding.right,
        ),
        child: Column(
          children: [
            if (showThumbnail) thumbnail,
            StreamInfoBar(
              streamInfo: streamInfo,
              showCategory: showCategory,
              padding: const EdgeInsets.symmetric(vertical: 12),
              tooltipTriggerMode: TooltipTriggerMode.longPress,
            ),
          ],
        ),
      ),
    );
  }
}
