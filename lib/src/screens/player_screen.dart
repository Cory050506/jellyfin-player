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

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
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
      await player.open(Media(url.toString()), play: true);
      await _applyDefaultTrackSettings(settings);
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
    if (settings.subtitleMode == DefaultSubtitleMode.off) {
      await player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      await player.setSubtitleTrack(SubtitleTrack.auto());
    }
    await player.setAudioTrack(AudioTrack.auto());
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final controller = _controller;
    final settings = _settings;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.item.name),
        actions: [
          if (player != null)
            IconButton(
              tooltip: 'Audio tracks',
              onPressed: () => _showAudioTracks(player),
              icon: const Icon(Icons.spatial_audio_rounded),
            ),
          if (player != null)
            IconButton(
              tooltip: 'Subtitles',
              onPressed: () => _showSubtitleTracks(player),
              icon: const Icon(Icons.subtitles_rounded),
            ),
        ],
      ),
      body: Center(
        child: _error != null
            ? ErrorPane(message: _error!, dark: true)
            : controller == null || settings == null
            ? const CircularProgressIndicator()
            : Video(controller: controller, fit: settings.boxFit),
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
            final tracks = [
              AudioTrack.auto(),
              ...tracksSnapshot.data?.audio ?? const <AudioTrack>[],
            ];
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
            final tracks = [
              SubtitleTrack.no(),
              SubtitleTrack.auto(),
              ...tracksSnapshot.data?.subtitle ?? const <SubtitleTrack>[],
            ];
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
