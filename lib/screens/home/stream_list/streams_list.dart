import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/screens/home/stream_list/large_stream_card.dart';
import 'package:krosty/screens/home/stream_list/offline_channel_card.dart';
import 'package:krosty/screens/home/stream_list/stream_card.dart';
import 'package:krosty/screens/home/stream_list/stream_list_store.dart';
import 'package:krosty/screens/settings/stores/auth_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/widgets/alert_message.dart';
import 'package:krosty/widgets/expandable_section_header.dart';
import 'package:krosty/widgets/krosty_scrollbar.dart';
import 'package:krosty/widgets/scroll_to_top_button.dart';
import 'package:krosty/widgets/section_header.dart';
import 'package:krosty/widgets/skeleton_loader.dart';
import 'package:provider/provider.dart';

/// A widget that displays a list of followed or top streams based on the provided [listType].
/// For a widget that displays the top streams under a category, refer to [CategoryStreams].
class StreamsList extends StatefulWidget {
  /// The type of list to display.
  final ListType listType;

  /// The category ID for filtering streams (only used when listType is category).
  final int? categoryId;

  /// The scroll controller to use for scroll to top functionality.
  final ScrollController? scrollController;

  final bool showJumpButton;

  const StreamsList({
    super.key,
    required this.listType,
    this.categoryId,
    this.scrollController,
    this.showJumpButton = false,
  });

  @override
  State<StreamsList> createState() => _StreamsListState();
}

