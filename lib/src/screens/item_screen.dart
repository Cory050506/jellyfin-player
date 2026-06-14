part of '../../main.dart';

class ItemScreen extends StatefulWidget {
  const ItemScreen({super.key, required this.client, required this.item});

  final JellyfinClient client;
  final JellyfinItem item;

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  Future<List<JellyfinItem>>? _childrenFuture;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == 'Series' ||
        widget.item.type == 'Season' ||
        widget.item.type == 'Folder') {
      _childrenFuture = widget.client.getItems(widget.item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlayable = widget.item.isPlayable;
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: DetailBackdrop(
                backdropUrl: widget.client.backdropUrl(
                  widget.item,
                  width: 1600,
                ),
                posterUrl: widget.client.imageUrl(widget.item, width: 700),
                item: widget.item,
                onPlay: isPlayable
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              client: widget.client,
                              item: widget.item,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ),
          if (_childrenFuture != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              sliver: FutureBuilder<List<JellyfinItem>>(
                future: _childrenFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final children = snapshot.data ?? [];
                  return SliverList.separated(
                    itemCount: children.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final child = children[index];
                      return ListTile(
                        tileColor: const Color(0xff182025),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: Icon(
                          child.isPlayable
                              ? Icons.play_circle_rounded
                              : Icons.folder_rounded,
                        ),
                        title: Text(child.name),
                        subtitle: Text(child.subtitle),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => child.isPlayable
                                  ? PlayerScreen(
                                      client: widget.client,
                                      item: child,
                                    )
                                  : ItemScreen(
                                      client: widget.client,
                                      item: child,
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
