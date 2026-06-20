part of '../../main.dart';

class ItemsView extends StatefulWidget {
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
  State<ItemsView> createState() => _ItemsViewState();
}

class _ItemsViewState extends State<ItemsView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final future = widget.itemsFuture;
    if (widget.library == null || future == null) {
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
            title: '${widget.library!.name} is empty',
            subtitle: 'Nothing was returned from this library.',
          );
        }
        final screenWidth = MediaQuery.of(context).size.width;
        final isTV = defaultTargetPlatform == TargetPlatform.android &&
            screenWidth >= 960;
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(24, _isMacOS ? 36 : 16, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        widget.library!.name,
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
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isTV ? 180 : 214,
                    mainAxisSpacing: isTV ? 24 : 18,
                    crossAxisSpacing: isTV ? 24 : 18,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return MediaTile(
                      item: item,
                      imageUrl: widget.client.imageUrl(item),
                      onTap: () {
                        Navigator.of(context)
                            .pushAdaptive<void>(
                              builder: (_) =>
                                  ItemScreen(client: widget.client, item: item),
                              name: '/item/${item.id}',
                            )
                            .then((_) => widget.onRefresh?.call());
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
