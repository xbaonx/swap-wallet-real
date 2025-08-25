import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/lifecycle.dart';
import 'data/polling_service.dart';
import 'storage/prefs_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final prefsStore = PrefsStore(prefs);
  await prefsStore.initialize();

  final pollingService = PollingService();
  final lifecycleObserver = AppLifecycleObserver(pollingService, prefsStore);

  runApp(CryptoSwapApp(
    prefsStore: prefsStore,
    pollingService: pollingService,
    lifecycleObserver: lifecycleObserver,
  ));
}
