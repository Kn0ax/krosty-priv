import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/channel/channel.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/utils/modal_bottom_sheet.dart';
import 'package:krosty/widgets/frosty_cached_network_image.dart';
import 'package:krosty/widgets/user_actions_modal.dart';
import 'package:provider/provider.dart';

/// A tappable card widget that displays an offline followed channel's details.
class OfflineChannelCard extends StatelessWidget {
  final KickFollowedChannel channelInfo;
  final bool showPinOption;
  final bool? isPinned;

  const OfflineChannelCard({
    super.key,
    required this.channelInfo,
    required this.showPinOption,
    this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    final channelName = getReadableName(
      channelInfo.userUsername,
      channelInfo.channelSlug,
    );

    final fontColor = DefaultTextStyle.of(context).style.color;
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainer;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoChat(
            userId: channelInfo.channelSlug,
            userName: channelInfo.userUsername,
            userLogin: channelInfo.channelSlug,
          ),
        ),
      ),
      onLongPress: () {
        HapticFeedback.mediumImpact();

        showModalBottomSheetWithProperFocus(
          context: context,
          builder: (context) => UserActionsModal(
            authStore: context.read<AuthStore>(),
            name: channelName,
            userLogin: channelInfo.channelSlug,
            userId: channelInfo.channelSlug,
            showPinOption: showPinOption,
            isPinned: isPinned,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16 + MediaQuery.of(context).padding.left,
          vertical: 8,
        ),
        child: Row(
          spacing: 12,
          children: [
            // Profile picture - use API data or default Kick avatar
            ClipOval(
              child: FrostyCachedNetworkImage(
                width: 40,
                height: 40,
                imageUrl: channelInfo.profilePicture?.isNotEmpty == true
                    ? channelInfo.profilePicture!
                    : 'https://files.kick.com/images/profile_image/default2.jpeg',
                placeholder: (context, url) =>
                    Container(width: 40, height: 40, color: placeholderColor),
              ),
            ),
            // Channel info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel name
                  Text(
                    channelName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: fontColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Offline status
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: fontColor?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
