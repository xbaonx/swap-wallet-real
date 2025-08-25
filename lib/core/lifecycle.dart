import 'package:flutter/material.dart';
import '../data/polling_service.dart';
import '../storage/prefs_store.dart';

class AppLifecycleObserver with WidgetsBindingObserver {
  final PollingService _pollingService;
  final PrefsStore _prefsStore;
  
  AppLifecycleObserver(this._pollingService, this._prefsStore) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _pollingService.resume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _pollingService.pause();
        _flushData();
        break;
      case AppLifecycleState.detached:
        _pollingService.stop();
        _flushData();
        break;
      case AppLifecycleState.hidden:
        _pollingService.pause();
        _flushData();
        break;
    }
  }

  void _flushData() {
    // Fire and forget - ensure data is persisted when app goes background/killed
    _prefsStore.flush().catchError((e) {
      print('Error flushing data: $e');
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingService.stop();
    _flushData();
  }
}
