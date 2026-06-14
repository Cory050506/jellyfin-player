part of '../../main.dart';

class JellyfinClient {
  JellyfinClient({JellyfinSession? session, String? baseUrl})
    : session = session,
      baseUrl = baseUrl ?? session!.serverUrl;

  static const clientName = 'Jellyfin Player';
  static const clientVersion = '0.1.0';

  final JellyfinSession? session;
  final String baseUrl;

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

  Future<List<JellyfinItem>> getItems(String parentId) async {
    final userId = session!.userId;
    final response = await http.get(
      _uri('/Users/$userId/Items', {
        'ParentId': parentId,
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Fields':
            'Overview,PrimaryImageAspectRatio,MediaSources,Genres,RunTimeTicks,ProductionYear,BackdropImageTags',
        'Limit': '200',
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

  Uri streamUrl(JellyfinItem item) {
    return _uri('/Videos/${item.id}/stream', {
      'static': 'true',
      'api_key': session!.accessToken,
    });
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
