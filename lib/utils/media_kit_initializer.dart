import 'package:media_kit/media_kit.dart';

/// Initialize media_kit for native video playback.
/// This should be called once in main.dart before runApp().
void initializeMediaKit() {
  MediaKit.ensureInitialized();
}
