import 'dart:async';

import 'package:flutter/material.dart';
import 'package:krosty/apis/kick_api.dart';
import 'package:krosty/models/kick_channel.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/utils/modal_bottom_sheet.dart';
import 'package:krosty/widgets/alert_message.dart';
import 'package:krosty/widgets/animated_scroll_border.dart';
import 'package:krosty/widgets/live_indicator.dart';
import 'package:krosty/widgets/profile_picture.dart';
import 'package:krosty/widgets/section_header.dart';
import 'package:krosty/widgets/skeleton_loader.dart';

/// Data class returned when a channel is selected in the AddChatSheet.
class AddChatResult {
  final int channelId;
  final String channelSlug;
  final String displayName;

  const AddChatResult({
    required this.channelId,
    required this.channelSlug,
    required this.displayName,
  });
}

/// Bottom sheet for adding a new chat tab by searching for a Kick channel.
class AddChatSheet extends StatefulWidget {
  final KickApi kickApi;

  const AddChatSheet({super.key, required this.kickApi});

  /// Shows the bottom sheet and returns the selected channel info, or null if cancelled.
  static Future<AddChatResult?> show(
    BuildContext context,
    KickApi kickApi,
  ) {
    return showModalBottomSheetWithProperFocus<AddChatResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddChatSheet(kickApi: kickApi),
    );
  }

  @override
  State<AddChatSheet> createState() => _AddChatSheetState();
}

class _AddChatSheetState extends State<AddChatSheet> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  Timer? _debounce;
  bool _isLoading = false;
  String? _errorMessage;
  List<KickChannelSearch> _results = [];

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Cancel any existing debounce
    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Debounce the search by 300ms
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final channels = await widget.kickApi.searchChannels(query: query);
        if (mounted) {
          setState(() {
            _results = channels;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _results = [];
            _isLoading = false;
            _errorMessage = 'Failed to search channels';
          });
        }
      }
    });
  }

  void _selectChannel(KickChannelSearch channel) {
    Navigator.of(context).pop(
      AddChatResult(
        channelId: channel.id,
        channelSlug: channel.slug,
        displayName: channel.username,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Add Chat', isFirst: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                autocorrect: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search for a channel',
                  suffixIcon:
                      _focusNode.hasFocus || _textController.text.isNotEmpty
                          ? IconButton(
                              tooltip: _textController.text.isEmpty
                                  ? 'Cancel'
                                  : 'Clear',
                              onPressed: () {
                                if (_textController.text.isEmpty) {
                                  _focusNode.unfocus();
                                }
                                _textController.clear();
                                _onSearchChanged('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                ),
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
              ),
            ),
            AnimatedScrollBorder(scrollController: _scrollController),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_textController.text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Search for a channel to add',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return ListView.builder(
        controller: _scrollController,
        itemCount: 8,
        itemBuilder: (context, index) => ChannelSkeletonLoader(index: index),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AlertMessage(message: _errorMessage!),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No channels found',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final channel = _results[index];
        final displayName = getReadableName(
          channel.username,
          channel.slug,
        );

        return ListTile(
          leading: ProfilePicture(
            userLogin: channel.slug,
            profileUrl: channel.profilePic,
            radius: 16,
          ),
          title: Text(displayName),
          subtitle: channel.isLive
              ? Row(
                  spacing: 6,
                  children: [
                    const LiveIndicator(),
                    // Uptime not available in search results
                  ],
                )
              : null,
          onTap: () => _selectChannel(channel),
        );
      },
    );
  }
}

// Keep backward compatibility alias
typedef AddChatDialog = AddChatSheet;
