import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'src/app.dart';
part 'src/models.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const JellyfinPlayerApp());
}
