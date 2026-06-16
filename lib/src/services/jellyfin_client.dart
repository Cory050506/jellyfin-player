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
      final uri = _uri('/Videos/${item.id}/master.m3u8', {
        'api_key': session!.accessToken,
        'MediaSourceId': item.id,
        'VideoCodec': 'h264,hevc,av1',
        'AudioCodec': 'aac,mp3,ac3,eac3,flac,opus',
        'AllowVideoStreamCopy': 'true',
        'AllowAudioStreamCopy': 'true',
        'VideoBitrate': '80000000',
        'AudioBitrate': '384000',
        if (audioStreamIndex != null) 'AudioStreamIndex': '$audioStreamIndex',
        if (subtitleStreamIndex != null)
          'SubtitleStreamIndex': '$subtitleStreamIndex',
      });
      // ignore: avoid_print
      print('[streamUrl HLS] $uri');
      return uri;
    }
    final uri = _uri('/Videos/${item.id}/stream', {
      if (settings.directStream) 'static': 'true',
      'MediaSourceId': item.id,
      'api_key': session!.accessToken,
      if (audioStreamIndex != null) 'AudioStreamIndex': '$audioStreamIndex',
      if (subtitleStreamIndex != null)
        'SubtitleStreamIndex': '$subtitleStreamIndex',
    });
    // ignore: avoid_print
    print('[streamUrl] $uri');
    return uri;
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

  // Device profile for iOS/AVPlayer: direct play MP4/MOV, remux everything
  // else to HLS-TS. Jellyfin picks the right method and hands back the URL.
  static const _iosDeviceProfile = {
    'DirectPlayProfiles': [
      {
        'Type': 'Video',
        'Container': 'mp4,mov,m4v',
        'VideoCodec': 'h264,hevc,av1',
        'AudioCodec': 'aac,mp3,ac3,eac3,alac',
      },
    ],
    'TranscodingProfiles': [
      {
        'Type': 'Video',
        'Container': 'ts',
        'Protocol': 'hls',
        'VideoCodec': 'hevc,h264',
        'AudioCodec': 'aac,mp3,ac3,eac3',
        'Context': 'Streaming',
        'CopyTimestamps': true,
        'EnableSubtitlesInManifest': false,
        'MaxAudioChannels': '8',
        'MinSegments': 1,
        'SegmentLength': 6,
        'VideoBitrate': 120000000,
        'AudioBitrate': 640000,
      },
    ],
    'ContainerProfiles': <Map<String, dynamic>>[],
    'CodecProfiles': <Map<String, dynamic>>[],
    'SubtitleProfiles': [
      {'Format': 'vtt', 'Method': 'External'},
      {'Format': 'ass', 'Method': 'External'},
    ],
  };

  Future<String> resolveStreamUrl(
    JellyfinItem item, {
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    final userId = session!.userId;
    final response = await http.post(
      _uri('/Items/${item.id}/PlaybackInfo', {
        'UserId': userId,
        'MediaSourceId': item.id,
      }),
      headers: _headers,
      body: jsonEncode({
        'DeviceProfile': _iosDeviceProfile,
        'UserId': userId,
        'MediaSourceId': item.id,
        'AllowVideoStreamCopy': true,
        'AllowAudioStreamCopy': true,
        if (audioStreamIndex != null) 'AudioStreamIndex': audioStreamIndex,
        if (subtitleStreamIndex != null)
          'SubtitleStreamIndex': subtitleStreamIndex,
      }),
    );
    final body = decodeResponse(response);
    final sources = body['MediaSources'] as List<dynamic>? ?? [];
    if (sources.isEmpty) throw Exception('No media sources returned');
    final source = sources.first as Map<String, dynamic>;

    // Prefer direct stream URL; fall back to transcoding URL.
    final directUrl = source['DirectStreamUrl'] as String?;
    final transcodingUrl = source['TranscodingUrl'] as String?;
    final url = directUrl ?? transcodingUrl;
    if (url == null) throw Exception('No stream URL in PlaybackInfo response');

    final resolved = url.startsWith('http') ? url : '$baseUrl$url';
    // ignore: avoid_print
    print('[resolveStreamUrl] $resolved');
    return resolved;
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
