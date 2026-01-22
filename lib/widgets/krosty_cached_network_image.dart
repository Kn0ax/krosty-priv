import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:krosty/cache_manager.dart';

/// A wrapper around [CachedNetworkImage] that adds custom defaults for Krosty.
/// Optimized for memory efficiency with reduced fade durations and memory caching.
class KrostyCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final String? cacheKey;
  final double? width;
  final double? height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Widget Function(BuildContext, String)? placeholder;
  final bool useOldImageOnUrlChange;
  final bool useFade;
  final BoxFit? fit;

  const KrostyCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.placeholder,
    this.useFade = true,
    this.useOldImageOnUrlChange = false,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      width: width,
      height: height,
      color: color,
      colorBlendMode: colorBlendMode,
      placeholder: placeholder,
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      // Reduced fade durations for better performance
      fadeOutDuration: useFade
          ? const Duration(milliseconds: 200)
          : Duration.zero,
      fadeInDuration: useFade
          ? const Duration(milliseconds: 200)
          : Duration.zero,
      fadeInCurve: Curves.easeOut,
      fadeOutCurve: Curves.easeIn,
      fit: fit,
      cacheManager: CustomCacheManager.instance,
      // Use memory cache for frequently accessed images (emotes)
      memCacheWidth: width != null
          ? (width! * MediaQuery.of(context).devicePixelRatio).toInt()
          : null,
      memCacheHeight: height != null
          ? (height! * MediaQuery.of(context).devicePixelRatio).toInt()
          : null,
    );
  }
}
