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
    required this.parentIndexNumber,
    required this.indexNumber,
    required this.seriesName,
    required this.seasonName,
    required this.playbackPositionTicks,
    required this.mediaStreams,
    required this.people,
  });

  final String id;
  final String name;
  final String type;
  final String overview;
  final int? productionYear;
  final int? runTimeTicks;
  final String? imageTag;
  final String? backdropTag;
  final int? parentIndexNumber;
  final int? indexNumber;
  final String? seriesName;
  final String? seasonName;
  final int playbackPositionTicks;
  final List<JellyfinMediaStream> mediaStreams;
  final List<JellyfinPerson> people;

  bool get isPlayable =>
      type == 'Movie' || type == 'Episode' || type == 'Video';

  String get subtitle {
    final parts = [
      if (productionYear != null) productionYear.toString(),
      if (durationLabel.isNotEmpty) durationLabel,
      if (episodeCode.isNotEmpty) episodeCode,
      type,
    ];
    return parts.join('  ');
  }

  String get displayTitle {
    if (type == 'Episode' && seriesName != null && episodeCode.isNotEmpty) {
      return '$seriesName  $episodeCode  $name';
    }
    return name;
  }

  String get episodeCode {
    if (parentIndexNumber == null && indexNumber == null) {
      return '';
    }
    final season = parentIndexNumber == null
        ? ''
        : 'S${parentIndexNumber.toString().padLeft(2, '0')}';
    final episode = indexNumber == null
        ? ''
        : 'E${indexNumber.toString().padLeft(2, '0')}';
    return '$season$episode';
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

  Duration get resumePosition =>
      Duration(microseconds: playbackPositionTicks ~/ 10);

  List<JellyfinMediaStream> get audioStreams =>
      mediaStreams.where((stream) => stream.type == 'Audio').toList();

  List<JellyfinMediaStream> get subtitleStreams =>
      mediaStreams.where((stream) => stream.type == 'Subtitle').toList();

  static JellyfinItem fromJson(Map<String, dynamic> json) {
    final tags = json['ImageTags'] as Map<String, dynamic>? ?? {};
    final backdropTags = json['BackdropImageTags'] as List<dynamic>? ?? [];
    final mediaSources = json['MediaSources'] as List<dynamic>? ?? [];
    final userData = json['UserData'] as Map<String, dynamic>? ?? {};
    final streams = mediaSources.isEmpty
        ? <dynamic>[]
        : (mediaSources.first as Map<String, dynamic>)['MediaStreams']
                  as List<dynamic>? ??
              [];
    return JellyfinItem(
      id: json['Id'] as String,
      name: json['Name'] as String? ?? 'Untitled',
      type: json['Type'] as String? ?? '',
      overview: json['Overview'] as String? ?? '',
      productionYear: json['ProductionYear'] as int?,
      runTimeTicks: json['RunTimeTicks'] as int?,
      imageTag: tags['Primary'] as String?,
      backdropTag: backdropTags.isEmpty ? null : backdropTags.first as String?,
      parentIndexNumber: json['ParentIndexNumber'] as int?,
      indexNumber: json['IndexNumber'] as int?,
      seriesName: json['SeriesName'] as String?,
      seasonName: json['SeasonName'] as String?,
      playbackPositionTicks:
          (userData['PlaybackPositionTicks'] as num?)?.toInt() ?? 0,
      mediaStreams: streams
          .map(
            (stream) =>
                JellyfinMediaStream.fromJson(stream as Map<String, dynamic>),
          )
          .toList(),
      people: (json['People'] as List<dynamic>? ?? [])
          .map(
            (person) => JellyfinPerson.fromJson(person as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class JellyfinMediaStream {
  const JellyfinMediaStream({
    required this.index,
    required this.type,
    required this.displayTitle,
    required this.language,
    required this.codec,
    required this.isDefault,
    required this.isForced,
  });

  final int index;
  final String type;
  final String displayTitle;
  final String? language;
  final String? codec;
  final bool isDefault;
  final bool isForced;

  String get label {
    final parts = [
      if (displayTitle.isNotEmpty) displayTitle,
      if (language != null && language!.isNotEmpty) language!,
      if (codec != null && codec!.isNotEmpty) codec!,
      if (isDefault) 'Default',
      if (isForced) 'Forced',
    ];
    return parts.isEmpty ? '$type track $index' : parts.join('  ');
  }

  static JellyfinMediaStream fromJson(Map<String, dynamic> json) {
    return JellyfinMediaStream(
      index: json['Index'] as int? ?? -1,
      type: json['Type'] as String? ?? '',
      displayTitle: json['DisplayTitle'] as String? ?? '',
      language: json['Language'] as String?,
      codec: json['Codec'] as String?,
      isDefault: json['IsDefault'] as bool? ?? false,
      isForced: json['IsForced'] as bool? ?? false,
    );
  }
}

class JellyfinPerson {
  const JellyfinPerson({
    required this.id,
    required this.name,
    required this.role,
    required this.type,
    required this.imageTag,
  });

  final String id;
  final String name;
  final String role;
  final String type;
  final String? imageTag;

  static JellyfinPerson fromJson(Map<String, dynamic> json) {
    final tags = json['ImageTags'] as Map<String, dynamic>? ?? {};
    return JellyfinPerson(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? 'Unknown',
      role: json['Role'] as String? ?? '',
      type: json['Type'] as String? ?? '',
      imageTag: tags['Primary'] as String?,
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
    required this.preferredAudioLanguage,
    required this.subtitleOffsetMs,
    required this.playerFit,
    required this.sidebarCollapsed,
    required this.libraryOrder,
    required this.hiddenLibraries,
    required this.pinnedNavLibraries,
    required this.skipDurationSeconds,
    required this.autoPlayNextEpisode,
    required this.resumeBehavior,
    required this.accentColor,
  });

  static const defaults = AppSettings(
    directStream: true,
    highBitrateCache: true,
    hardwareDecoding: true,
    hdrMode: HdrMode.passthrough,
    subtitleMode: DefaultSubtitleMode.auto,
    preferredAudioLanguage: '',
    subtitleOffsetMs: 0,
    playerFit: PlayerFit.contain,
    sidebarCollapsed: false,
    libraryOrder: <String>[],
    hiddenLibraries: <String>[],
    pinnedNavLibraries: <String>[],
    skipDurationSeconds: 30,
    autoPlayNextEpisode: true,
    resumeBehavior: ResumeBehavior.ask,
    accentColor: null,
  );

  final bool directStream;
  final bool highBitrateCache;
  final bool hardwareDecoding;
  final HdrMode hdrMode;
  final DefaultSubtitleMode subtitleMode;
  /// ISO 639 language code or display name, e.g. "eng", "en", "English".
  /// Empty string means use the file's default track.
  final String preferredAudioLanguage;
  final int subtitleOffsetMs;
  final PlayerFit playerFit;

  /// Whether the home-screen sidebar shows icons only.
  final bool sidebarCollapsed;
  /// Library ids in the user's preferred display order. Ids not listed fall
  /// back to the server's order, after the listed ones.
  final List<String> libraryOrder;
  /// Library ids the user has chosen to hide from the sidebar.
  final List<String> hiddenLibraries;
  /// Library ids pinned to the iOS nav bar (max 4). Empty = auto first 4.
  final List<String> pinnedNavLibraries;
  /// Seconds to skip back/forward in the player controls.
  final int skipDurationSeconds;
  /// Whether to automatically play the next episode when one finishes.
  final bool autoPlayNextEpisode;
  /// What to do when an item has a saved resume position.
  final ResumeBehavior resumeBehavior;
  /// Accent color as ARGB int, or null to use the default cyan.
  final int? accentColor;

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
    String? preferredAudioLanguage,
    int? subtitleOffsetMs,
    PlayerFit? playerFit,
    bool? sidebarCollapsed,
    List<String>? libraryOrder,
    List<String>? hiddenLibraries,
    List<String>? pinnedNavLibraries,
    int? skipDurationSeconds,
    bool? autoPlayNextEpisode,
    ResumeBehavior? resumeBehavior,
    Object? accentColor = _sentinel,
  }) {
    return AppSettings(
      directStream: directStream ?? this.directStream,
      highBitrateCache: highBitrateCache ?? this.highBitrateCache,
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
      hdrMode: hdrMode ?? this.hdrMode,
      subtitleMode: subtitleMode ?? this.subtitleMode,
      preferredAudioLanguage:
          preferredAudioLanguage ?? this.preferredAudioLanguage,
      subtitleOffsetMs: subtitleOffsetMs ?? this.subtitleOffsetMs,
      playerFit: playerFit ?? this.playerFit,
      sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      libraryOrder: libraryOrder ?? this.libraryOrder,
      hiddenLibraries: hiddenLibraries ?? this.hiddenLibraries,
      pinnedNavLibraries: pinnedNavLibraries ?? this.pinnedNavLibraries,
      skipDurationSeconds: skipDurationSeconds ?? this.skipDurationSeconds,
      autoPlayNextEpisode: autoPlayNextEpisode ?? this.autoPlayNextEpisode,
      resumeBehavior: resumeBehavior ?? this.resumeBehavior,
      accentColor: accentColor == _sentinel ? this.accentColor : accentColor as int?,
    );
  }

  static const _sentinel = Object();

  Map<String, Object?> toJson() => {
    'directStream': directStream,
    'highBitrateCache': highBitrateCache,
    'hardwareDecoding': hardwareDecoding,
    'hdrMode': hdrMode.name,
    'subtitleMode': subtitleMode.name,
    'preferredAudioLanguage': preferredAudioLanguage,
    'subtitleOffsetMs': subtitleOffsetMs,
    'playerFit': playerFit.name,
    'sidebarCollapsed': sidebarCollapsed,
    'libraryOrder': libraryOrder,
    'hiddenLibraries': hiddenLibraries,
    'pinnedNavLibraries': pinnedNavLibraries,
    'skipDurationSeconds': skipDurationSeconds,
    'autoPlayNextEpisode': autoPlayNextEpisode,
    'resumeBehavior': resumeBehavior.name,
    'accentColor': accentColor,
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
      preferredAudioLanguage:
          json['preferredAudioLanguage'] as String? ??
          defaults.preferredAudioLanguage,
      subtitleOffsetMs:
          json['subtitleOffsetMs'] as int? ?? defaults.subtitleOffsetMs,
      playerFit: enumByName(
        PlayerFit.values,
        json['playerFit'] as String?,
        defaults.playerFit,
      ),
      sidebarCollapsed:
          json['sidebarCollapsed'] as bool? ?? defaults.sidebarCollapsed,
      libraryOrder:
          (json['libraryOrder'] as List<dynamic>?)?.cast<String>() ??
          defaults.libraryOrder,
      hiddenLibraries:
          (json['hiddenLibraries'] as List<dynamic>?)?.cast<String>() ??
          defaults.hiddenLibraries,
      pinnedNavLibraries:
          (json['pinnedNavLibraries'] as List<dynamic>?)?.cast<String>() ??
          defaults.pinnedNavLibraries,
      skipDurationSeconds:
          json['skipDurationSeconds'] as int? ?? defaults.skipDurationSeconds,
      autoPlayNextEpisode:
          json['autoPlayNextEpisode'] as bool? ?? defaults.autoPlayNextEpisode,
      resumeBehavior: enumByName(
        ResumeBehavior.values,
        json['resumeBehavior'] as String?,
        defaults.resumeBehavior,
      ),
      accentColor: json['accentColor'] as int?,
    );
  }
}

enum HdrMode { passthrough, toneMap, off }

enum DefaultSubtitleMode { auto, off }

enum PlayerFit { contain, cover, fill }

enum ResumeBehavior { ask, alwaysResume, alwaysRestart }
