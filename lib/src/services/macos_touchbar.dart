part of '../../main.dart';

/// macOS Touch Bar integration — actual controls are set up in PlayerScreen
/// using the touch_bar package directly (setTouchBar / TouchBarButton).
class MacOSTouchBar {
  static final MacOSTouchBar _instance = MacOSTouchBar._internal();
  factory MacOSTouchBar() => _instance;
  MacOSTouchBar._internal();
}
