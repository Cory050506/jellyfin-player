part of '../../main.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<JellyfinSession?> _sessionFuture = SessionStore.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JellyfinSession?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        final session = snapshot.data;
        if (session == null) {
          return LoginScreen(onSignedIn: _openHome);
        }
        return HomeScreen(session: session, onSignedOut: _signOut);
      },
    );
  }

  void _openHome(JellyfinSession session) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(session: session, onSignedOut: _signOut),
      ),
    );
  }

  Future<void> _signOut() async {
    await SessionStore.clear();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(onSignedIn: _openHome)),
      (_) => false,
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
