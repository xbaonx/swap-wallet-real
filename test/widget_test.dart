// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:swap_real/app.dart';
import 'package:swap_real/core/service_locator.dart';
import 'package:swap_real/storage/prefs_store.dart';
import 'package:swap_real/core/lifecycle.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Create test dependencies
    final serviceLocator = ServiceLocator();
    await serviceLocator.initializeForTesting();
    
    final prefsStore = PrefsStore(serviceLocator.prefs);
    await prefsStore.initialize();
    
    final lifecycleObserver = AppLifecycleObserver(
      serviceLocator.pricesAdapter,
      prefsStore
    );
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(CryptoSwapApp(
      prefsStore: prefsStore,
      serviceLocator: serviceLocator,
      lifecycleObserver: lifecycleObserver,
    ));

    // Verify the app loads without crashing
    await tester.pumpAndSettle();
    expect(find.byType(CryptoSwapApp), findsOneWidget);
  });
}
