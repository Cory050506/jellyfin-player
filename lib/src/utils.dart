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

T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

String hdrModeLabel(HdrMode mode) {
  return switch (mode) {
    HdrMode.passthrough => 'Passthrough',
    HdrMode.toneMap => 'Tone map',
    HdrMode.off => 'Off',
  };
}

String hdrModeDescription(HdrMode mode) {
  return switch (mode) {
    HdrMode.passthrough =>
      'Ask mpv to preserve HDR output when the display path allows it.',
    HdrMode.toneMap =>
      'Map HDR to SDR for displays or OS modes that do not handle HDR.',
    HdrMode.off => 'Use mpv defaults without extra HDR handling.',
  };
}

String subtitleModeLabel(DefaultSubtitleMode mode) {
  return switch (mode) {
    DefaultSubtitleMode.auto => 'Auto',
    DefaultSubtitleMode.off => 'Off',
  };
}

String playerFitLabel(PlayerFit fit) {
  return switch (fit) {
    PlayerFit.contain => 'Contain',
    PlayerFit.cover => 'Cover',
    PlayerFit.fill => 'Fill',
  };
}

String audioTrackLabel(AudioTrack track) {
  if (track.id == 'auto') {
    return 'Auto';
  }
  if (track.id == 'no') {
    return 'Off';
  }
  final details = [
    if (track.language != null && track.language!.isNotEmpty) track.language!,
    if (track.codec != null && track.codec!.isNotEmpty) track.codec!,
    if (track.channels != null && track.channels!.isNotEmpty) track.channels!,
  ];
  final title = track.title == null || track.title!.isEmpty
      ? 'Audio ${track.id}'
      : track.title!;
  return details.isEmpty ? title : '$title  ${details.join(' / ')}';
}

String subtitleTrackLabel(SubtitleTrack track) {
  if (track.id == 'auto') {
    return 'Auto';
  }
  if (track.id == 'no') {
    return 'Off';
  }
  final details = [
    if (track.language != null && track.language!.isNotEmpty) track.language!,
    if (track.codec != null && track.codec!.isNotEmpty) track.codec!,
  ];
  final title = track.title == null || track.title!.isEmpty
      ? 'Subtitle ${track.id}'
      : track.title!;
  return details.isEmpty ? title : '$title  ${details.join(' / ')}';
}

List<T> uniqueTracks<T>(List<T> tracks) {
  final seen = <String>{};
  final result = <T>[];
  for (final track in tracks) {
    final id = switch (track) {
      AudioTrack audio => 'audio:${audio.id}',
      SubtitleTrack subtitle => 'subtitle:${subtitle.id}',
      _ => track.toString(),
    };
    if (seen.add(id)) {
      result.add(track);
    }
  }
  return result;
}

String formatDuration(Duration duration) {
  if (duration <= Duration.zero) {
    return '0:00';
  }
  final hours = duration.inHours;
  final minutes = duration.inMinutes
      .remainder(60)
      .toString()
      .padLeft(hours > 0 ? 2 : 1, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

class JellyfinException implements Exception {
  const JellyfinException(this.message);

  final String message;

  @override
  String toString() => message;
}
