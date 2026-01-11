import 'package:flutter/material.dart';
import 'package:krosty/models/kick_message.dart';

/// A panel that displays an active prediction with betting options.
class PredictionPanel extends StatefulWidget {
  final KickPredictionEvent prediction;
  final String? userVotedOutcomeId;
  final int? userVoteAmount;
  final Future<void> Function(String outcomeId, int amount)? onBet;

  const PredictionPanel({
    super.key,
    required this.prediction,
    this.userVotedOutcomeId,
    this.userVoteAmount,
    this.onBet,
  });

  @override
  State<PredictionPanel> createState() => _PredictionPanelState();
}

class _PredictionPanelState extends State<PredictionPanel> {
  String? _selectedOutcomeId;
  int _betAmount = 10;
  bool _isPlacingBet = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final prediction = widget.prediction;
    final totalAmount = prediction.totalVoteAmount;
    final hasVoted = widget.userVotedOutcomeId != null;
    final canBet = prediction.isActive && !hasVoted && widget.onBet != null;

    // Outcome colors for visual distinction
    final outcomeColors = [
      Colors.blue,
      Colors.pink,
      Colors.orange,
      Colors.green,
      Colors.purple,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.3),
        ),
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
                  Icons.trending_up_rounded,
                  size: 18,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prediction.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                _PredictionStateChip(state: prediction.state),
              ],
            ),
            const SizedBox(height: 12),

            // Outcomes
            ...prediction.outcomes.asMap().entries.map((entry) {
              final index = entry.key;
              final outcome = entry.value;
              final color = outcomeColors[index % outcomeColors.length];
              final percentage = outcome.percentageOf(totalAmount);
              final isUserChoice = widget.userVotedOutcomeId == outcome.id;
              final isSelected = _selectedOutcomeId == outcome.id;
              final isWinner =
                  prediction.isResolved &&
                  prediction.winningOutcomeId == outcome.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PredictionOutcome(
                  title: outcome.title,
                  amount: outcome.totalVoteAmount,
                  voteCount: outcome.voteCount,
                  percentage: percentage,
                  returnRate: outcome.returnRate,
                  color: color,
                  isSelected: isSelected,
                  isUserChoice: isUserChoice,
                  isWinner: isWinner,
                  showResults: hasVoted || !prediction.isActive,
                  canSelect: canBet && !_isPlacingBet,
                  onTap: canBet
                      ? () => setState(() => _selectedOutcomeId = outcome.id)
                      : null,
                ),
              );
            }),

            // Bet amount selector (only when active and can bet)
            if (canBet && _selectedOutcomeId != null) ...[
              const SizedBox(height: 8),
              _BetAmountSelector(
                amount: _betAmount,
                onAmountChanged: (amount) =>
                    setState(() => _betAmount = amount),
                onPlaceBet: _isPlacingBet
                    ? null
                    : () async {
                        setState(() => _isPlacingBet = true);
                        try {
                          await widget.onBet?.call(
                            _selectedOutcomeId!,
                            _betAmount,
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isPlacingBet = false);
                          }
                        }
                      },
                isLoading: _isPlacingBet,
              ),
            ],

            // Footer
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatAmount(totalAmount)} points in pool',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (hasVoted)
                  Text(
                    'You bet ${widget.userVoteAmount ?? 0}',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }
}

class _PredictionOutcome extends StatelessWidget {
  final String title;
  final int amount;
  final int voteCount;
  final double percentage;
  final double returnRate;
  final Color color;
  final bool isSelected;
  final bool isUserChoice;
  final bool isWinner;
  final bool showResults;
  final bool canSelect;
  final VoidCallback? onTap;

  const _PredictionOutcome({
    required this.title,
    required this.amount,
    required this.voteCount,
    required this.percentage,
    required this.returnRate,
    required this.color,
    required this.isSelected,
    required this.isUserChoice,
    required this.isWinner,
    required this.showResults,
    required this.canSelect,
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
              color: isSelected || isUserChoice
                  ? color
                  : isWinner
                      ? Colors.amber
                      : colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected || isUserChoice || isWinner ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Stack(
              children: [
                // Progress bar
                if (showResults)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percentage / 100,
                      child: Container(
                        color: color.withValues(alpha: 0.2),
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
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontWeight: isSelected ||
                                              isUserChoice ||
                                              isWinner
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isWinner)
                                  const Icon(
                                    Icons.emoji_events,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                if (isUserChoice && !isWinner)
                                  Icon(
                                    Icons.check_circle,
                                    color: color,
                                    size: 18,
                                  ),
                              ],
                            ),
                            if (showResults)
                              Text(
                                '${percentage.toStringAsFixed(0)}% • $voteCount bets',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              )
                            else if (returnRate > 0)
                              Text(
                                '${returnRate.toStringAsFixed(1)}x return',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
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

class _BetAmountSelector extends StatelessWidget {
  final int amount;
  final ValueChanged<int> onAmountChanged;
  final VoidCallback? onPlaceBet;
  final bool isLoading;

  const _BetAmountSelector({
    required this.amount,
    required this.onAmountChanged,
    this.onPlaceBet,
    this.isLoading = false,
  });

  static const _presetAmounts = [10, 50, 100, 500, 1000];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Preset buttons
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _presetAmounts.map((preset) {
              final isSelected = amount == preset;
              return Material(
                color: isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => onAmountChanged(preset),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      preset.toString(),
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        // Place bet button
        FilledButton(
          onPressed: onPlaceBet,
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Bet $amount'),
        ),
      ],
    );
  }
}

class _PredictionStateChip extends StatelessWidget {
  final String state;

  const _PredictionStateChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color textColor;
    String label;

    switch (state) {
      case KickPredictionState.active:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = 'OPEN';
      case KickPredictionState.locked:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        label = 'LOCKED';
      case KickPredictionState.resolved:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = 'RESOLVED';
      case KickPredictionState.cancelled:
        backgroundColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        label = 'CANCELLED';
      default:
        backgroundColor = colorScheme.surfaceContainerHigh;
        textColor = colorScheme.onSurfaceVariant;
        label = state.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
