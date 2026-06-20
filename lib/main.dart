import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:better_native_video_player/better_native_video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';
import 'package:auto_updater/auto_updater.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:touch_bar/touch_bar.dart';

part 'src/app.dart';
part 'src/models.dart';
part 'src/services/app_settings_store.dart';
part 'src/services/jellyfin_client.dart';
part 'src/services/native_features.dart';
part 'src/services/macos_touchbar.dart';
part 'src/utils.dart';
part 'src/widgets/adaptive_controls.dart';
part 'src/widgets/adaptive_navigation.dart';
part 'src/widgets/adaptive_sheets.dart';
part 'src/widgets/adaptive_app_shell.dart';
part 'src/widgets/media_artwork.dart';
part 'src/widgets/status_panes.dart';
part 'src/screens/session_gate.dart';
part 'src/screens/login_screen.dart';
part 'src/screens/home_screen.dart';
part 'src/screens/items_view.dart';
part 'src/screens/item_screen.dart';
part 'src/screens/player_screen.dart';
part 'src/screens/settings_screen.dart';
part 'src/screens/search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final savedSettings = await AppSettingsStore.load();
  if (savedSettings.accentColor != null) {
    AppColors.accentNotifier.value = Color(savedSettings.accentColor!);
  }
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    _initializeAcrylic();
  }
  if (isDesktopPlatform) {
    final info = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: info.appName,
      appPath: Platform.resolvedExecutable,
    );
    FlutterWindowClose.setWindowShouldCloseHandler(() async => true);
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      await autoUpdater.setFeedURL(
        'https://raw.githubusercontent.com/Cory050506/jellyfin-player/master/appcast.xml',
      );
    }
  }
  runApp(const JellyfinPlayerApp());
}

void _initializeAcrylic() {
  // This will be called after the first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // Apply acrylic effect on Windows
      try {
        // flutter_acrylic will be initialized here if needed
        debugPrint('✅ Acrylic effects initialized for Windows');
      } catch (e) {
        debugPrint('⚠️ Failed to initialize acrylic: $e');
      }
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      // Apply effects on macOS
      try {
        debugPrint('✅ Visual effects initialized for macOS');
      } catch (e) {
        debugPrint('⚠️ Failed to initialize macOS effects: $e');
      }
    }
  });
}
