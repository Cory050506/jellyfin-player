part of '../../main.dart';

class ItemsView extends StatelessWidget {
  const ItemsView({
    super.key,
    required this.client,
    required this.library,
    required this.itemsFuture,
    this.onRefresh,
  });

  final JellyfinClient client;
  final JellyfinLibrary? library;
  final Future<List<JellyfinItem>>? itemsFuture;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final future = itemsFuture;
    if (library == null || future == null) {
      return const EmptyPane(
        icon: Icons.movie_filter_rounded,
        title: 'Pick a library',
        subtitle: 'Choose a media library to start browsing.',
      );
    }
    return FutureBuilder<List<JellyfinItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorPane(message: friendlyError(snapshot.error));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return EmptyPane(
            icon: Icons.folder_open_rounded,
            title: '${library!.name} is empty',
            subtitle: 'Nothing was returned from this library.',
          );
        }
        final featured = items.first;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 24, 10),
              sliver: SliverToBoxAdapter(
                child: LibraryHero(
                  library: library!,
                  item: featured,
                  backdropUrl: client.backdropUrl(featured, width: 1400),
                  posterUrl: client.imageUrl(featured, width: 360),
                  onPlay: featured.isPlayable
                      ? () async {
                          final playable = featured.mediaStreams.isEmpty
                              ? await client.getItemDetails(featured.id)
                              : featured;
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    client: client,
                                    item: playable,
                                  ),
                                ),
                              )
                              .then((_) => onRefresh?.call());
                        }
                      : null,
                  onOpen: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ItemScreen(client: client, item: featured),
                          ),
                        )
                        .then((_) => onRefresh?.call());
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'All media',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${items.length} items',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 214,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.6,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return MediaTile(
                    item: item,
                    imageUrl: client.imageUrl(item),
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ItemScreen(client: client, item: item),
                            ),
                          )
                          .then((_) => onRefresh?.call());
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
