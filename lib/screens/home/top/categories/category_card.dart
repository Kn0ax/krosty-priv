import 'package:flutter/material.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/home/top/categories/category_streams.dart';
import 'package:krosty/widgets/frosty_cached_network_image.dart';
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
    // Calculate the dimmensions of the box art based on the current dimmensions of the screen.
    final size = MediaQuery.of(context).size;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final artWidth = (size.width * pixelRatio) ~/ 5;
    final artHeight = (artWidth * (4 / 3)).toInt();

    // Append width and height query parameters to get lower quality thumbnails
    final bannerUrl = category.banner?.url != null
        ? '${category.banner?.url}?width=$artWidth&height=$artHeight&quality=80'
        : '';

    return InkWell(
      onTap: isTappable
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryStreams(
                  categorySlug: category.slug, // Updated to use slug
                  categoryId: category.id.toString(), // Kept for compatibility if needed, but safer to use slug
                ),
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
                  child: FrostyCachedNetworkImage(
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
