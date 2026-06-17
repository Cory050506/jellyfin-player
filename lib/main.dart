import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:better_native_video_player/better_native_video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:window_manager/window_manager.dart';

part 'src/app.dart';
part 'src/models.dart';
part 'src/services/app_settings_store.dart';
part 'src/services/jellyfin_client.dart';
part 'src/utils.dart';
part 'src/widgets/media_artwork.dart';
part 'src/widgets/status_panes.dart';
part 'src/screens/session_gate.dart';
part 'src/screens/login_screen.dart';
part 'src/screens/home_screen.dart';
part 'src/screens/items_view.dart';
part 'src/screens/item_screen.dart';
part 'src/screens/player_screen.dart';
part 'src/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
  }
  runApp(const JellyfinPlayerApp());
}
