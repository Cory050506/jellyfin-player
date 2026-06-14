part of '../main.dart';

Map<String, dynamic> decodeResponse(http.Response response) {
  final body = response.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return body;
  }
  final message =
      body['Message'] as String? ??
      'Jellyfin returned HTTP ${response.statusCode}.';
  throw JellyfinException(message);
}

String normalizeServerUrl(String input) {
  final trimmed = input.trim().replaceAll(RegExp(r'/$'), '');
  final withScheme =
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
      ? trimmed
      : 'http://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) {
    throw const JellyfinException('Enter a valid Jellyfin server URL.');
  }
  return withScheme;
}

String friendlyError(Object? error) {
  if (error is JellyfinException) {
    return error.message;
  }
  if (error is TimeoutException) {
    return 'The server took too long to respond.';
  }
  return 'Something went wrong: $error';
}

IconData iconForLibrary(String type) {
  return switch (type) {
    'movies' => Icons.movie_rounded,
    'tvshows' => Icons.tv_rounded,
    'music' => Icons.music_note_rounded,
    'books' => Icons.menu_book_rounded,
    _ => Icons.video_library_rounded,
  };
}

class JellyfinException implements Exception {
  const JellyfinException(this.message);

  final String message;

  @override
  String toString() => message;
}
