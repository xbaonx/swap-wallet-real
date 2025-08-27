import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final SharedPreferences _prefs;
  
  static const String _keySlippage = 'swap_slippage';
  static const String _keyDeadline = 'swap_deadline';
  static const String _keyRpcUrl = 'custom_rpc_url';
  static const String _keyNetwork = 'selected_network';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  
  // Default values
  static const double defaultSlippage = 0.5; // 0.5%
  static const int defaultDeadline = 20; // 20 minutes
  static const String defaultNetwork = 'BSC_MAINNET';

  SettingsService(this._prefs);

  // Swap Settings
  double get slippage => _prefs.getDouble(_keySlippage) ?? defaultSlippage;
  Future<void> setSlippage(double value) async {
    await _prefs.setDouble(_keySlippage, value);
  }

  int get deadline => _prefs.getInt(_keyDeadline) ?? defaultDeadline;
  Future<void> setDeadline(int minutes) async {
    await _prefs.setInt(_keyDeadline, minutes);
  }

  // Network Settings
  String get selectedNetwork => _prefs.getString(_keyNetwork) ?? defaultNetwork;
  Future<void> setNetwork(String network) async {
    await _prefs.setString(_keyNetwork, network);
  }

  String? get customRpcUrl => _prefs.getString(_keyRpcUrl);
  Future<void> setCustomRpcUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _prefs.remove(_keyRpcUrl);
    } else {
      await _prefs.setString(_keyRpcUrl, url);
    }
  }

  // Security Settings
  bool get isBiometricEnabled => _prefs.getBool(_keyBiometricEnabled) ?? false;
  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_keyBiometricEnabled, enabled);
  }

  // Clear all settings (for reset)
  Future<void> clearAllSettings() async {
    await _prefs.remove(_keySlippage);
    await _prefs.remove(_keyDeadline);
    await _prefs.remove(_keyRpcUrl);
    await _prefs.remove(_keyNetwork);
    await _prefs.remove(_keyBiometricEnabled);
  }

  // Get current RPC URL based on settings
  String getCurrentRpcUrl() {
    final customRpc = customRpcUrl;
    if (customRpc != null && customRpc.isNotEmpty) {
      return customRpc;
    }
    
    // Return default based on network
    switch (selectedNetwork) {
      case 'BSC_MAINNET':
        return 'https://bsc-dataseed1.binance.org/';
      case 'BSC_TESTNET':
        return 'https://data-seed-prebsc-1-s1.binance.org:8545/';
      default:
        return 'https://bsc-dataseed1.binance.org/';
    }
  }

  // Get fallback RPC URL
  String getFallbackRpcUrl() {
    switch (selectedNetwork) {
      case 'BSC_MAINNET':
        return 'https://bsc-dataseed2.binance.org/';
      case 'BSC_TESTNET':
        return 'https://data-seed-prebsc-2-s1.binance.org:8545/';
      default:
        return 'https://bsc-dataseed2.binance.org/';
    }
  }
}
