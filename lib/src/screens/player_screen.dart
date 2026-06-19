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
  // media_kit backend (non-iOS)
  Player? _player;
  VideoController? _controller;

  // better_native_video_player backend (iOS)
  NativeVideoPlayerController? _nativeController;

  AppSettings? _settings;
  String? _error;
  Timer? _progressTimer;
  bool _reportedStopped = false;
  bool _isFullscreen = false;
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  final FocusNode _focusNode = FocusNode();

  bool get _useNativePlayer =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(WakelockPlus.enable());
    unawaited(_initialize());
    if (isDesktopPlatform) {
      unawaited(_syncFullscreenState());
    }
    _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(
      const Duration(seconds: 4),
      () => mounted ? setState(() => _controlsVisible = false) : null,
    );
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideControlsTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Future<void> _nativeFullscreen() async {
    final nc = _nativeController;
    if (nc != null) {
      await nc.enterFullScreen();
    }
  }

  Future<void> _enterPictureInPicture() async {
    final nc = _nativeController;
    if (nc == null) return;
    try {
      debugPrint('Checking PiP availability...');
      final available = await nc.isPictureInPictureAvailable();
      debugPrint('PiP available: $available');
      if (available) {
        debugPrint('Entering PiP...');
        final success = await nc.enterPictureInPicture();
        debugPrint('PiP enter result: $success');
      } else {
        debugPrint('PiP not available');
      }
    } catch (e) {
      debugPrint('PiP error: $e');
    }
  }

  Future<void> _onVideoTap() async {
    if (_useNativePlayer) {
      final nc = _nativeController;
      if (nc == null) return;
      if (nc.activityState == PlayerActivityState.playing) {
        await nc.pause();
      } else {
        await nc.play();
      }
    } else {
      unawaited(_player?.playOrPause());
    }
    _showControls();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _toggleControls();
    } else if (_controlsVisible) {
      _scheduleHideControls();
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
      if (!mounted) return;
      setState(() => _settings = settings);

      if (_useNativePlayer) {
        final ctrl = NativeVideoPlayerController(
          id: 0,
          showNativeControls: true,
          allowsPictureInPicture: true,
          canStartPictureInPictureAutomatically: true,
        );
        setState(() => _nativeController = ctrl);
        // Give the widget one frame to attach the platform view before loading.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        await ctrl.initialize();
        if (!mounted) return;
        final streamUrl = await widget.client.resolveStreamUrl(
          widget.item,
          audioStreamIndex: widget.audioStreamIndex,
          subtitleStreamIndex: widget.subtitleStreamIndex,
        );
        if (!mounted) return;
        final resume = widget.item.resumePosition;
        await ctrl.loadUrl(
          url: streamUrl,
          startAt: resume > const Duration(seconds: 5) ? resume : null,
        );
        // Brief delay to ensure video is ready before playing
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await ctrl.play();
        // Auto-enter native fullscreen on iOS for Liquid Glass controls.
        await ctrl.enterFullScreen();
        unawaited(widget.client.reportPlaybackStart(widget.item));
        _progressTimer = Timer.periodic(
          const Duration(seconds: 10),
          (_) => unawaited(_reportProgress()),
        );
        return;
      }

      // Non-iOS: media_kit / mpv backend.
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

    AudioTrack targetAudio = AudioTrack.auto();
    final audioIndex = widget.audioStreamIndex;
    if (audioIndex != null) {
      // Explicit track chosen on the item screen — use it.
      final position = _streamPosition(widget.item.audioStreams, audioIndex);
      final match = _audioTrackAtPosition(tracks.audio, position);
      if (match != null) {
        targetAudio = match;
      }
    } else {
      // No explicit choice — try to match the preferred language setting.
      final preferred = settings.preferredAudioLanguage.trim().toLowerCase();
      if (preferred.isNotEmpty) {
        final match = _audioTrackByLanguage(tracks.audio, preferred);
        if (match != null) {
          targetAudio = match;
        }
      }
    }

    SubtitleTrack targetSubtitle = SubtitleTrack.auto();
    final subtitleIndex = widget.subtitleStreamIndex;
    if (subtitleIndex != null) {
      final position = _streamPosition(
        widget.item.subtitleStreams,
        subtitleIndex,
      );
      final match = _subtitleTrackAtPosition(tracks.subtitle, position);
      targetSubtitle = match ?? SubtitleTrack.no();
    } else if (settings.subtitleMode == DefaultSubtitleMode.off) {
      targetSubtitle = SubtitleTrack.no();
    }

    await player.setAudioTrack(targetAudio);
    await player.setSubtitleTrack(targetSubtitle);

    // mpv can reset to its own default track selection shortly after a file
    // finishes loading, racing with the explicit selection above. Re-apply
    // once playback has actually started so the user's choice sticks.
    unawaited(_reapplyTrackSettings(player, targetAudio, targetSubtitle));
  }

  Future<void> _reapplyTrackSettings(
    Player player,
    AudioTrack audio,
    SubtitleTrack subtitle,
  ) async {
    try {
      if (!player.state.playing) {
        await player.stream.playing
            .firstWhere((playing) => playing)
            .timeout(const Duration(seconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted || _player != player) {
        return;
      }
      await player.setAudioTrack(audio);
      await player.setSubtitleTrack(subtitle);
    } catch (_) {
      // Best effort; if this fails the initial selection still applies.
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
  AudioTrack? _audioTrackByLanguage(List<AudioTrack> mpvTracks, String lang) {
    final real = mpvTracks
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();
    for (final t in real) {
      final trackLang = (t.language ?? '').toLowerCase();
      final trackTitle = (t.title ?? '').toLowerCase();
      if (trackLang == lang ||
          trackLang.startsWith(lang) ||
          lang.startsWith(trackLang) ||
          trackTitle.contains(lang)) {
        return t;
      }
    }
    return null;
  }

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
    _hideControlsTimer?.cancel();
    _focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    unawaited(WakelockPlus.disable());
    unawaited(_reportStopped());
    _nativeController?.dispose();
    unawaited(_player?.dispose());
    if (_isFullscreen) {
      unawaited(windowManager.setFullScreen(false));
    }
    super.dispose();
  }

  Duration get _currentPosition =>
      _useNativePlayer
          ? (_nativeController?.currentPosition ?? Duration.zero)
          : (_player?.state.position ?? Duration.zero);

  bool get _currentlyPlaying =>
      _useNativePlayer
          ? (_nativeController?.activityState == PlayerActivityState.playing)
          : (_player?.state.playing ?? false);

  Future<void> _reportProgress() async {
    if (_useNativePlayer && _nativeController == null) return;
    if (!_useNativePlayer && _player == null) return;
    try {
      final pos = _currentPosition;
      final itemId = widget.item.id;
      final ticks = (pos.inMicroseconds ~/ 10).toString();
      debugPrint('reportProgress: $itemId at ${pos.inSeconds}s (${ticks} ticks), paused: ${!_currentlyPlaying}');
      await widget.client.reportPlaybackProgress(
        widget.item,
        position: pos,
        paused: !_currentlyPlaying,
      );
      debugPrint('reportProgress success');
    } catch (e) {
      debugPrint('reportProgress error: $e');
    }
  }

  Future<void> _reportStopped() async {
    if (_reportedStopped) return;
    _reportedStopped = true;
    if (_useNativePlayer && _nativeController == null) return;
    if (!_useNativePlayer && _player == null) return;
    try {
      final pos = _currentPosition;
      final itemId = widget.item.id;
      final ticks = (pos.inMicroseconds ~/ 10).toString();
      debugPrint('reportStopped: $itemId at ${pos.inSeconds}s ($ticks ticks)');
      await widget.client.reportPlaybackStopped(
        widget.item,
        position: pos,
      );
      debugPrint('reportStopped success');
    } catch (e) {
      debugPrint('reportStopped error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final controller = _controller;
    final settings = _settings;

    final Widget videoSurface;
    final bool playerReady;
    if (_error != null) {
      videoSurface = ErrorPane(message: _error!, dark: true);
      playerReady = false;
    } else if (_useNativePlayer) {
      final nc = _nativeController;
      videoSurface = nc != null
          ? NativeVideoPlayer(controller: nc)
          : const CircularProgressIndicator();
      playerReady = nc != null;
    } else if (controller == null || settings == null) {
      videoSurface = const CircularProgressIndicator();
      playerReady = false;
    } else {
      videoSurface = Video(
        controller: controller,
        fit: settings.boxFit,
        controls: NoVideoControls,
      );
      playerReady = player != null;
    }

    // iOS uses native controls; only non-iOS needs our custom bottom chrome.
    final PlayerBottomChrome? bottomChrome =
        (playerReady && !_useNativePlayer && player != null)
        ? PlayerBottomChrome(
            positionStream: player.stream.position,
            durationStream: player.stream.duration,
            playingStream: player.stream.playing,
            onSeek: (pos) => unawaited(player.seek(pos)),
            onPlayPause: () => unawaited(player.playOrPause()),
            item: widget.item,
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onHover: (_) => _showControls(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: videoSurface),
              // iOS uses the native AVPlayerViewController controls, so we skip
              // our own tap detector and chrome (they'd swallow the touches).
              // We keep only a lightweight back button to leave the player.
              if (_useNativePlayer) ...[
                // Always-visible button to close player and return to item screen.
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton.filledTonal(
                        tooltip: 'Close player',
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          await _reportStopped();
                          // Fully exit fullscreen before popping
                          if (_nativeController != null) {
                            try {
                              await _nativeController!.exitFullScreen();
                              // Wait longer for native dismissal to complete
                              await Future<void>.delayed(const Duration(milliseconds: 500));
                            } catch (e) {
                              debugPrint('exitFullScreen error: $e');
                            }
                          }
                          if (context.mounted) {
                            nav.pop();
                          }
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Tap anywhere to toggle play/pause; show controls briefly.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _onVideoTap,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: Listener(
                        onPointerDown: (_) => _showControls(),
                        child: PlayerTopChrome(
                          item: widget.item,
                          onBack: () async {
                            await _reportStopped();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          onAudio: _useNativePlayer
                              ? () => _showNativeAudioTracks()
                              : player != null
                              ? () => _showAudioTracks(player)
                              : null,
                          onSubtitles: _useNativePlayer
                              ? () => _showNativeSubtitleTracks()
                              : player != null
                              ? () => _showSubtitleTracks(player)
                              : null,
                          isFullscreen: _isFullscreen,
                          onFullscreen: _useNativePlayer
                              ? _nativeFullscreen
                              : isDesktopPlatform
                              ? _toggleFullscreen
                              : null,
                          onPiP: _useNativePlayer ? _enterPictureInPicture : null,
                        ),
                      ),
                    ),
                  ),
                ),
                if (bottomChrome != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: Listener(
                          onPointerDown: (_) => _showControls(),
                          child: bottomChrome,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
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

  Future<void> _showNativeAudioTracks() async {
    final nc = _nativeController;
    if (nc == null) return;
    final tracks = await nc.getAvailableAudioTracks();
    if (!mounted || tracks.isEmpty) return;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (context) => NativeAudioTrackSheet(
        tracks: tracks,
        onSelected: (track) async {
          await nc.setAudioTrack(track);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _showNativeSubtitleTracks() async {
    final nc = _nativeController;
    if (nc == null) return;
    final tracks = await nc.getAvailableSubtitleTracks();
    if (!mounted || tracks.isEmpty) return;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (context) => NativeSubtitleTrackSheet(
        tracks: tracks,
        onSelected: (track) async {
          await nc.setSubtitleTrack(track);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
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
    this.onPiP,
  });

  final JellyfinItem item;
  final Future<void> Function() onBack;
  final VoidCallback? onAudio;
  final VoidCallback? onSubtitles;
  final bool isFullscreen;
  final Future<void> Function()? onFullscreen;
  final Future<void> Function()? onPiP;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
          // Clear the floating macOS traffic-light buttons (windowed only).
          padding: EdgeInsets.fromLTRB(
            _isMacOS && !isFullscreen ? 78 : 12,
            8,
            12,
            42,
          ),
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
              if (onPiP != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Picture in Picture',
                  onPressed: () => unawaited(onPiP!()),
                  icon: const Icon(Icons.picture_in_picture_rounded),
                ),
              ],
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
    );
  }
}

class PlayerBottomChrome extends StatelessWidget {
  const PlayerBottomChrome({
    super.key,
    required this.positionStream,
    required this.durationStream,
    required this.playingStream,
    required this.onSeek,
    required this.onPlayPause,
    required this.item,
  });

  final Stream<Duration> positionStream;
  final Stream<Duration> durationStream;
  final Stream<bool> playingStream;
  final void Function(Duration) onSeek;
  final VoidCallback onPlayPause;
  final JellyfinItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
            stream: positionStream,
            builder: (context, positionSnapshot) {
              return StreamBuilder<Duration>(
                stream: durationStream,
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
                          IconButton.filledTonal(
                            tooltip: 'Back 10 seconds',
                            onPressed: () {
                              final target =
                                  position - const Duration(seconds: 10);
                              onSeek(
                                target < Duration.zero
                                    ? Duration.zero
                                    : target,
                              );
                            },
                            icon: const Icon(Icons.replay_10_rounded),
                          ),
                          const SizedBox(width: 8),
                          StreamBuilder<bool>(
                            stream: playingStream,
                            builder: (context, snapshot) {
                              final playing = snapshot.data ?? false;
                              return IconButton.filled(
                                tooltip: playing ? 'Pause' : 'Play',
                                onPressed: onPlayPause,
                                icon: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Forward 30 seconds',
                            onPressed: () {
                              final target =
                                  position + const Duration(seconds: 30);
                              onSeek(target > duration ? duration : target);
                            },
                            icon: const Icon(Icons.forward_30_rounded),
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
                        onChanged: (next) =>
                            onSeek(Duration(milliseconds: next.round())),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class NativeAudioTrackSheet extends StatelessWidget {
  const NativeAudioTrackSheet({
    super.key,
    required this.tracks,
    required this.onSelected,
  });

  final List<NativeVideoPlayerAudioTrack> tracks;
  final Future<void> Function(NativeVideoPlayerAudioTrack) onSelected;

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
              'Audio',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => unawaited(onSelected(track)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            if (track.isSelected)
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: AppColors.cyan,
                                ),
                              )
                            else
                              const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(track.displayName),
                                  if (track.language.isNotEmpty)
                                    Text(
                                      track.language,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class NativeSubtitleTrackSheet extends StatelessWidget {
  const NativeSubtitleTrackSheet({
    super.key,
    required this.tracks,
    required this.onSelected,
  });

  final List<NativeVideoPlayerSubtitleTrack> tracks;
  final Future<void> Function(NativeVideoPlayerSubtitleTrack) onSelected;

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
              'Subtitles',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => unawaited(onSelected(track)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            if (track.isSelected)
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: AppColors.cyan,
                                ),
                              )
                            else
                              const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(track.displayName),
                                  if (track.language.isNotEmpty)
                                    Text(
                                      track.language,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
