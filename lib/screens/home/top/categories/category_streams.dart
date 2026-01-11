import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/home/stream_list/stream_list_store.dart';
import 'package:krosty/screens/home/stream_list/streams_list.dart';
import 'package:krosty/widgets/blurred_container.dart';
import 'package:krosty/widgets/frosty_cached_network_image.dart';
import 'package:krosty/widgets/skeleton_loader.dart';

/// A widget that displays a list of streams under the provided category.
class CategoryStreams extends StatefulWidget {
  /// The category data (passed from categories list or stream card).
  final KickCategory category;

  const CategoryStreams({super.key, required this.category});

  @override
  State<CategoryStreams> createState() => _CategoryStreamsState();
}

class _CategoryStreamsState extends State<CategoryStreams> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Stream list content behind the pinned elements
          Positioned.fill(
            child: StreamsList(
              listType: ListType.category,
              categoryId: widget.category.id,
              showJumpButton: true,
            ),
          ),
          // Single blurred background spanning app bar and category card
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BlurredContainer(
              gradientDirection: GradientDirection.up,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: MediaQuery.of(context).padding.left,
                right: MediaQuery.of(context).padding.right,
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App bar section
                    SizedBox(
                      height: kToolbarHeight,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            icon: Icon(Icons.adaptive.arrow_back_rounded),
                            onPressed: Navigator.of(context).pop,
                          ),
                        ],
                      ),
                    ),
                    // Category card section - use passed category data directly
                    _TransparentCategoryCard(category: widget.category),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A transparent version of CategoryCard for use in blurred overlays
class _TransparentCategoryCard extends StatelessWidget {
  final KickCategory category;

  const _TransparentCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontColor = theme.textTheme.bodyMedium?.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: FrostyCachedNetworkImage(
                  imageUrl: category.banner?.url ?? '',
                  placeholder: (context, url) => const SkeletonLoader(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  category.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category.viewers != null)
                  Row(
                    spacing: 4,
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        size: 16,
                        color: fontColor?.withValues(alpha: 0.7),
                      ),
                      Text(
                        '${NumberFormat.compact().format(category.viewers)} viewers',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: fontColor?.withValues(alpha: 0.7),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