class _StreamsListState extends State<StreamsList>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final ListStore _listStore;
  ScrollController? _scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.scrollController == null && widget.showJumpButton) {
      _scrollController = ScrollController();
    }

    _listStore = ListStore(
      authStore: context.read<AuthStore>(),
      settingsStore: context.read<SettingsStore>(),
      kickApi: context.read<KickApi>(),
      listType: widget.listType,
      categoryId: widget.categoryId,
      scrollController: widget.scrollController ?? _scrollController,
    );
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _listStore.checkLastTimeRefreshedAndUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    _listStore.checkLastTimeRefreshedAndUpdate();

    final extraTopPadding = widget.listType == ListType.top
        ? kToolbarHeight
        : widget.listType == ListType.category
        ? kToolbarHeight + 122
        : 0.0;

    final topPadding = MediaQuery.of(context).padding.top + extraTopPadding;

    return RefreshIndicator.adaptive(
      edgeOffset: topPadding,
      onRefresh: () async {
        HapticFeedback.lightImpact();

        await _listStore.refreshStreams();

        if (_listStore.error != null) {
          final snackBar = SnackBar(
            content: AlertMessage(message: _listStore.error!, centered: false),
          );

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      },
      child: Observer(
        builder: (_) {
          Widget? statusWidget;

          if (_listStore.error != null) {
            statusWidget = AlertMessage(
              message: _listStore.error!,
              vertical: true,
            );
          }

          // Check if we have any streams (live for followed, all for others)
          final hasStreams = widget.listType == ListType.followed
              ? _listStore.liveStreams.isNotEmpty ||
                    _listStore.offlineChannels.isNotEmpty
              : _listStore.streams.isNotEmpty;

          if (!hasStreams) {
            if (_listStore.isLoading && _listStore.error == null) {
              // Show skeleton loaders while loading
              final settingsStore = context.watch<SettingsStore>();
              final isLargeCard = settingsStore.largeStreamCard;
              final isFollowingTab = widget.listType == ListType.followed;
              final pinnedChannelCount = settingsStore.pinnedChannelIds.length;

              return CustomScrollView(
                slivers: [
                  // Add padding for app bar
                  SliverTopPadding(extraTopPadding: extraTopPadding),

                  // Show pinned section if following tab and has pinned channels
                  if (isFollowingTab && pinnedChannelCount > 0) ...[
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) => SectionHeader(
                          'Pinned',
                          isFirst: true,
                          padding: EdgeInsets.fromLTRB(
                            16 + MediaQuery.of(context).padding.left,
                            8,
                            16 + MediaQuery.of(context).padding.right,
                            8,
                          ),
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: pinnedChannelCount,
                      itemBuilder: (context, index) {
                        if (isLargeCard) {
                          return LargeStreamCardSkeletonLoader(
                            showThumbnail: settingsStore.showThumbnails,
                            showCategory: widget.listType != ListType.category,
                          );
                        } else {
                          return StreamCardSkeletonLoader(
                            showThumbnail: settingsStore.showThumbnails,
                            showCategory: widget.listType != ListType.category,
                          );
                        }
                      },
                    ),
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) => SectionHeader(
                          'All',
                          isFirst: true,
                          padding: EdgeInsets.fromLTRB(
                            16 + MediaQuery.of(context).padding.left,
                            8,
                            16 + MediaQuery.of(context).padding.right,
                            8,
                          ),
                        ),
                      ),
                    ),
                  ],

                  SliverList.builder(
                    itemCount: isFollowingTab && pinnedChannelCount > 0 ? 5 : 8,
                    itemBuilder: (context, index) {
                      if (isLargeCard) {
                        return LargeStreamCardSkeletonLoader(
                          showThumbnail: settingsStore.showThumbnails,
                          showCategory: widget.listType != ListType.category,
                        );
                      } else {
                        return StreamCardSkeletonLoader(
                          showThumbnail: settingsStore.showThumbnails,
                          showCategory: widget.listType != ListType.category,
                        );
                      }
                    },
                  ),
                  SliverBottomPadding(),
                ],
              );
            } else {
              statusWidget = AlertMessage(
                message: widget.listType == ListType.followed
                    ? 'No followed streams'
                    : 'No top streams',
                vertical: true,
              );
            }
          }

          if (statusWidget != null) {
            return CustomScrollView(
              slivers: [
                SliverFillRemaining(child: Center(child: statusWidget)),
              ],
            );
          }

          final settingsStore = context.watch<SettingsStore>();

          final streams = _listStore.streams;

          final isFollowingTab = widget.listType == ListType.followed;

          return Stack(
            alignment: AlignmentDirectional.bottomCenter,
            children: [
              Column(
                children: [
                  Expanded(
                    child: KrostyScrollbar(
                      controller: _listStore.scrollController,
                      padding: EdgeInsets.only(
                        top:
                            MediaQuery.of(context).padding.top +
                            extraTopPadding,
                        bottom: MediaQuery.of(context).padding.bottom,
                      ),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: _listStore.scrollController,
                        slivers: [
                          SliverTopPadding(extraTopPadding: extraTopPadding),

                          // For followed tab, show live streams first, then offline
                          if (isFollowingTab) ...[
                            // Live streams
                            SliverList.builder(
                              itemCount: _listStore.liveStreams.length,
                              itemBuilder: (context, index) {
                                final liveStreams = _listStore.liveStreams;
                                if (index > liveStreams.length - 10 &&
                                    _listStore.hasMore) {
                                  _listStore.getStreams();
                                }
                                return Observer(
                                  builder: (context) =>
                                      settingsStore.largeStreamCard
                                      ? LargeStreamCard(
                                          key: ValueKey(liveStreams[index].id),
                                          streamInfo: liveStreams[index],
                                          showThumbnail:
                                              settingsStore.showThumbnails,
                                          showCategory:
                                              widget.categoryId == null,
                                          showPinOption: true,
                                          isPinned: false,
                                        )
                                      : StreamCard(
                                          key: ValueKey(liveStreams[index].id),
                                          streamInfo: liveStreams[index],
                                          showThumbnail:
                                              settingsStore.showThumbnails,
                                          showCategory:
                                              widget.categoryId == null,
                                          showPinOption: true,
                                          isPinned: false,
                                        ),
                                );
                              },
                            ),
                            // Offline channels section
                            if (_listStore.offlineChannels.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Observer(
                                  builder: (context) => ExpandableSectionHeader(
                                    'Offline',
                                    isFirst: true,
                                    padding: EdgeInsets.fromLTRB(
                                      16 + MediaQuery.of(context).padding.left,
                                      16,
                                      16 + MediaQuery.of(context).padding.right,
                                      8,
                                    ),
                                    isExpanded:
                                        _listStore.isOfflineChannelsExpanded,
                                    onToggle: () =>
                                        _listStore.isOfflineChannelsExpanded =
                                            !_listStore
                                                .isOfflineChannelsExpanded,
                                  ),
                                ),
                              ),
                              if (_listStore.isOfflineChannelsExpanded)
                                SliverList.builder(
                                  itemCount: _listStore.offlineChannels.length,
                                  itemBuilder: (context, index) {
                                    // Load more offline channels when nearing the end
                                    if (index >
                                            _listStore.offlineChannels.length -
                                                5 &&
                                        _listStore.hasMoreOfflineChannels) {
                                      _listStore.loadMoreOfflineChannels();
                                    }
                                    return Observer(
                                      builder: (context) => OfflineChannelCard(
                                        key: ValueKey(
                                          _listStore
                                              .offlineChannels[index]
                                              .channelSlug,
                                        ),
                                        channelInfo:
                                            _listStore.offlineChannels[index],
                                        showPinOption: false,
                                        isPinned: false,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ] else
                            // For non-followed tabs, show all streams as before
                            SliverList.builder(
                              itemCount: streams.length,
                              itemBuilder: (context, index) {
                                if (index > streams.length - 10 &&
                                    _listStore.hasMore) {
                                  _listStore.getStreams();
                                }
                                return Observer(
                                  builder: (context) =>
                                      settingsStore.largeStreamCard
                                      ? LargeStreamCard(
                                          key: ValueKey(streams[index].id),
                                          streamInfo: streams[index],
                                          showThumbnail:
                                              settingsStore.showThumbnails,
                                          showCategory:
                                              widget.categoryId == null,
                                          isPinned: false,
                                        )
                                      : StreamCard(
                                          key: ValueKey(streams[index].id),
                                          streamInfo: streams[index],
                                          showThumbnail:
                                              settingsStore.showThumbnails,
                                          showCategory:
                                              widget.categoryId == null,
                                          isPinned: false,
                                        ),
                                );
                              },
                            ),
                          // Add padding for bottom navigation bar
                          const SliverBottomPadding(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.showJumpButton)
                Observer(
                  builder: (context) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _listStore.showJumpButton
                        ? ScrollToTopButton(
                            scrollController: _listStore.scrollController!,
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Helper widget for consistent top padding in sliver lists
class SliverTopPadding extends StatelessWidget {
  final double extraTopPadding;

  const SliverTopPadding({super.key, this.extraTopPadding = 0.0});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: MediaQuery.of(context).padding.top + extraTopPadding,
      ),
    );
  }
}

/// Helper widget for consistent bottom padding in sliver lists
class SliverBottomPadding extends StatelessWidget {
  const SliverBottomPadding({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(height: MediaQuery.of(context).padding.bottom),
    );
  }
}
