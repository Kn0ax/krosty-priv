import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/screens/channel/chat/details/chat_details_store.dart';

class ChatModes extends StatelessWidget {
  final KickRoomState roomState;

  const ChatModes({super.key, required this.roomState});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final activeModes = <MapEntry<String, Widget>>[];

        // Collect active modes with their labels for sorting
        if (roomState.emotesMode) {
          activeModes.add(
            MapEntry(
              'Emote only',
              _buildModeChip(
                context: context,
                icon: Icons.emoji_emotions_outlined,
                activeIcon: Icons.emoji_emotions_rounded,
                label: 'Emote only',
                activeLabel: 'Emote only',
                isActive: true,
                activeColor: const Color(0xFFFFB74D),
              ),
            ),
          );
        }

        if (roomState.followersMode) {
          activeModes.add(
            MapEntry(
              'Follower only',
              _buildModeChip(
                context: context,
                icon: Icons.favorite_outline_rounded,
                activeIcon: Icons.favorite_rounded,
                label: 'Follower only',
                activeLabel: 'Follower only',
                isActive: true,
                activeColor: const Color(0xFFF44336),
                duration: roomState.followingMinDuration > 0
                    ? _formatDuration(roomState.followingMinDuration)
                    : null,
              ),
            ),
          );
        }

        if (roomState.slowMode) {
          activeModes.add(
            MapEntry(
              'Slow mode',
              _buildModeChip(
                context: context,
                icon: Icons.hourglass_empty_rounded,
                activeIcon: Icons.hourglass_top_rounded,
                label: 'Slow mode',
                activeLabel: 'Slow mode',
                isActive: true,
                activeColor: const Color(0xFF2196F3),
                duration: roomState.messageInterval > 0
                    ? _formatSeconds(roomState.messageInterval)
                    : null,
              ),
            ),
          );
        }

        if (roomState.subscribersMode) {
          activeModes.add(
            MapEntry(
              'Sub only',
              _buildModeChip(
                context: context,
                icon: Icons.monetization_on_outlined,
                activeIcon: Icons.monetization_on_rounded,
                label: 'Sub only',
                activeLabel: 'Sub only',
                isActive: true,
                activeColor: const Color(0xFF4CAF50),
              ),
            ),
          );
        }

        // Sort alphabetically by label
        activeModes.sort((a, b) => a.key.compareTo(b.key));
        final activeChips = activeModes.map((entry) => entry.value).toList();

        return Wrap(spacing: 8, runSpacing: -4, children: activeChips);
      },
    );
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
    return '${minutes}m';
  }

  String _formatSeconds(int seconds) {
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '${minutes}m';
      } else {
        return '${minutes}m ${remainingSeconds}s';
      }
    }
    return '${seconds}s';
  }

  Widget _buildModeChip({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String activeLabel,
    required bool isActive,
    required Color activeColor,
    String? duration,
  }) {
    return Chip(
      avatar: Icon(
        isActive ? activeIcon : icon,
        size: 16,
        color: isActive ? activeColor : null,
      ),
      label: duration != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isActive ? activeLabel : label),
                const SizedBox(width: 4),
                Text(
                  duration,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            )
          : Text(isActive ? activeLabel : label),
      side: BorderSide.none,
    );
  }
}
