import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/apis/base_api_client.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/screens/channel/channel.dart';
import 'package:krosty/screens/home/search/search_store.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/utils/modal_bottom_sheet.dart';
import 'package:krosty/widgets/alert_message.dart';
import 'package:krosty/widgets/live_indicator.dart';
import 'package:krosty/widgets/profile_picture.dart';
import 'package:krosty/widgets/skeleton_loader.dart';
import 'package:krosty/widgets/uptime.dart';
import 'package:krosty/widgets/user_actions_modal.dart';
import 'package:mobx/mobx.dart';

class SearchResultsChannels extends StatefulWidget {
  final SearchStore searchStore;
  final String query;

  const SearchResultsChannels({
    super.key,
    required this.searchStore,
    required this.query,
  });

  @override
  State<SearchResultsChannels> createState() => _SearchResultsChannelsState();
}

class _SearchResultsChannelsState extends State<SearchResultsChannels> {
  Future<void> _handleSearch(BuildContext context, String search) async {
    try {
      final channelInfo = await widget.searchStore.searchChannel(search);

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoChat(
            userId: channelInfo.id.toString(),
            userName: channelInfo.user.username,
            userLogin: channelInfo.slug,
          ),
        ),
      );
    } on ApiException catch (e) {
      debugPrint('Search channels ApiException: $e');
      final snackBar = SnackBar(
        content: AlertMessage(message: e.message, centered: false),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (error) {
      debugPrint('Search channels error: $error');
      final snackBar = SnackBar(
        content: AlertMessage(
          message: 'Unable to find channel',
          centered: false,
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final future = widget.searchStore.channelFuture;

        // Show skeletons immediately while waiting for debounce.
        if (future == null) {
          if (widget.searchStore.isSearching) {
            return SliverList.builder(
              itemCount: 8,
              itemBuilder: (context, index) =>
                  ChannelSkeletonLoader(index: index),
            );
          }
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        switch (future.status) {
          case FutureStatus.pending:
            return SliverList.builder(
              itemCount: 8,
              itemBuilder: (context, index) =>
                  ChannelSkeletonLoader(index: index),
            );
          case FutureStatus.rejected:
            return const SliverToBoxAdapter(
              child: SizedBox(
                height: 100.0,
                child: AlertMessage(
                  message: 'Unable to load channels',
                  vertical: true,
                ),
              ),
            );
          case FutureStatus.fulfilled:
            final results = (future.result as List<KickChannelSearch>);

            return SliverList.list(
              children: [
                ...results.map((channel) {
                  final displayName = getReadableName(
                    channel.username,
                    channel.slug,
                  );

                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoChat(
                          userId: channel.id.toString(),
                          userName: channel.username,
                          userLogin: channel.slug,
                        ),
                      ),
                    ),
                    onLongPress: () {
                      HapticFeedback.lightImpact();

                      showModalBottomSheetWithProperFocus(
                        context: context,
                        builder: (context) => UserActionsModal(
                          authStore: widget.searchStore.authStore,
                          name: displayName,
                          userLogin: channel.slug,
                          userId: channel.id.toString(),
                        ),
                      );
                    },
                    child: ListTile(
                      title: Text(displayName),
                      leading: ProfilePicture(
                        userLogin: channel.slug,
                        profileUrl: channel.profilePic,
                        radius: 16,
                      ),
                      subtitle: channel.isLive
                          ? Row(
                              spacing: 6,
                              children: [
                                const LiveIndicator(),
                                if (channel.startTime != null)
                                  Uptime(startTime: channel.startTime!),
                              ],
                            )
                          : null,
                    ),
                  );
                }),
                ListTile(
                  title: Text('Go to channel "${widget.query}"'),
                  onTap: () => _handleSearch(context, widget.query),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            );
        }
      },
    );
  }
}
