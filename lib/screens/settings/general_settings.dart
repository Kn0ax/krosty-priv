import 'package:flutter/material.dart';
// import removed: flutter_colorpicker
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:krosty/screens/settings/stores/settings_store.dart';
import 'package:krosty/screens/settings/widgets/settings_list_switch.dart';
import 'package:krosty/widgets/accent_color_setting.dart';
import 'package:krosty/widgets/external_browser_setting.dart';
// 
import 'package:krosty/widgets/section_header.dart';
import 'package:krosty/widgets/settings_page_layout.dart';
import 'package:krosty/widgets/theme_selection_setting.dart';

class GeneralSettings extends StatelessWidget {
  final SettingsStore settingsStore;

  const GeneralSettings({super.key, required this.settingsStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => SettingsPageLayout(
        children: [
          const SectionHeader('Theme', isFirst: true),
          ThemeSelectionSetting(settingsStore: settingsStore),
          AccentColorSetting(settingsStore: settingsStore),
          const SectionHeader('Stream card'),
          SettingsListSwitch(
            title: 'Use large stream card',
            value: settingsStore.largeStreamCard,
            onChanged: (newValue) => settingsStore.largeStreamCard = newValue,
          ),
          SettingsListSwitch(
            title: 'Show thumbnail',
            value: settingsStore.showThumbnails,
            onChanged: (newValue) => settingsStore.showThumbnails = newValue,
          ),
          const SectionHeader('Links'),
          ExternalBrowserSetting(settingsStore: settingsStore),
        ],
      ),
    );
  }
}
