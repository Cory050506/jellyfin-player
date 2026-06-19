part of '../../main.dart';

/// Manages all native platform features (hotkeys, tray, acrylic, etc.)
class NativeFeatures {
  static final NativeFeatures _instance = NativeFeatures._internal();

  factory NativeFeatures() {
    return _instance;
  }

  NativeFeatures._internal();

  /// Initialize all native features based on platform
  Future<void> initialize({
    required VoidCallback onTrayExit,
    required VoidCallback onTrayShow,
  }) async {
    if (isDesktopPlatform) {
      // Initialize protocol handler for jellyfin:// URLs
      await _initializeProtocolHandler();

      // Initialize tray manager for system tray
      if (Platform.isWindows || Platform.isMacOS) {
        await _initializeTray(onTrayExit: onTrayExit, onTrayShow: onTrayShow);
      }

      // Initialize screen retriever (works on all desktop platforms)
      await _initializeScreenRetriever();
    }
  }

  /// Setup system tray icon and menu
  Future<void> _initializeTray({
    required VoidCallback onTrayExit,
    required VoidCallback onTrayShow,
  }) async {
    try {
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/icon.png' : 'assets/icon.png',
      );

      Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show',
            label: 'Show',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: 'Exit',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
      trayManager.addListener(_TrayListener(
        onExit: onTrayExit,
        onShow: onTrayShow,
      ));

      debugPrint('✅ System tray initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize tray: $e');
    }
  }

  /// Setup protocol handler for jellyfin:// URLs
  Future<void> _initializeProtocolHandler() async {
    try {
      await protocolHandler.register('jellyfin');
      debugPrint('✅ Protocol handler registered for jellyfin://');
    } catch (e) {
      debugPrint('❌ Failed to register protocol handler: $e');
    }
  }

  /// Initialize screen retriever for display info
  Future<void> _initializeScreenRetriever() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      debugPrint('✅ Screen retriever initialized (${displays.length} displays)');
    } catch (e) {
      debugPrint('❌ Failed to initialize screen retriever: $e');
    }
  }

  /// Get primary display info
  Future<Display?> getPrimaryDisplay() async {
    try {
      return await screenRetriever.getPrimaryDisplay();
    } catch (e) {
      debugPrint('Error getting primary display: $e');
      return null;
    }
  }

  /// Get all displays
  Future<List<Display>> getAllDisplays() async {
    try {
      return await screenRetriever.getAllDisplays();
    } catch (e) {
      debugPrint('Error getting all displays: $e');
      return [];
    }
  }

  /// Show tray
  Future<void> showTray() async {
    try {
      // Tray manager doesn't have show/hide in newer versions
      // but the menu can be shown via popUpContextMenu
      await trayManager.popUpContextMenu();
    } catch (e) {
      debugPrint('Error showing tray: $e');
    }
  }
}

/// Tray listener for handling tray events
class _TrayListener extends TrayListener {
  final VoidCallback onExit;
  final VoidCallback onShow;

  _TrayListener({
    required this.onExit,
    required this.onShow,
  });

  @override
  void onTrayIconMouseDown() {
    onShow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'exit') {
      onExit();
    } else if (menuItem.key == 'show') {
      onShow();
    }
  }
}
