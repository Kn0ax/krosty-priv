import 'package:flutter/material.dart';

/// A wrapper widget that makes panels dismissible via swipe.
/// When dismissed, shows a small icon button on the side to restore.
class DismissiblePanel extends StatelessWidget {
  final Widget child;
  final Widget minimizedIcon;
  final Color minimizedColor;
  final bool isMinimized;
  final VoidCallback onDismiss;
  final VoidCallback onRestore;
  final DismissDirection direction;

  const DismissiblePanel({
    super.key,
    required this.child,
    required this.minimizedIcon,
    required this.minimizedColor,
    required this.isMinimized,
    required this.onDismiss,
    required this.onRestore,
    this.direction = DismissDirection.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    if (isMinimized) {
      return _MinimizedButton(
        icon: minimizedIcon,
        color: minimizedColor,
        onTap: onRestore,
      );
    }

    return Dismissible(
      key: ValueKey(child.hashCode),
      direction: direction,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Icon(
          Icons.chevron_left,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      child: child,
    );
  }
}

/// Small button shown when panel is minimized.
class _MinimizedButton extends StatelessWidget {
  final Widget icon;
  final Color color;
  final VoidCallback onTap;

  const _MinimizedButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, right: 8),
        child: Material(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(padding: const EdgeInsets.all(8), child: icon),
          ),
        ),
      ),
    );
  }
}
