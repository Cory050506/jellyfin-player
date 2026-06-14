part of '../../main.dart';

class ItemScreen extends StatefulWidget {
  const ItemScreen({super.key, required this.client, required this.item});

  final JellyfinClient client;
  final JellyfinItem item;

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  late final Future<JellyfinItem> _detailsFuture = _loadDetails();
  Future<List<JellyfinItem>>? _childrenFuture;
  late final Future<List<JellyfinItem>> _similarFuture = widget.client
      .getSimilarItems(widget.item.id);
  int? _selectedAudioStreamIndex;
  int? _selectedSubtitleStreamIndex;
  bool _tracksInitialized = false;

  Future<JellyfinItem> _loadDetails() async {
    final item = await widget.client.getItemDetails(widget.item.id);
    if (item.type == 'Series' ||
        item.type == 'Season' ||
        item.type == 'Folder') {
      _childrenFuture = widget.client.getChildren(item.id);
    }
    final settings = await AppSettingsStore.load();
    _initializeTrackSelections(item, settings);
    return item;
  }

  void _initializeTrackSelections(JellyfinItem item, AppSettings settings) {
    if (_tracksInitialized) {
      return;
    }
    _tracksInitialized = true;
    final defaultAudio = item.audioStreams.where((stream) => stream.isDefault);
    _selectedAudioStreamIndex =
        (defaultAudio.isNotEmpty
                ? defaultAudio.first
                : item.audioStreams.firstOrNull)
            ?.index;
    if (settings.subtitleMode == DefaultSubtitleMode.auto) {
      final forced = item.subtitleStreams.where((stream) => stream.isForced);
      final defaults = item.subtitleStreams.where((stream) => stream.isDefault);
      _selectedSubtitleStreamIndex =
          (forced.isNotEmpty
                  ? forced.first
                  : defaults.isNotEmpty
                  ? defaults.first
                  : null)
              ?.index;
    }
  }

  Future<void> _play(JellyfinItem item) async {
    final playableItem = item.mediaStreams.isEmpty
        ? await widget.client.getItemDetails(item.id)
        : item;
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          client: widget.client,
          item: playableItem,
          audioStreamIndex: item.id == widget.item.id
              ? _selectedAudioStreamIndex
              : null,
          subtitleStreamIndex: item.id == widget.item.id
              ? _selectedSubtitleStreamIndex
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JellyfinItem>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        final item = snapshot.data ?? widget.item;
        final isPlayable = item.isPlayable;
        return Scaffold(
          appBar: AppBar(title: Text(item.name)),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
                  child: DetailBackdrop(
                    backdropUrl: widget.client.backdropUrl(item, width: 1600),
                    posterUrl: widget.client.imageUrl(item, width: 700),
                    item: item,
                    onPlay: isPlayable ? () => unawaited(_play(item)) : null,
                  ),
                ),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (snapshot.hasError)
                SliverToBoxAdapter(
                  child: ErrorPane(message: friendlyError(snapshot.error)),
                )
              else ...[
                if (isPlayable)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                      child: PrePlayTrackPanel(
                        item: item,
                        selectedAudioStreamIndex: _selectedAudioStreamIndex,
                        selectedSubtitleStreamIndex:
                            _selectedSubtitleStreamIndex,
                        onAudioChanged: (value) => setState(
                          () => _selectedAudioStreamIndex = value?.index,
                        ),
                        onSubtitleChanged: (value) => setState(
                          () => _selectedSubtitleStreamIndex = value?.index,
                        ),
                      ),
                    ),
                  ),
                CastSection(client: widget.client, people: item.people),
                if (_childrenFuture != null)
                  ChildrenSection(
                    client: widget.client,
                    future: _childrenFuture!,
                    parent: item,
                    onPlayableTap: (item) => unawaited(_play(item)),
                  ),
                SimilarSection(client: widget.client, future: _similarFuture),
              ],
            ],
          ),
        );
      },
    );
  }
}

class PrePlayTrackPanel extends StatelessWidget {
  const PrePlayTrackPanel({
    super.key,
    required this.item,
    required this.selectedAudioStreamIndex,
    required this.selectedSubtitleStreamIndex,
    required this.onAudioChanged,
    required this.onSubtitleChanged,
  });

  final JellyfinItem item;
  final int? selectedAudioStreamIndex;
  final int? selectedSubtitleStreamIndex;
  final ValueChanged<JellyfinMediaStream?> onAudioChanged;
  final ValueChanged<JellyfinMediaStream?> onSubtitleChanged;

