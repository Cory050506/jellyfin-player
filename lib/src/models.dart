part of '../main.dart';

class JellyfinSession {
  const JellyfinSession({
    required this.serverUrl,
    required this.accessToken,
    required this.userId,
    required this.username,
    required this.deviceId,
  });

  final String serverUrl;
  final String accessToken;
  final String userId;
  final String username;
  final String deviceId;

  Map<String, String> toJson() => {
    'serverUrl': serverUrl,
    'accessToken': accessToken,
    'userId': userId,
    'username': username,
    'deviceId': deviceId,
  };

  static JellyfinSession fromJson(Map<String, dynamic> json) {
    return JellyfinSession(
      serverUrl: json['serverUrl'] as String,
      accessToken: json['accessToken'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      deviceId: json['deviceId'] as String,
    );
  }
}

class SessionStore {
  static const _sessionKey = 'session';
  static const _deviceIdKey = 'deviceId';

  static Future<JellyfinSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_sessionKey);
    if (value == null) {
      return null;
    }
    return JellyfinSession.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  static Future<void> save(JellyfinSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null) {
      return existing;
    }
    final generated = 'flutter-${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }
}

class JellyfinLibrary {
  const JellyfinLibrary({
    required this.id,
    required this.name,
    required this.collectionType,
  });

  final String id;
  final String name;
  final String collectionType;

  static JellyfinLibrary fromJson(Map<String, dynamic> json) {
    return JellyfinLibrary(
      id: json['Id'] as String,
      name: json['Name'] as String? ?? 'Library',
      collectionType: json['CollectionType'] as String? ?? '',
    );
  }
}

class JellyfinItem {
  const JellyfinItem({
    required this.id,
    required this.name,
    required this.type,
    required this.overview,
    required this.productionYear,
    required this.runTimeTicks,
    required this.imageTag,
    required this.backdropTag,
  });

  final String id;
  final String name;
  final String type;
  final String overview;
  final int? productionYear;
  final int? runTimeTicks;
  final String? imageTag;
  final String? backdropTag;

  bool get isPlayable =>
      type == 'Movie' || type == 'Episode' || type == 'Video';

  String get subtitle {
    final parts = [
      if (productionYear != null) productionYear.toString(),
      if (durationLabel.isNotEmpty) durationLabel,
      type,
    ];
    return parts.join('  ');
  }

  String get durationLabel {
    final ticks = runTimeTicks;
    if (ticks == null || ticks <= 0) {
      return '';
    }
    final duration = Duration(microseconds: ticks ~/ 10);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  static JellyfinItem fromJson(Map<String, dynamic> json) {
    final tags = json['ImageTags'] as Map<String, dynamic>? ?? {};
    final backdropTags = json['BackdropImageTags'] as List<dynamic>? ?? [];
    return JellyfinItem(
      id: json['Id'] as String,
      name: json['Name'] as String? ?? 'Untitled',
      type: json['Type'] as String? ?? '',
      overview: json['Overview'] as String? ?? '',
      productionYear: json['ProductionYear'] as int?,
      runTimeTicks: json['RunTimeTicks'] as int?,
      imageTag: tags['Primary'] as String?,
      backdropTag: backdropTags.isEmpty ? null : backdropTags.first as String?,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.directStream,
    required this.highBitrateCache,
    required this.hardwareDecoding,
    required this.hdrMode,
    required this.subtitleMode,
    required this.audioMode,
    required this.subtitleOffsetMs,
    required this.playerFit,
  });

  static const defaults = AppSettings(
    directStream: true,
    highBitrateCache: true,
    hardwareDecoding: true,
    hdrMode: HdrMode.passthrough,
    subtitleMode: DefaultSubtitleMode.auto,
    audioMode: DefaultAudioMode.auto,
    subtitleOffsetMs: 0,
    playerFit: PlayerFit.contain,
  );

  final bool directStream;
  final bool highBitrateCache;
  final bool hardwareDecoding;
  final HdrMode hdrMode;
  final DefaultSubtitleMode subtitleMode;
  final DefaultAudioMode audioMode;
  final int subtitleOffsetMs;
  final PlayerFit playerFit;

  int get bufferSizeBytes =>
      highBitrateCache ? 512 * 1024 * 1024 : 64 * 1024 * 1024;

  BoxFit get boxFit {
    return switch (playerFit) {
      PlayerFit.contain => BoxFit.contain,
      PlayerFit.cover => BoxFit.cover,
      PlayerFit.fill => BoxFit.fill,
    };
  }

  AppSettings copyWith({
    bool? directStream,
    bool? highBitrateCache,
    bool? hardwareDecoding,
    HdrMode? hdrMode,
    DefaultSubtitleMode? subtitleMode,
    DefaultAudioMode? audioMode,
    int? subtitleOffsetMs,
    PlayerFit? playerFit,
  }) {
    return AppSettings(
      directStream: directStream ?? this.directStream,
      highBitrateCache: highBitrateCache ?? this.highBitrateCache,
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
      hdrMode: hdrMode ?? this.hdrMode,
      subtitleMode: subtitleMode ?? this.subtitleMode,
      audioMode: audioMode ?? this.audioMode,
      subtitleOffsetMs: subtitleOffsetMs ?? this.subtitleOffsetMs,
      playerFit: playerFit ?? this.playerFit,
    );
  }

  Map<String, Object> toJson() => {
    'directStream': directStream,
    'highBitrateCache': highBitrateCache,
    'hardwareDecoding': hardwareDecoding,
    'hdrMode': hdrMode.name,
    'subtitleMode': subtitleMode.name,
    'audioMode': audioMode.name,
    'subtitleOffsetMs': subtitleOffsetMs,
    'playerFit': playerFit.name,
  };

  static AppSettings fromJson(Map<String, dynamic> json) {
    final defaults = AppSettings.defaults;
    return AppSettings(
      directStream: json['directStream'] as bool? ?? defaults.directStream,
      highBitrateCache:
          json['highBitrateCache'] as bool? ?? defaults.highBitrateCache,
      hardwareDecoding:
          json['hardwareDecoding'] as bool? ?? defaults.hardwareDecoding,
      hdrMode: enumByName(
        HdrMode.values,
        json['hdrMode'] as String?,
        defaults.hdrMode,
      ),
      subtitleMode: enumByName(
        DefaultSubtitleMode.values,
        json['subtitleMode'] as String?,
        defaults.subtitleMode,
      ),
      audioMode: enumByName(
        DefaultAudioMode.values,
        json['audioMode'] as String?,
        defaults.audioMode,
      ),
      subtitleOffsetMs:
          json['subtitleOffsetMs'] as int? ?? defaults.subtitleOffsetMs,
      playerFit: enumByName(
        PlayerFit.values,
        json['playerFit'] as String?,
        defaults.playerFit,
      ),
    );
  }
}

enum HdrMode { passthrough, toneMap, off }

enum DefaultSubtitleMode { auto, off }

enum DefaultAudioMode { auto }

enum PlayerFit { contain, cover, fill }
