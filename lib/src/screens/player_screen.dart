part of '../../main.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.client, required this.item});

  final JellyfinClient client;
  final JellyfinItem item;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    unawaited(_openMedia());
  }

  Future<void> _openMedia() async {
    try {
      final url = widget.client.streamUrl(widget.item);
      await _player.open(Media(url.toString()), play: true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.item.name),
      ),
      body: Center(
        child: _error == null
            ? Video(controller: _controller)
            : ErrorPane(message: _error!, dark: true),
      ),
    );
  }
}
