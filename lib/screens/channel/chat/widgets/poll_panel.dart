import 'package:flutter/material.dart';
import 'package:krosty/models/kick_message.dart';

/// A panel that displays an active poll with voting options.
class PollPanel extends StatelessWidget {
  final KickPollUpdateEvent poll;
  final bool hasVoted;
  final int? selectedOptionIndex;
  final Future<void> Function(int optionIndex)? onVote;

  const PollPanel({
    super.key,
    required this.poll,
    this.hasVoted = false,
    this.selectedOptionIndex,
    this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalVotes = poll.poll.totalVotes;
    final isCompleted = poll.state == KickPollState.completed;
    final isCancelled = poll.state == KickPollState.cancelled;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.poll_rounded,
                  size: 18,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.poll.title ?? 'Poll',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (!isCompleted && !isCancelled)
                  _RemainingTime(remaining: poll.poll.remaining),
              ],
            ),
            const SizedBox(height: 12),

            // Options
            ...poll.poll.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final votes = option.votes;
              final percentage = totalVotes > 0
                  ? (votes / totalVotes * 100)
                  : 0.0;
              final isSelected = selectedOptionIndex == index;
              final canVote =
                  !hasVoted && !isCompleted && !isCancelled && onVote != null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PollOption(
                  label: option.label,
                  votes: votes,
                  percentage: percentage,
                  isSelected: isSelected,
                  showResults: hasVoted || isCompleted,
                  canVote: canVote,
                  onTap: canVote ? () => onVote?.call(index) : null,
                ),
              );
            }),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (isCompleted)
                  Text(
                    'Poll ended',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  )
                else if (isCancelled)
                  Text(
                    'Poll cancelled',
                    style: TextStyle(color: colorScheme.error, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  final String label;
  final int votes;
  final double percentage;
  final bool isSelected;
  final bool showResults;
  final bool canVote;
  final VoidCallback? onTap;

  const _PollOption({
    required this.label,
    required this.votes,
    required this.percentage,
    required this.isSelected,
    required this.showResults,
    required this.canVote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Stack(
              children: [
                // Progress bar background
                if (showResults)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percentage / 100,
                      child: Container(
                        color:
                            (isSelected
                                    ? colorScheme.primary
                                    : colorScheme.secondaryContainer)
                                .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (showResults) ...[
                        Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ] else if (canVote)
                        Icon(
                          Icons.radio_button_unchecked,
                          size: 18,
                          color: colorScheme.outline,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemainingTime extends StatelessWidget {
  final int remaining;

  const _RemainingTime({required this.remaining});

  String get _formattedTime {
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formattedTime,
        style: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
