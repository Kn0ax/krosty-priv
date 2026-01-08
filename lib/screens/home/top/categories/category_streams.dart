import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/screens/home/stream_list/stream_list_store.dart';
import 'package:krosty/screens/home/stream_list/streams_list.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/widgets/blurred_container.dart';
import 'package:krosty/widgets/frosty_cached_network_image.dart';
import 'package:krosty/widgets/skeleton_loader.dart';
import 'package:provider/provider.dart';

/// A widget that displays a list of streams under the provided [categoryId].
class CategoryStreams extends StatefulWidget {
  /// The category id, used for fetching the relevant streams in the [ListStore].
  final String categorySlug;
  final String? categoryId;

  const CategoryStreams({
    super.key,
    required this.categorySlug,
    this.categoryId,
  });

  @override
  State<CategoryStreams> createState() => _CategoryStreamsState();
}

class _CategoryStreamsState extends State<CategoryStreams> {
  late final _listStore = ListStore(
    listType: ListType.category,
    categorySlug: widget.categorySlug,
    authStore: context.read<AuthStore>(),
    kickApi: context.read<KickApi>(),
    settingsStore: context.read<SettingsStore>(),
  );

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
              categorySlug: widget.categorySlug,
              // categorySlug: widget.categorySlug, // StreamsList might need update to use slug if it doesn't already? 
              // StreamsList uses listType.category. And likely categoryId parameter.
              // I'll check StreamsList later. Ideally pass slug if StreamsList supports it.
              // For now, pass categoryId (if string) or slug as ID?
              // StreamsList.dart accepts `categoryId` as String?. (Step 611).
              // And uses `ListStore`. `ListStore` uses `categorySlug`.
              // So I should pass `categorySlug` to StreamsList's `categoryId`?? or `categoryId`?
              // Let's pass `widget.categorySlug` to `categoryId` parameter of StreamsList if StreamsList treats it as slug.
              // StreamsList currently has `final String? categoryId;`.
              // And `_listStore` uses `categoryId` as `categorySlug`?
              // ListStore constructor: `categorySlug: widget.categoryId ?? widget.categorySlug`.
              // So passing slug as categoryId works??
              // I'll pass widget.categorySlug to StreamsList.
             
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
                    // Category card section
                    Observer(
                      builder: (_) {
                        if (_listStore.categoryDetails != null) {
                          return _TransparentCategoryCard(
                            category: _listStore.categoryDetails!,
                          );
                        } else {
                          // Skeleton loader for category card
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 16,
                              left: 16,
                              right: 16,
                            ),
                            child: Row(
                              spacing: 12,
                              children: [
                                const SizedBox(
                                  width: 80,
                                  child: AspectRatio(
                                    aspectRatio: 3 / 4,
                                    child: SkeletonLoader(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 8,
                                    children: [
                                      SkeletonLoader(
                                        height: 20,
                                        width: double.infinity,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      SkeletonLoader(
                                        height: 16,
                                        width: 120,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _listStore.dispose();
    super.dispose();
  }
}

/// A transparent version of CategoryCard for use in blurred overlays
class _TransparentCategoryCard extends StatelessWidget {
  final dynamic category;

  const _TransparentCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    // Calculate the dimensions of the box art based on the current dimensions of the screen.
    final size = MediaQuery.of(context).size;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final artWidth = (size.width * pixelRatio) ~/ 5;
    final artHeight = (artWidth * (4 / 3)).toInt();

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
                  imageUrl: category.banner ?? '',
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
              children: [
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
