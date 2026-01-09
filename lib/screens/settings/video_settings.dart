import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/screens/settings/widgets/settings_list_switch.dart';
import 'package:krosty/utils.dart';
import 'package:krosty/widgets/section_header.dart';
import 'package:krosty/widgets/settings_page_layout.dart';

class VideoSettings extends StatelessWidget {
  final SettingsStore settingsStore;

  const VideoSettings({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => SettingsPageLayout(
        children: [
          const SectionHeader('Player', isFirst: true),
          SettingsListSwitch(
            title: 'Enable video',
            value: settingsStore.showVideo,
            onChanged: (newValue) => settingsStore.showVideo = newValue,
          ),
          if (!Platform.isIOS || isIPad())
            SettingsListSwitch(
              title: 'Default to highest quality',
              value: settingsStore.defaultToHighestQuality,
              onChanged: (newValue) =>
                  settingsStore.defaultToHighestQuality = newValue,
            ),
          const SectionHeader('Overlay'),
          SettingsListSwitch(
            title: 'Use custom video overlay',
            subtitle: const Text(
              'Replaces the default player controls with a mobile-friendly overlay.',
            ),
            value: settingsStore.showOverlay,
            onChanged: (newValue) => settingsStore.showOverlay = newValue,
          ),
          SettingsListSwitch(
            title: 'Long-press player to toggle overlay',
            subtitle: const Text(
              'Allows switching between the default and custom overlay.',
            ),
            value: settingsStore.toggleableOverlay,
            onChanged: (newValue) => settingsStore.toggleableOverlay = newValue,
          ),
        ],
      ),
    );
  }
}
