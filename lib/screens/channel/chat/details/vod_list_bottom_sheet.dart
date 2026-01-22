import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_video.dart';
import 'package:krosty/screens/channel/video/video_store.dart';
import 'package:krosty/widgets/animated_scroll_border.dart';
import 'package:krosty/widgets/krosty_cached_network_image.dart';
import 'package:krosty/widgets/section_header.dart';

/// Bottom sheet that displays a list of recent VODs for a channel.
class VodListBottomSheet extends StatefulWidget {
  final KickApi kickApi;
  final String channelSlug;
  final VideoStore? videoStore;

  /// Whether the current user is subscribed to this channel.
  final bool isSubscriber;

  const VodListBottomSheet({
    super.key,
    required this.kickApi,
    required this.channelSlug,
    this.videoStore,
    this.isSubscriber = false,
  });

  @override
  State<VodListBottomSheet> createState() => _VodListBottomSheetState();
}

class _VodListBottomSheetState extends State<VodListBottomSheet> {
  late final _scrollController = ScrollController();
  List<KickVideo>? _videos;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      final videos = await widget.kickApi.getChannelVideos(
        channelSlug: widget.channelSlug,
      );
      if (mounted) {
        setState(() {
          // Filter videos based on playability (public + subscriber-only for subscribers)
          _videos = videos
              .where((v) => v.isPlayable(isSubscriber: widget.isSubscriber))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load VODs';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return DateFormat.MMMd().format(date);
      }
    } catch (e) {
      return '';
    }
  }

  void _playVod(KickVideo video) {
    HapticFeedback.lightImpact();
    widget.videoStore?.playVod(video);
    // Close the bottom sheet and the chat details
    Navigator.of(context).pop(); // Close VOD list
    Navigator.of(context).pop(); // Close chat details
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Recent VODs',
          padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
          isFirst: true,
        ),
        AnimatedScrollBorder(scrollController: _scrollController),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchVideos();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_videos == null || _videos!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 48),
            SizedBox(height: 16),
            Text('No VODs available'),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _videos!.length,
      itemBuilder: (context, index) {
        final video = _videos![index];
        return _VodListTile(
          video: video,
          formattedDate: _formatDate(video.createdAt),
          isSubscriberOnly: video.isSubscriberOnly,
          onTap: widget.videoStore != null ? () => _playVod(video) : null,
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _VodListTile extends StatelessWidget {
  final KickVideo video;
  final String formattedDate;
  final bool isSubscriberOnly;
  final VoidCallback? onTap;

  const _VodListTile({
    required this.video,
    required this.formattedDate,
    this.isSubscriberOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final viewCount = video.views ?? video.viewerCount ?? 0;
    final formattedViews = NumberFormat.compact().format(viewCount);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            SizedBox(
              width: 80,
              height: 45,
              child: video.thumbnailUrl != null
                  ? KrostyCachedNetworkImage(
                      imageUrl: video.thumbnailUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(Icons.play_circle_outline, size: 24),
                      ),
                    ),
            ),
            // Duration badge
            if (video.formattedDuration.isNotEmpty)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    video.formattedDuration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            // Subscriber-only badge
            if (isSubscriberOnly)
              Positioned(
                left: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text(
                    'SUB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(
        video.title.isNotEmpty ? video.title : 'Untitled VOD',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '$formattedDate • $formattedViews views',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: onTap != null ? const Icon(Icons.play_arrow_rounded) : null,
      onTap: onTap,
    );
  }
}
