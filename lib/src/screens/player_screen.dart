part of '../../main.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.client,
    required this.item,
    this.audioStreamIndex,
    this.subtitleStreamIndex,
  });

  final JellyfinClient client;
  final JellyfinItem item;
  final int? audioStreamIndex;
  final int? subtitleStreamIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Player? _player;
  VideoController? _controller;
  AppSettings? _settings;
  String? _error;
  Timer? _progressTimer;
  bool _reportedStopped = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
    if (isDesktopPlatform) {
      unawaited(_syncFullscreenState());
    }
  }

  Future<void> _syncFullscreenState() async {
    final fullscreen = await windowManager.isFullScreen();
    if (mounted) {
      setState(() => _isFullscreen = fullscreen);
    }
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    await windowManager.setFullScreen(next);
    if (mounted) {
      setState(() => _isFullscreen = next);
    }
  }

  Future<void> _initialize() async {
    try {
      final settings = await AppSettingsStore.load();
      final player = Player(
        configuration: PlayerConfiguration(
          title: 'Jellyfin Player',
          bufferSize: settings.bufferSizeBytes,
          logLevel: MPVLogLevel.error,
        ),
      );
      final controller = VideoController(player);
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _settings = settings;
        _player = player;
        _controller = controller;
      });
      await _applyMpvSettings(settings);
      final url = widget.client.streamUrl(
        widget.item,
        settings,
        audioStreamIndex: widget.audioStreamIndex,
        subtitleStreamIndex: widget.subtitleStreamIndex,
      );
      final resumePosition = widget.item.resumePosition;
      await player.open(
        Media(
          url.toString(),
          start: resumePosition > const Duration(seconds: 5)
              ? resumePosition
              : null,
        ),
        play: true,
      );
      await _applyDefaultTrackSettings(settings);
      unawaited(widget.client.reportPlaybackStart(widget.item));
      _progressTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => unawaited(_reportProgress()),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    }
  }

  Future<void> _applyMpvSettings(AppSettings settings) async {
    final player = _player;
    if (player == null) {
      return;
    }
    final platform = player.platform as dynamic;
    final properties = <String, String>{
      'hwdec': settings.hardwareDecoding ? 'auto-safe' : 'no',
      'vd-lavc-dr': 'yes',
      'demuxer-seekable-cache': 'yes',
      'cache': 'yes',
      'sub-delay': (settings.subtitleOffsetMs / 1000).toStringAsFixed(3),
      if (settings.hdrMode == HdrMode.passthrough) ...{
        'target-colorspace-hint': 'yes',
        'tone-mapping': 'auto',
        'hdr-compute-peak': 'yes',
      } else if (settings.hdrMode == HdrMode.toneMap) ...{
        'target-colorspace-hint': 'no',
        'tone-mapping': 'bt.2446a',
        'hdr-compute-peak': 'yes',
      },
    };
    for (final entry in properties.entries) {
      try {
        await platform.setProperty(entry.key, entry.value);
      } catch (_) {
        // Some mpv properties are platform/backend-specific.
      }
    }
  }

  Future<void> _applyDefaultTrackSettings(AppSettings settings) async {
    final player = _player;
    if (player == null) {
      return;
    }
    final tracks = await _waitForTracks(player);

    final audioIndex = widget.audioStreamIndex;
    if (audioIndex != null) {
      final position = _streamPosition(widget.item.audioStreams, audioIndex);
      final match = _audioTrackAtPosition(tracks.audio, position);
      await player.setAudioTrack(match ?? AudioTrack.auto());
    } else {
      await player.setAudioTrack(AudioTrack.auto());
    }

    final subtitleIndex = widget.subtitleStreamIndex;
    if (subtitleIndex != null) {
      final position = _streamPosition(
        widget.item.subtitleStreams,
        subtitleIndex,
      );
      final match = _subtitleTrackAtPosition(tracks.subtitle, position);
      await player.setSubtitleTrack(match ?? SubtitleTrack.no());
    } else if (settings.subtitleMode == DefaultSubtitleMode.off) {
      await player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      await player.setSubtitleTrack(SubtitleTrack.auto());
    }
  }

  /// Waits briefly for mpv to report the tracks it discovered in the opened
  /// media, falling back to whatever is currently known if it takes too long.
  Future<Tracks> _waitForTracks(Player player) async {
    if (player.state.tracks.audio.length > 2 ||
        player.state.tracks.subtitle.length > 2) {
      return player.state.tracks;
    }
    try {
      return await player.stream.tracks
          .firstWhere(
            (tracks) => tracks.audio.length > 2 || tracks.subtitle.length > 2,
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return player.state.tracks;
    }
  }

  /// Finds the position of a selected Jellyfin stream index among streams of
  /// the same type, e.g. the 2nd audio stream overall.
  int _streamPosition(List<JellyfinMediaStream> streams, int selectedIndex) {
    return streams.indexWhere((stream) => stream.index == selectedIndex);
  }

  /// Returns the mpv-reported audio track at [position] among real tracks
  /// (i.e. excluding the synthetic "auto"/"no" entries), since mpv assigns
  /// track ids per-type rather than using the absolute Jellyfin stream index.
  AudioTrack? _audioTrackAtPosition(List<AudioTrack> mpvTracks, int position) {
    if (position < 0) {
      return null;
    }
    final realTracks = mpvTracks
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();
    return position < realTracks.length ? realTracks[position] : null;
  }

  /// Returns the mpv-reported subtitle track at [position] among real tracks
  /// (i.e. excluding the synthetic "auto"/"no" entries), since mpv assigns
  /// track ids per-type rather than using the absolute Jellyfin stream index.
  SubtitleTrack? _subtitleTrackAtPosition(
    List<SubtitleTrack> mpvTracks,
    int position,
  ) {
    if (position < 0) {
      return null;
    }
    final realTracks = mpvTracks
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();
    return position < realTracks.length ? realTracks[position] : null;
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    unawaited(_reportStopped());
    unawaited(_player?.dispose());
    if (_isFullscreen) {
      unawaited(windowManager.setFullScreen(false));
    }
    super.dispose();
  }

  Future<void> _reportProgress() async {
    final player = _player;
    if (player == null) {
      return;
    }
    try {
      await widget.client.reportPlaybackProgress(
        widget.item,
        position: player.state.position,
        paused: !player.state.playing,
      );
    } catch (_) {
      // Playback reporting should never interrupt local playback.
    }
  }

  Future<void> _reportStopped() async {
    if (_reportedStopped) {
      return;
    }
    _reportedStopped = true;
    final player = _player;
    if (player == null) {
      return;
    }
    try {
      await widget.client.reportPlaybackStopped(
        widget.item,
        position: player.state.position,
      );
    } catch (_) {
      // Best effort; the next periodic progress report may already be enough.
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final controller = _controller;
    final settings = _settings;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _error != null
                ? ErrorPane(message: _error!, dark: true)
                : controller == null || settings == null
                ? const CircularProgressIndicator()
                : Video(
                    controller: controller,
                    fit: settings.boxFit,
                    controls: NoVideoControls,
                  ),
          ),
          PlayerTopChrome(
            item: widget.item,
            onBack: () async {
              await _reportStopped();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            onAudio: player == null ? null : () => _showAudioTracks(player),
            onSubtitles: player == null
                ? null
                : () => _showSubtitleTracks(player),
            isFullscreen: _isFullscreen,
            onFullscreen: isDesktopPlatform ? _toggleFullscreen : null,
          ),
          if (player != null)
            PlayerBottomChrome(player: player, item: widget.item),
        ],
      ),
    );
  }

  Future<void> _showAudioTracks(Player player) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (context) => StreamBuilder<Track>(
        stream: player.stream.track,
        initialData: player.state.track,
        builder: (context, trackSnapshot) => StreamBuilder<Tracks>(
          stream: player.stream.tracks,
          initialData: player.state.tracks,
          builder: (context, tracksSnapshot) {
            final selected = trackSnapshot.data?.audio;
            final tracks = uniqueTracks<AudioTrack>([
              AudioTrack.auto(),
              ...tracksSnapshot.data?.audio ?? const <AudioTrack>[],
            ]);
            return TrackSheet<AudioTrack>(
              title: 'Audio',
              tracks: tracks,
              selected: selected,
              label: audioTrackLabel,
              onSelected: (track) async {
                await player.setAudioTrack(track);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showSubtitleTracks(Player player) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (context) => StreamBuilder<Track>(
        stream: player.stream.track,
        initialData: player.state.track,
        builder: (context, trackSnapshot) => StreamBuilder<Tracks>(
          stream: player.stream.tracks,
          initialData: player.state.tracks,
          builder: (context, tracksSnapshot) {
            final selected = trackSnapshot.data?.subtitle;
            final tracks = uniqueTracks<SubtitleTrack>([
              SubtitleTrack.no(),
              SubtitleTrack.auto(),
              ...tracksSnapshot.data?.subtitle ?? const <SubtitleTrack>[],
            ]);
            return TrackSheet<SubtitleTrack>(
              title: 'Subtitles',
              tracks: tracks,
              selected: selected,
              label: subtitleTrackLabel,
              onSelected: (track) async {
                await player.setSubtitleTrack(track);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class TrackSheet<T> extends StatelessWidget {
  const TrackSheet({
    super.key,
    required this.title,
    required this.tracks,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final String title;
  final List<T> tracks;
  final T? selected;
  final String Function(T track) label;
  final Future<void> Function(T track) onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final active = selected == track;
                  return ListTile(
                    leading: Icon(
                      active
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: active ? AppColors.cyan : Colors.white60,
                    ),
                    title: Text(label(track)),
                    onTap: () => unawaited(onSelected(track)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerTopChrome extends StatelessWidget {
  const PlayerTopChrome({
    super.key,
    required this.item,
    required this.onBack,
    required this.onAudio,
    required this.onSubtitles,
    required this.isFullscreen,
    required this.onFullscreen,
  });

  final JellyfinItem item;
  final Future<void> Function() onBack;
  final VoidCallback? onAudio;
  final VoidCallback? onSubtitles;
  final bool isFullscreen;
  final Future<void> Function()? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xdd000000), Color(0x00000000)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 42),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Back',
                  onPressed: () => unawaited(onBack()),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      if (item.subtitle.isNotEmpty)
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Audio tracks',
                  onPressed: onAudio,
                  icon: const Icon(Icons.spatial_audio_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Subtitles',
                  onPressed: onSubtitles,
                  icon: const Icon(Icons.subtitles_rounded),
                ),
                if (onFullscreen != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: isFullscreen ? 'Exit full screen' : 'Full screen',
                    onPressed: () => unawaited(onFullscreen!()),
                    icon: Icon(
                      isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerBottomChrome extends StatelessWidget {
  const PlayerBottomChrome({
    super.key,
    required this.player,
    required this.item,
  });

  final Player player;
  final JellyfinItem item;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xdd000000), Color(0x00000000)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 46, 20, 18),
            child: StreamBuilder<Duration>(
              stream: player.stream.position,
              initialData: player.state.position,
              builder: (context, positionSnapshot) {
                return StreamBuilder<Duration>(
                  stream: player.stream.duration,
                  initialData: player.state.duration,
                  builder: (context, durationSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final duration = durationSnapshot.data ?? Duration.zero;
                    final max = duration.inMilliseconds <= 0
                        ? 1.0
                        : duration.inMilliseconds.toDouble();
                    final value = position.inMilliseconds
                        .clamp(0, max.toInt())
                        .toDouble();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            StreamBuilder<bool>(
                              stream: player.stream.playing,
                              initialData: player.state.playing,
                              builder: (context, snapshot) {
                                final playing = snapshot.data ?? false;
                                return IconButton.filled(
                                  tooltip: playing ? 'Pause' : 'Play',
                                  onPressed: () =>
                                      unawaited(player.playOrPause()),
                                  icon: Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${formatDuration(position)} / ${formatDuration(duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (item.episodeCode.isNotEmpty)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  child: Text(
                                    item.episodeCode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Slider(
                          min: 0,
                          max: max,
                          value: value,
                          onChanged: (next) => unawaited(
                            player.seek(Duration(milliseconds: next.round())),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
