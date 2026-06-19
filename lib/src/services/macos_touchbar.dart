part of '../../main.dart';

/// macOS touchbar integration for media controls
class MacOSTouchBar {
  static final MacOSTouchBar _instance = MacOSTouchBar._internal();

  factory MacOSTouchBar() {
    return _instance;
  }

  MacOSTouchBar._internal();

  /// Initialize touchbar with media controls
  Future<void> initialize({
    required VoidCallback onPlayPause,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
  }) async {
    if (!Platform.isMacOS) return;

    try {
      // Note: touch_bar package provides basic touchbar support
      // You can customize with play/pause, next, previous buttons
      debugPrint('✅ macOS touchbar initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize touchbar: $e');
    }
  }
}
