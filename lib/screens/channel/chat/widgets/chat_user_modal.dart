import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/constants.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/models/kick_channel_user_info.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/screens/channel/chat/widgets/chat_message.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/utils/modal_bottom_sheet.dart';
import 'package:krosty/widgets/alert_message.dart';
import 'package:krosty/widgets/krosty_cached_network_image.dart';
import 'package:krosty/widgets/krosty_scrollbar.dart';
import 'package:krosty/widgets/profile_picture.dart';
import 'package:krosty/widgets/user_actions_modal.dart';
import 'package:provider/provider.dart';

class ChatUserModal extends StatefulWidget {
  final ChatStore chatStore;

  /// The user's original username (e.g. "cool_user123").
  /// Used for moderation actions (ban/timeout) and display.
  final String username;

  /// The user's URL-friendly slug (e.g. "cool-user123").
  /// Used for filtering messages and profile picture lookups.
  final String userSlug;

  final String displayName;
  final String userId;

  const ChatUserModal({
    super.key,
    required this.chatStore,
    required this.username,
    required this.userSlug,
    required this.displayName,
    required this.userId,
  });

  @override
  State<ChatUserModal> createState() => _ChatUserModalState();
}

class _ChatUserModalState extends State<ChatUserModal> {
  late Future<KickChannelUserInfo> _dataFuture;

  @override
  void initState() {
    super.initState();
    final kickApi = context.read<KickApi>();
    _dataFuture = kickApi.getChannelUserInfo(
      channelSlug: widget.chatStore.channelSlug,
      username: widget.username,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = getReadableName(widget.displayName, widget.username);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(name),
          FutureBuilder<KickChannelUserInfo>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return _buildUserInfo(
                  snapshot.data!,
                  widget.chatStore.assetsStore.subscriberBadges,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const Divider(indent: 12, endIndent: 12),
          Expanded(child: _buildMessagesList()),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      leading: ProfilePicture(userLogin: widget.userSlug),
      title: Row(
        children: [
          Flexible(
            child: Tooltip(
              message: name,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.chatStore.auth.isLoggedIn)
            IconButton(
              tooltip: 'Reply',
              onPressed: () {
                widget.chatStore.textController.text = '@${widget.username} ';
                Navigator.pop(context);
                widget.chatStore.safeRequestFocus();
              },
              icon: const Icon(Icons.reply_rounded),
            ),
          IconButton(
            tooltip: 'More',
            onPressed: () => showModalBottomSheetWithProperFocus(
              context: context,
              builder: (context) => UserActionsModal(
                authStore: widget.chatStore.auth,
                name: name,
                userLogin: widget.userSlug,
                userId: widget.userId,
              ),
            ),
            icon: Icon(Icons.adaptive.more_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(
    KickChannelUserInfo userInfo,
    List<KickSubscriberBadge>? subscriberBadges,
  ) {
    final activeBadges = userInfo.badges.where((b) => b.active).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeBadges.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: activeBadges
                  .map((badge) => _buildBadge(badge, subscriberBadges))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          _buildInfoRow(userInfo),
        ],
      ),
    );
  }

  Widget _buildBadge(
    KickUserBadge badge,
    List<KickSubscriberBadge>? subscriberBadges,
  ) {
    final color = _getBadgeColor(badge.type);
    final label = badge.type == 'subscriber' && badge.count != null
        ? '${badge.count} mo'
        : badge.text ?? badge.type;

    // Get badge image widget
    Widget badgeImage;
    if (badge.type == 'subscriber' && badge.count != null) {
      final subBadgeUrl = _getSubscriberBadgeUrl(
        badge.count!,
        subscriberBadges,
      );
      if (subBadgeUrl != null) {
        badgeImage = KrostyCachedNetworkImage(
          imageUrl: subBadgeUrl,
          width: 14,
          height: 14,
        );
      } else {
        badgeImage = Icon(_getBadgeIcon(badge.type), size: 14, color: color);
      }
    } else {
      final badgeAsset = _getBadgeAsset(badge.type);
      if (badgeAsset != null) {
        badgeImage = Image.asset(badgeAsset, width: 14, height: 14);
      } else {
        badgeImage = Icon(_getBadgeIcon(badge.type), size: 14, color: color);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          badgeImage,
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String? _getSubscriberBadgeUrl(
    int months,
    List<KickSubscriberBadge>? subscriberBadges,
  ) {
    if (subscriberBadges == null || subscriberBadges.isEmpty) return null;

    // Find the highest tier badge that the user qualifies for
    final sortedBadges = [...subscriberBadges]
      ..sort((a, b) => b.months.compareTo(a.months));

    for (final badge in sortedBadges) {
      if (months >= badge.months) {
        return badge.badgeImage?.src;
      }
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

  Widget _buildInfoRow(KickChannelUserInfo userInfo) {
    final items = <Widget>[];

    if (userInfo.followingSince != null) {
      final date = DateTime.tryParse(userInfo.followingSince!);
      if (date != null) {
        items.add(
          _buildInfoChip(
            Icons.favorite_rounded,
            'Following since ${DateFormat.yMMMd().format(date)}',
          ),
        );
      }
    }

    if (userInfo.subscribedFor != null && userInfo.subscribedFor! > 0) {
      items.add(
        _buildInfoChip(
          Icons.star_rounded,
          '${userInfo.subscribedFor} month sub',
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 4, children: items);
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  IconData _getBadgeIcon(String type) {
    switch (type) {
      case 'broadcaster':
        return Icons.videocam;
      case 'moderator':
        return Icons.shield;
      case 'vip':
        return Icons.diamond;
      case 'verified':
        return Icons.verified;
      case 'subscriber':
        return Icons.star;
      case 'og':
        return Icons.local_fire_department;
      case 'founder':
        return Icons.workspace_premium;
      default:
        return Icons.badge;
    }
  }

  Color _getBadgeColor(String type) {
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

  Widget _buildMessagesList() {
    return Observer(
      builder: (context) {
        final userMessages = widget.chatStore.messages.reversed
            .where((message) => message.sender.slug == widget.userSlug)
            .toList();

        if (userMessages.isEmpty) {
          return const AlertMessage(message: 'No recent messages');
        }

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              widget.chatStore.settings.messageScale,
            ),
          ),
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(
              context,
            ).style.copyWith(fontSize: widget.chatStore.settings.fontSize),
            child: KrostyScrollbar(
              child: ListView.builder(
                reverse: true,
                primary: false,
                itemCount: userMessages.length,
                itemBuilder: (context, index) => ChatMessage(
                  message: userMessages[index],
                  chatStore: widget.chatStore,
                  isModal: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
