import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krosty/constants.dart';
import 'package:krosty/models/emotes.dart';
import 'package:krosty/models/kick_message_renderer.dart';
import 'package:krosty/screens/channel/chat/stores/chat_store.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/utils/context_extensions.dart';
import 'package:krosty/widgets/krosty_cached_network_image.dart';
import 'package:provider/provider.dart';

class EmoteMenuSection extends StatefulWidget {
  final ChatStore chatStore;
  final List<Emote> emotes;
  final bool disabled;

  const EmoteMenuSection({
    super.key,
    required this.chatStore,
    required this.emotes,
    this.disabled = false,
  });

  @override
  State<EmoteMenuSection> createState() => _EmoteMenuSectionState();
}

class _EmoteMenuSectionState extends State<EmoteMenuSection>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.isPortrait
              ? 8
              : context.read<SettingsStore>().showVideo
              ? 6
              : 16,
        ),
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) => InkWell(
          onTap: widget.disabled
              ? null
              : () => widget.chatStore.addEmote(widget.emotes[index]),
          onLongPress: () {
            HapticFeedback.lightImpact();

            showEmoteDetailsBottomSheet(
              context,
              emote: widget.emotes[index],
              launchExternal: widget.chatStore.settings.launchUrlExternal,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Center(
              child: KrostyCachedNetworkImage(
                imageUrl: widget.emotes[index].lowQualityUrl,
                height:
                    widget.emotes[index].height?.toDouble() ?? defaultEmoteSize,
                width: widget.emotes[index].width?.toDouble(),
                color: widget.disabled
                    ? const Color.fromRGBO(255, 255, 255, 0.5)
                    : null,
                colorBlendMode: widget.disabled ? BlendMode.modulate : null,
              ),
            ),
          ),
        ),
        itemCount: widget.emotes.length,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
