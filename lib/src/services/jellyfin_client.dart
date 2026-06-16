part of '../../main.dart';

class JellyfinClient {
  JellyfinClient({JellyfinSession? session, String? baseUrl})
    : session = session,
      baseUrl = baseUrl ?? session!.serverUrl;

  static const clientName = 'Jellyfin Player';
  static const clientVersion = '0.1.0';

  final JellyfinSession? session;
  final String baseUrl;

  static const listFields =
      'Overview,PrimaryImageAspectRatio,Genres,RunTimeTicks,ProductionYear,BackdropImageTags,ParentIndexNumber,IndexNumber,SeriesName,SeasonName,UserData';
  static const detailFields =
      'Overview,PrimaryImageAspectRatio,MediaSources,Genres,RunTimeTicks,ProductionYear,BackdropImageTags,People,UserData';

  Map<String, String> get _headers {
    final deviceId = session?.deviceId ?? 'setup-device';
    final tokenPart = session == null
        ? ''
        : ', Token="${session!.accessToken}"';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Emby-Authorization':
          'MediaBrowser Client="$clientName", Device="Flutter", DeviceId="$deviceId", Version="$clientVersion"$tokenPart',
    };
  }

  Future<JellyfinSession> authenticate({
    required String username,
    required String password,
  }) async {
    final deviceId = await SessionStore.deviceId();
    final response = await http.post(
      _uri('/Users/AuthenticateByName'),
      headers: {
        ..._headers,
        'X-Emby-Authorization':
            'MediaBrowser Client="$clientName", Device="Flutter", DeviceId="$deviceId", Version="$clientVersion"',
      },
      body: jsonEncode({'Username': username, 'Pw': password}),
    );
    final body = decodeResponse(response);
    return JellyfinSession(
      serverUrl: baseUrl,
      accessToken: body['AccessToken'] as String,
      userId: body['User']['Id'] as String,
      username: body['User']['Name'] as String? ?? username,
      deviceId: deviceId,
    );
  }

  Future<List<JellyfinLibrary>> getLibraries() async {
    final userId = session!.userId;
    final response = await http.get(
      _uri('/Users/$userId/Views'),
      headers: _headers,
    );
    final body = decodeResponse(response);
    return (body['Items'] as List<dynamic>? ?? [])
        .map((item) => JellyfinLibrary.fromJson(item as Map<String, dynamic>))
        .where((library) => library.collectionType != 'playlists')
        .toList();
  }

  Future<List<JellyfinItem>> getItems(JellyfinLibrary library) async {
    final userId = session!.userId;
    final movieLibrary = library.collectionType == 'movies';
    final response = await http.get(
      _uri('/Users/$userId/Items', {
        'ParentId': library.id,
        if (movieLibrary) ...{'Recursive': 'true', 'IncludeItemTypes': 'Movie'},
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Fields': listFields,
        'Limit': '200',
      }),
      headers: _headers,
    );
    final body = decodeResponse(response);
    return (body['Items'] as List<dynamic>? ?? [])
        .map((item) => JellyfinItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<JellyfinItem>> getChildren(String parentId) async {
    final userId = session!.userId;
    final response = await http.get(
      _uri('/Users/$userId/Items', {
        'ParentId': parentId,
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Fields': listFields,
        'Limit': '300',
      }),
      headers: _headers,
    );
    final body = decodeResponse(response);
    return (body['Items'] as List<dynamic>? ?? [])
        .map((item) => JellyfinItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<JellyfinItem> getItemDetails(String itemId) async {
    final userId = session!.userId;
    final response = await http.get(
      _uri('/Users/$userId/Items/$itemId', {'Fields': detailFields}),
      headers: _headers,
    );
    return JellyfinItem.fromJson(decodeResponse(response));
  }

  Future<List<JellyfinItem>> getSimilarItems(String itemId) async {
    final response = await http.get(
      _uri('/Items/$itemId/Similar', {
        'UserId': session!.userId,
        'Fields': listFields,
        'Limit': '12',
      }),
      headers: _headers,
    );
    final body = decodeResponse(response);
    return (body['Items'] as List<dynamic>? ?? [])
        .map((item) => JellyfinItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Uri imageUrl(JellyfinItem item, {int width = 420}) {
    final query = <String, String>{
      'fillWidth': '$width',
      'quality': '90',
      if (item.imageTag != null) 'tag': item.imageTag!,
      if (session != null) 'api_key': session!.accessToken,
    };
    return _uri('/Items/${item.id}/Images/Primary', query);
  }

  Uri backdropUrl(JellyfinItem item, {int width = 1200}) {
    final query = <String, String>{
      'fillWidth': '$width',
      'quality': '88',
      if (item.backdropTag != null) 'tag': item.backdropTag!,
      if (session != null) 'api_key': session!.accessToken,
    };
    return _uri('/Items/${item.id}/Images/Backdrop/0', query);
  }

  Uri personImageUrl(JellyfinPerson person, {int width = 260}) {
    final query = <String, String>{
      'fillWidth': '$width',
      'quality': '88',
      if (person.imageTag != null) 'tag': person.imageTag!,
      if (session != null) 'api_key': session!.accessToken,
    };
    return _uri('/Items/${person.id}/Images/Primary', query);
  }

  Uri streamUrl(
    JellyfinItem item,
    AppSettings settings, {
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    bool useHls = false,
  }) {
    if (useHls) {
      // HLS endpoint: Jellyfin remuxes the container (e.g. MKV→MPEG-TS) while
      // passing through video/audio streams untouched. AVPlayer requires this
      // for any container that isn't natively supported (MKV, etc).
      return _uri('/Videos/${item.id}/master.m3u8', {
        'api_key': session!.accessToken,
        'VideoCodec': 'h264,hevc,av1',
        'AudioCodec': 'aac,mp3,ac3,eac3,flac,opus',
        if (audioStreamIndex != null) 'AudioStreamIndex': '$audioStreamIndex',
        if (subtitleStreamIndex != null)
          'SubtitleStreamIndex': '$subtitleStreamIndex',
      });
    }
    return _uri('/Videos/${item.id}/stream', {
      if (settings.directStream) 'static': 'true',
      'api_key': session!.accessToken,
      if (audioStreamIndex != null) 'AudioStreamIndex': '$audioStreamIndex',
      if (subtitleStreamIndex != null)
        'SubtitleStreamIndex': '$subtitleStreamIndex',
    });
  }

  Future<void> reportPlaybackStart(JellyfinItem item) async {
    await _postPlayback('/Sessions/Playing', {
      'ItemId': item.id,
      'MediaSourceId': item.id,
      'CanSeek': true,
      'PlayMethod': 'DirectStream',
    });
  }

  Future<void> reportPlaybackProgress(
    JellyfinItem item, {
    required Duration position,
    required bool paused,
  }) async {
    await _postPlayback('/Sessions/Playing/Progress', {
      'ItemId': item.id,
      'MediaSourceId': item.id,
      'PositionTicks': durationToTicks(position),
      'IsPaused': paused,
      'IsMuted': false,
      'PlayMethod': 'DirectStream',
    });
  }

  Future<void> reportPlaybackStopped(
    JellyfinItem item, {
    required Duration position,
  }) async {
    await _postPlayback('/Sessions/Playing/Stopped', {
      'ItemId': item.id,
      'MediaSourceId': item.id,
      'PositionTicks': durationToTicks(position),
      'PlayMethod': 'DirectStream',
    });
  }

  Future<void> _postPlayback(String path, Map<String, Object?> body) async {
    final response = await http.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw JellyfinException(
        'Jellyfin playback report failed with HTTP ${response.statusCode}.',
      );
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final normalizedPath = [
      if (base.path.isNotEmpty) base.path.replaceAll(RegExp(r'/$'), ''),
      path,
    ].join();
    return base.replace(path: normalizedPath, queryParameters: query);
  }
}
