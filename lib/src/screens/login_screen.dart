part of '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final ValueChanged<JellyfinSession> onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverController = TextEditingController(text: 'http://');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff05080c), Color(0xff0b1820), Color(0xff080b10)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 820;
                    final form = _LoginPanel(
                      busy: _busy,
                      error: _error,
                      serverController: _serverController,
                      usernameController: _usernameController,
                      passwordController: _passwordController,
                      onSignIn: _signIn,
                    );
                    if (compact) {
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _BrandPanel(compact: true),
                            const SizedBox(height: 20),
                            form,
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(child: _BrandPanel()),
                          const SizedBox(width: 24),
                          SizedBox(width: 430, child: form),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final normalizedServer = normalizeServerUrl(_serverController.text);
      final client = JellyfinClient(baseUrl: normalizedServer);
      final session = await client.authenticate(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await SessionStore.save(session);
      widget.onSignedIn(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 0 : 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff102533), Color(0xff091017)],
        ),
        border: Border.all(color: Colors.white10),
      ),
      padding: EdgeInsets.all(compact ? 22 : 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/icon.png',
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'HQFin',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'High-quality Jellyfin playback.\nDirect streams, no compromises.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.busy,
    required this.error,
    required this.serverController,
    required this.usernameController,
    required this.passwordController,
    required this.onSignIn,
  });

  final bool busy;
  final String? error;
  final TextEditingController serverController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Connect',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use your Jellyfin server URL and account.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 24),
              AdaptiveTextField(
                controller: serverController,
                placeholder: 'Server URL',
                icon: Icons.dns_rounded,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 12),
              AdaptiveTextField(
                controller: usernameController,
                placeholder: 'Username',
                icon: Icons.person_rounded,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 12),
              AdaptiveTextField(
                controller: passwordController,
                placeholder: 'Password',
                icon: Icons.lock_rounded,
                obscureText: true,
                onSubmitted: (_) => onSignIn(),
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              AdaptiveButton(
                label: busy ? 'Connecting…' : 'Connect',
                icon: Icons.login_rounded,
                onPressed: busy ? null : onSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