  @override
  Widget build(BuildContext context) {
    final audioStreams = item.audioStreams;
    final subtitleStreams = item.subtitleStreams;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            TrackDropdown(
              icon: Icons.spatial_audio_rounded,
              title: 'Audio',
              value: selectedAudioStreamIndex,
              streams: audioStreams,
              emptyLabel: 'Auto',
              onChanged: onAudioChanged,
            ),
            TrackDropdown(
              icon: Icons.subtitles_rounded,
              title: 'Subtitles',
              value: selectedSubtitleStreamIndex,
              streams: subtitleStreams,
              emptyLabel: 'Off',
              onChanged: onSubtitleChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class TrackDropdown extends StatelessWidget {
  const TrackDropdown({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.streams,
    required this.emptyLabel,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final int? value;
  final List<JellyfinMediaStream> streams;
  final String emptyLabel;
  final ValueChanged<JellyfinMediaStream?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430, minWidth: 280),
      child: Row(
        children: [
          Icon(icon, color: AppColors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue: streams.any((stream) => stream.index == value)
                  ? value
                  : null,
              decoration: InputDecoration(labelText: title),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(emptyLabel)),
                for (final stream in streams)
                  DropdownMenuItem<int?>(
                    value: stream.index,
                    child: Text(
                      stream.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (index) {
                if (index == null) {
                  onChanged(null);
                } else {
                  onChanged(
                    streams.firstWhere((stream) => stream.index == index),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CastSection extends StatelessWidget {
  const CastSection({super.key, required this.client, required this.people});

  final JellyfinClient client;
  final List<JellyfinPerson> people;

  @override
  Widget build(BuildContext context) {
    final cast = people
        .where((person) => person.type == 'Actor')
        .take(16)
        .toList();
    if (cast.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: DetailHorizontalSection(
        title: 'Cast',
        height: 224,
        itemCount: cast.length,
        itemBuilder: (context, index) {
          final person = cast[index];
          return PersonCard(client: client, person: person);
        },
      ),
    );
  }
}

class PersonCard extends StatelessWidget {
  const PersonCard({super.key, required this.client, required this.person});

  final JellyfinClient client;
  final JellyfinPerson person;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                client.personImageUrl(person).toString(),
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.panelRaised,
                  child: Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: 44,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            person.role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class SimilarSection extends StatelessWidget {
  const SimilarSection({super.key, required this.client, required this.future});

  final JellyfinClient client;
  final Future<List<JellyfinItem>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JellyfinItem>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: DetailHorizontalSection(
            title: 'More like this',
            height: 312,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 180,
                child: MediaTile(
                  item: item,
                  imageUrl: client.imageUrl(item),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemScreen(client: client, item: item),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class ChildrenSection extends StatelessWidget {
  const ChildrenSection({
    super.key,
    required this.client,
    required this.future,
    required this.parent,
    required this.onPlayableTap,
  });

  final JellyfinClient client;
  final Future<List<JellyfinItem>> future;
  final JellyfinItem parent;
  final ValueChanged<JellyfinItem> onPlayableTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JellyfinItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final children = snapshot.data ?? [];
        if (children.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final title = parent.type == 'Series'
            ? 'Seasons'
            : parent.type == 'Season'
            ? 'Episodes'
            : 'Items';
        if (parent.type == 'Series') {
          return SliverToBoxAdapter(
            child: DetailHorizontalSection(
              title: title,
              height: 330,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return SizedBox(
                  width: 190,
                  child: SeasonCard(client: client, item: child),
                );
              },
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          sliver: SliverList.separated(
            itemCount: children.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 12)
                : const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                );
              }
              final child = children[index - 1];
              return EpisodeTile(
                client: client,
                item: child,
                onTap: () => child.isPlayable
                    ? onPlayableTap(child)
                    : Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ItemScreen(client: client, item: child),
                        ),
                      ),
              );
            },
          ),
        );
      },
    );
  }
}

class DetailHorizontalSection extends StatelessWidget {
  const DetailHorizontalSection({
    super.key,
    required this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String title;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: itemBuilder,
            ),
          ),
        ],
      ),
    );
  }
}

class SeasonCard extends StatelessWidget {
  const SeasonCard({super.key, required this.client, required this.item});

  final JellyfinClient client;
  final JellyfinItem item;

  @override
  Widget build(BuildContext context) {
    return MediaTile(
      item: item,
      imageUrl: client.imageUrl(item, width: 360),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemScreen(client: client, item: item),
          ),
        );
      },
    );
  }
}

class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.client,
    required this.item,
    required this.onTap,
  });

  final JellyfinClient client;
  final JellyfinItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  client.imageUrl(item, width: 320).toString(),
                  width: 156,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AppColors.panelRaised,
                    child: SizedBox(
                      width: 156,
                      height: 88,
                      child: Icon(
                        Icons.play_circle_rounded,
                        color: Colors.white54,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    if (item.overview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                item.isPlayable
                    ? Icons.play_arrow_rounded
                    : Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
