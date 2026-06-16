part of '../../main.dart';

class LibraryHero extends StatelessWidget {
  const LibraryHero({
    super.key,
    required this.library,
    required this.item,
    required this.backdropUrl,
    required this.posterUrl,
    required this.onOpen,
    this.onPlay,
  });

  final JellyfinLibrary library;
  final JellyfinItem item;
  final Uri backdropUrl;
  final Uri posterUrl;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            backdropUrl.toString(),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Image.network(
              posterUrl.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.panelRaised),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xee070b0f),
                  Color(0x99070b0f),
                  Color(0x22070b0f),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xcc070b0f), Color(0x00070b0f)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      posterUrl.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.panelRaised,
                        child: Icon(
                          Icons.movie_rounded,
                          color: Colors.white54,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        library.name,
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.subtitle,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (item.overview.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Text(
                            item.overview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (onPlay != null)
                            FilledButton.icon(
                              onPressed: onPlay,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play'),
                            ),
                          OutlinedButton.icon(
                            onPressed: onOpen,
                            icon: const Icon(Icons.info_outline_rounded),
                            label: const Text('Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MediaTile extends StatefulWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.imageUrl,
    required this.onTap,
  });

  final JellyfinItem item;
  final Uri imageUrl;
  final VoidCallback onTap;

  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      child: AnimatedScale(
        scale: active ? 1.035 : 1,
        duration: const Duration(milliseconds: 140),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? AppColors.cyan : Colors.white10,
              width: _focused ? 2 : 1,
            ),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: AppColors.panel,
              child: InkWell(
                onTap: widget.onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            widget.imageUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.panelRaised,
                                    Color(0xff0b1117),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.movie_rounded,
                                size: 44,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          const Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.center,
                                  colors: [
                                    Color(0x99000000),
                                    Color(0x00000000),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (widget.item.playbackPositionTicks > 0 &&
                              widget.item.runTimeTicks != null &&
                              widget.item.runTimeTicks! > 0)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: LinearProgressIndicator(
                                value: (widget.item.playbackPositionTicks /
                                        widget.item.runTimeTicks!)
                                    .clamp(0.0, 1.0),
                                minHeight: 3,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.cyan,
                                ),
                              ),
                            ),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.56),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.item.isPlayable
                                          ? Icons.play_arrow_rounded
                                          : iconForLibrary(widget.item.type),
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.item.durationLabel.isEmpty
                                          ? widget.item.type
                                          : widget.item.durationLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DetailBackdrop extends StatelessWidget {
  const DetailBackdrop({
    super.key,
    required this.backdropUrl,
    required this.posterUrl,
    required this.item,
    required this.onPlay,
  });

  final Uri backdropUrl;
  final Uri posterUrl;
  final JellyfinItem item;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            backdropUrl.toString(),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Image.network(
              posterUrl.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.panelRaised),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xee070b0f),
                  Color(0xaa070b0f),
                  Color(0x33070b0f),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xdd070b0f), Color(0x00070b0f)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      posterUrl.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.panelRaised,
                        child: Icon(
                          Icons.movie_rounded,
                          color: Colors.white54,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 26),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.type,
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.subtitle,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (item.overview.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Text(
                            item.overview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if (onPlay != null) ...[
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play'),
                          onPressed: onPlay,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
