import 'package:flutter/material.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/home/top/categories/category_streams.dart';
import 'package:krosty/widgets/krosty_cached_network_image.dart';
import 'package:krosty/widgets/skeleton_loader.dart';

/// A tappable card widget that displays a category's box art and name under.
class CategoryCard extends StatelessWidget {
  final KickCategory category;
  final bool isTappable;

  const CategoryCard({
    super.key,
    required this.category,
    this.isTappable = true,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the dimensions of the box art based on the current dimensions of the screen.
    // (unused width/height were removed as the KrostyCachedNetworkImage handles sizing)

    return InkWell(
      onTap: isTappable
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryStreams(category: category),
              ),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: 16 + MediaQuery.of(context).padding.left,
          right: 16 + MediaQuery.of(context).padding.right,
        ),
        child: Row(
          spacing: 16,
          children: [
            SizedBox(
              width: 80,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: KrostyCachedNetworkImage(
                    imageUrl: category.banner?.url ?? '',
                    placeholder: (context, url) => const SkeletonLoader(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: Text(
                category.name,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
