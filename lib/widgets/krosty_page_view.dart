import 'package:flutter/material.dart';

class KrostyPageView extends StatefulWidget {
  final List<String> headers;
  final List<Widget> children;

  const KrostyPageView({
    super.key,
    required this.headers,
    required this.children,
  }) : assert(headers.length == children.length);

  @override
  State<KrostyPageView> createState() => _KrostyPageViewState();
}

class _KrostyPageViewState extends State<KrostyPageView> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Avoid layout overflow during animated height transitions
        // (e.g., when the emote menu is opening/closing and height is tiny).
        const double minHeight = kTextTabBarHeight + 1;
        if (constraints.maxHeight < minHeight) {
          return const SizedBox.expand();
        }

        return DefaultTabController(
          length: widget.headers.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                isScrollable: true,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: widget.headers
                    .map((header) => Tab(text: header))
                    .toList(),
              ),
              const Divider(),
              Expanded(child: TabBarView(children: widget.children)),
            ],
          ),
        );
      },
    );
  }
}
