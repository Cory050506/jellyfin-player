part of '../../main.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.client});
  final JellyfinClient client;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<JellyfinItem>? _results;
  String? _error;
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _results = null; _error = null; _loading = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await widget.client.search(query);
      if (!mounted) return;
      setState(() { _results = results; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search movies, shows, episodes…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 4),
            filled: false,
          ),
          onChanged: _onQueryChanged,
          onSubmitted: (q) { if (q.trim().isNotEmpty) _search(q.trim()); },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
                _focusNode.requestFocus();
              },
            ),
        ],
      ),
      body: _buildBody(results),
    );
  }

  Widget _buildBody(List<JellyfinItem>? results) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorPane(message: _error!);
    }
    if (results == null) {
      return const EmptyPane(
        icon: Icons.search_rounded,
        title: 'Search your library',
        subtitle: 'Type a movie, show, or episode name.',
      );
    }
    if (results.isEmpty) {
      return const EmptyPane(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: 'Try a different search term.',
      );
    }

    final crossAxisCount =
        (MediaQuery.of(context).size.width / 200).floor().clamp(2, 8);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${results.length} result${results.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.6,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              return MediaTile(
                item: item,
                imageUrl: widget.client.imageUrl(item),
                onTap: () {
                  Navigator.of(context).pushAdaptive<void>(
                    builder: (_) => ItemScreen(client: widget.client, item: item),
                    name: '/item/${item.id}',
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
