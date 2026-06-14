import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_player/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the connection screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const JellyfinPlayerApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Jellyfin Player'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  test('normalizes server URLs', () {
    expect(
      normalizeServerUrl('jellyfin.local:8096/'),
      'http://jellyfin.local:8096',
    );
    expect(
      normalizeServerUrl('https://media.example.com'),
      'https://media.example.com',
    );
  });
}
