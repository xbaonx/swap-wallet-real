import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/lifecycle.dart';
import 'core/service_locator.dart';
import 'storage/prefs_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize service locator with all dependencies
  final serviceLocator = ServiceLocator();
  await serviceLocator.initialize();

  // Initialize PrefsStore with SharedPreferences from service locator
  final prefsStore = PrefsStore(serviceLocator.prefs);
  await prefsStore.initialize();

  // Try to load wallet if it exists
  await serviceLocator.loadWalletIfExists();

  final lifecycleObserver = AppLifecycleObserver(
    serviceLocator.pollingService, // Use Binance polling service for lifecycle management
    prefsStore
  );

  runApp(CryptoSwapApp(
    prefsStore: prefsStore,
    serviceLocator: serviceLocator,
    lifecycleObserver: lifecycleObserver,
  ));
}
