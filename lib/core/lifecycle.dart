import 'package:flutter/material.dart';
import '../data/polling_service.dart';
import '../storage/prefs_store.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  final PollingService _pollingService;
  final PrefsStore _prefsStore;
  bool _isBackground = false;

  AppLifecycleObserver(this._pollingService, this._prefsStore) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('🔍 LIFECYCLE: App resumed from background=$_isBackground');
        if (_isBackground) {
          // Only resume if we were actually in background
          _pollingService.resume();
          _isBackground = false;
        }
        break;
      case AppLifecycleState.paused:
        print('🔍 LIFECYCLE: App paused, saving state and pausing services');
        _isBackground = true;
        // Save current state before going to background
        _prefsStore.saveCurrentState();
        // Pause polling to save resources and prevent crashes
        _pollingService.pause();
        break;
      case AppLifecycleState.inactive:
        // Don't pause on inactive (e.g., during orientation change)
        print('🔍 LIFECYCLE: App inactive (temporary)');
        break;
      case AppLifecycleState.detached:
        print('🔍 LIFECYCLE: App detached, performing cleanup');
        _isBackground = false;
        // Clean shutdown - this is when app is actually being killed
        _pollingService.stop();
        break;
      case AppLifecycleState.hidden:
        print('🔍 LIFECYCLE: App hidden');
        break;
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    print('🔍 LIFECYCLE: Memory pressure detected - reducing activity');
    
    // Temporarily pause polling to free up memory
    if (!_isBackground) {
      _pollingService.pause();
      
      // Resume after a short delay if still in foreground
      Future.delayed(const Duration(seconds: 10), () {
        if (!_isBackground) {
          _pollingService.resume();
        }
      });
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
