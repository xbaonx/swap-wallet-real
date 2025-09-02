import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;
import '../../core/service_locator.dart';
import '../../data/settings/settings_service.dart';
import '../../core/storage.dart';
import '../../core/auth_guard.dart';
import '../../storage/prefs_store.dart';
import '../onboarding/screens/pin_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ServiceLocator serviceLocator;
  final PrefsStore prefsStore;
  final VoidCallback onSignOut;

  const SettingsScreen({
    super.key,
    required this.serviceLocator,
    required this.prefsStore,
    required this.onSignOut,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsService _settingsService;
  
  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService(widget.serviceLocator.prefs);
  }

  void _selectLanguage() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppI18n.tr(context, 'settings.language')),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              final nav = Navigator.of(context);
              await widget.prefsStore.setLanguage('system');
              if (!mounted) return;
              nav.pop();
              setState(() {});
            },
            child: Text(AppI18n.tr(context, 'settings.language.system')),
          ),
          SimpleDialogOption(
            onPressed: () async {
              final nav = Navigator.of(context);
              await widget.prefsStore.setLanguage('en');
              if (!mounted) return;
              nav.pop();
              setState(() {});
            },
            child: Text(AppI18n.tr(context, 'settings.language.en')),
          ),
          SimpleDialogOption(
            onPressed: () async {
              final nav = Navigator.of(context);
              await widget.prefsStore.setLanguage('vi');
              if (!mounted) return;
              nav.pop();
              setState(() {});
            },
            child: Text(AppI18n.tr(context, 'settings.language.vi')),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppI18n.tr(context, 'settings.appearance'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: widget.prefsStore.themeMode,
              builder: (context, mode, _) {
                return ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: Text(AppI18n.tr(context, 'settings.theme')),
                  subtitle: Text(_themeLabel(mode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectThemeMode,
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: widget.prefsStore.language,
              builder: (context, lang, _) {
                String key;
                if (lang == 'system') {
                  key = 'settings.language.system';
                } else if (lang == 'vi') {
                  key = 'settings.language.vi';
                } else {
                  key = 'settings.language.en';
                }
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(AppI18n.tr(context, 'settings.language')),
                  subtitle: Text(AppI18n.tr(context, key)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectLanguage,
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _authenticateUser({required String reason}) async {
    return AuthGuard.requireAuth(context, reason: reason);
  }

  Future<void> _showSensitiveDialog({
    required String title,
    required String value,
    required bool isSeed,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppI18n.tr(context, 'sensitive.warning')),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                value,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            if (isSeed)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(AppI18n.tr(context, 'seed.hint')),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _copyToClipboard(value);
              Navigator.pop(context);
            },
            child: Text(AppI18n.tr(context, 'common.copy_close')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppI18n.tr(context, 'common.close')),
          ),
        ],
      ),
    );
  }

  

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppI18n.tr(context, 'settings.theme.light');
      case ThemeMode.dark:
        return AppI18n.tr(context, 'settings.theme.dark');
      case ThemeMode.system:
        return AppI18n.tr(context, 'settings.theme.system');
    }
  }

  void _selectThemeMode() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppI18n.tr(context, 'settings.theme.select')),
        children: [
          SimpleDialogOption(
            onPressed: () {
              widget.prefsStore.setThemeMode(ThemeMode.system);
              Navigator.pop(context);
              setState(() {});
            },
            child: Text(AppI18n.tr(context, 'settings.theme.system')),
          ),
          SimpleDialogOption(
            onPressed: () {
              widget.prefsStore.setThemeMode(ThemeMode.light);
              Navigator.pop(context);
              setState(() {});
            },
            child: Text(AppI18n.tr(context, 'settings.theme.light')),
          ),
          SimpleDialogOption(
            onPressed: () {
              widget.prefsStore.setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
              setState(() {});
            },
            child: Text(AppI18n.tr(context, 'settings.theme.dark')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.tr(context, 'settings.title')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWalletSection(),
          const SizedBox(height: 24),
          _buildSecuritySection(),
          const SizedBox(height: 24),
          _buildAppearanceSection(),
          const SizedBox(height: 24),
          _buildNetworkSection(),
          const SizedBox(height: 24),
          _buildSwapSection(),
          const SizedBox(height: 24),
          _buildOtherSection(),
        ],
      ),
    );
  }

  Widget _buildWalletSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppI18n.tr(context, 'settings.wallet'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Current Address
            FutureBuilder<String?>(
              future: _getCurrentAddress(),
              builder: (context, snapshot) {
                final address = snapshot.data;
                return ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: Text(AppI18n.tr(context, 'settings.current_address')),
                  subtitle: address != null 
                      ? Text('${address.substring(0, 6)}...${address.substring(address.length - 4)}')
                      : Text(AppI18n.tr(context, 'settings.no_wallet')),
                  trailing: address != null 
                      ? IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyToClipboard(address),
                        )
                      : null,
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
            
            // Backup Seed
            ListTile(
              leading: const Icon(Icons.backup),
              title: Text(AppI18n.tr(context, 'settings.backup_seed')),
              subtitle: Text(AppI18n.tr(context, 'settings.backup_seed.subtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showBackupSeed(),
              contentPadding: EdgeInsets.zero,
            ),
            
            // Export Private Key
            ListTile(
              leading: const Icon(Icons.key),
              title: Text(AppI18n.tr(context, 'settings.export_pk')),
              subtitle: Text(AppI18n.tr(context, 'settings.export_pk.subtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportPrivateKey(),
              contentPadding: EdgeInsets.zero,
            ),

            // Sign out & remove wallet
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(AppI18n.tr(context, 'settings.sign_out'), style: const TextStyle(color: Colors.red)),
              subtitle: Text(AppI18n.tr(context, 'settings.sign_out.subtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _signOut,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppI18n.tr(context, 'settings.security'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Set PIN
            ListTile(
              leading: const Icon(Icons.pin),
              title: Text(AppI18n.tr(context, 'settings.change_pin')),
              subtitle: Text(AppI18n.tr(context, 'settings.change_pin.subtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePIN,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Biometric Toggle
            FutureBuilder<bool>(
              future: SecureStorage.isBiometricEnabled(),
              builder: (context, snapshot) {
                final isEnabled = snapshot.data ?? false;
                return SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(AppI18n.tr(context, 'settings.biometric')),
                  subtitle: Text(AppI18n.tr(context, 'settings.biometric.subtitle')),
                  value: isEnabled,
                  onChanged: _toggleBiometric,
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppI18n.tr(context, 'settings.network_rpc'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Network Selection
            ListTile(
              leading: const Icon(Icons.lan),
              title: Text(AppI18n.tr(context, 'settings.network')),
              subtitle: Text(_getNetworkDisplayName(_settingsService.selectedNetwork)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectNetwork,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Custom RPC
            ListTile(
              leading: const Icon(Icons.dns),
              title: Text(AppI18n.tr(context, 'settings.custom_rpc')),
              subtitle: Text(_settingsService.customRpcUrl ?? AppI18n.tr(context, 'settings.custom_rpc.default')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _setCustomRPC,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Current Active RPC
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(AppI18n.tr(context, 'settings.active_rpc')),
              subtitle: Text(_settingsService.getCurrentRpcUrl()),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppI18n.tr(context, 'settings.swap_settings'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Slippage
            ListTile(
              leading: const Icon(Icons.trending_down),
              title: Text(AppI18n.tr(context, 'settings.slippage')),
              subtitle: Text('${_settingsService.slippage}%'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _setSlippage,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Deadline
            ListTile(
              leading: const Icon(Icons.timer),
              title: Text(AppI18n.tr(context, 'settings.deadline')),
              subtitle: Text('${_settingsService.deadline} ${AppI18n.tr(context, 'settings.minutes')}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _setDeadline,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppI18n.tr(context, 'settings.other'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // App Version
            ListTile(
              leading: const Icon(Icons.info),
              title: Text(AppI18n.tr(context, 'settings.app_version')),
              subtitle: const Text('1.0.0'),
              contentPadding: EdgeInsets.zero,
            ),
            
            // Clear Token Cache
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(AppI18n.tr(context, 'settings.refresh_tokens')),
              subtitle: Text(AppI18n.tr(context, 'settings.refresh_tokens.subtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _refreshTokenList,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Reset All Settings
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.orange),
              title: Text(AppI18n.tr(context, 'settings.reset_settings'), style: const TextStyle(color: Colors.orange)),
              subtitle: Text(AppI18n.tr(context, 'settings.reset_settings.subtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _resetSettings,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getCurrentAddress() async {
    try {
      if (widget.serviceLocator.walletService.isInitialized && 
          !widget.serviceLocator.walletService.isLocked) {
        return await widget.serviceLocator.walletService.getAddress();
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppI18n.tr(context, 'common.copied'))),
    );
  }

  Future<void> _showBackupSeed() async {
    dev.log('Request to show backup seed', name: 'settings');
    final messenger = ScaffoldMessenger.of(context);
    // Precompute i18n before async
    final i18nAuthFailed = AppI18n.tr(context, 'auth.failed');
    final i18nSeedNotFound = AppI18n.tr(context, 'seed.not_found');
    final i18nSeedBackupTitle = AppI18n.tr(context, 'seed.backup.title');
    final i18nSeedFetchFailed = AppI18n.tr(context, 'seed.fetch_failed');

    final authed = await _authenticateUser(reason: AppI18n.tr(context, 'auth.reason.view_seed'));
    if (!authed) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(i18nAuthFailed)));
      }
      return;
    }

    try {
      final mnemonic = await SecureStorage.getMnemonic();
      if (mnemonic == null || mnemonic.isEmpty) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(i18nSeedBackupTitle),
            content: Text(i18nSeedNotFound),
          ),
        );
        return;
      }

      await _showSensitiveDialog(
        title: i18nSeedBackupTitle,
        value: mnemonic,
        isSeed: true,
      );
    } catch (e) {
      dev.log('Failed to get mnemonic: $e', name: 'settings');
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(i18nSeedFetchFailed)));
      }
    }
  }

  Future<void> _exportPrivateKey() async {
    dev.log('Request to export private key', name: 'settings');
    final wallet = widget.serviceLocator.walletService;
    final messenger = ScaffoldMessenger.of(context);
    // Precompute i18n before async
    final i18nWalletNotInitialized = AppI18n.tr(context, 'wallet.not_initialized');
    final i18nAuthFailed = AppI18n.tr(context, 'auth.failed');
    final i18nPkExportFailed = AppI18n.tr(context, 'pk.export_failed');
    final i18nPkTitle = AppI18n.tr(context, 'private_key.title');
    if (!wallet.isInitialized) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(i18nWalletNotInitialized)));
      }
      return;
    }

    final authed = await _authenticateUser(reason: AppI18n.tr(context, 'auth.reason.export_pk'));
    if (!authed) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(i18nAuthFailed)));
      }
      return;
    }

    try {
      if (wallet.isLocked) {
        await wallet.unlock();
      }
      final pk = await wallet.exportPrivateKey();
      if (!mounted) return;
      await _showSensitiveDialog(
        title: i18nPkTitle,
        value: pk,
        isSeed: false,
      );
    } catch (e) {
      dev.log('Failed to export private key: $e', name: 'settings');
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(i18nPkExportFailed)));
      }
    }
  }

  Future<void> _changePIN() async {
    try {
      final hasPin = await SecureStorage.hasPinSet();
      if (hasPin) {
        // Require current auth (biometric or PIN) before allowing change
        if (!mounted) return;
        final authed = await AuthGuard.requireAuth(
          context,
          reason: AppI18n.tr(context, 'auth.reason.change_pin'),
        );
        if (!authed) return;
      }

      // Dùng PinSetupScreen để nhập & xác nhận PIN mới (UI thống nhất với onboarding)
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PinSetupScreen(
            title: AppI18n.tr(ctx, 'pin.new_title'),
            showSkip: false,
            onBack: () => Navigator.pop(ctx),
            onSkip: () {},
            onPinSet: (pin) async {
              try {
                await SecureStorage.storePinHash(pin);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(AppI18n.tr(ctx, 'pin.update_success'))),
                );
              } catch (e) {
                dev.log('Store new PIN error: $e', name: 'settings');
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(AppI18n.tr(ctx, 'pin.update_failed'))),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      dev.log('Change PIN error: $e', name: 'settings');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.tr(context, 'pin.update_failed'))),
      );
    }
  }

  void _toggleBiometric(bool enabled) async {
    // Precompute i18n before async and outside try/catch for scope safety
    final messenger = ScaffoldMessenger.of(context);
    final i18nBioNotAvail = AppI18n.tr(context, 'biometric.not_available');
    final i18nRequirePinFirst = AppI18n.tr(context, 'biometric.require_pin_first');
    final i18nBioFailed = AppI18n.tr(context, 'biometric.failed');
    final i18nBioEnabled = AppI18n.tr(context, 'biometric.enabled');
    final i18nBioDisabled = AppI18n.tr(context, 'biometric.disabled');
    final i18nAuthFailed = AppI18n.tr(context, 'auth.failed');
    final i18nBioChangeFailed = AppI18n.tr(context, 'biometric.change_failed');
    final i18nBioEnableReason = AppI18n.tr(context, 'biometric.enable.reason');
    final i18nBioDisableReason = AppI18n.tr(context, 'biometric.disable.reason');
    try {
      if (enabled) {
        final available = await AuthGuard.isBiometricAvailable();
        if (!available) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text(i18nBioNotAvail)));
          setState(() {});
          return;
        }

        // Yêu cầu đặt PIN trước khi bật sinh trắc học
        final hasPin = await SecureStorage.hasPinSet();
        if (!hasPin) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text(i18nRequirePinFirst)));
          await _changePIN();
          final recheck = await SecureStorage.hasPinSet();
          if (!recheck) {
            setState(() {});
            return;
          }
        }

        // Xác thực sinh trắc học để bật
        final didAuth = await AuthGuard.authenticateBiometricOnly(
          reason: i18nBioEnableReason,
        );
        if (!didAuth) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text(i18nBioFailed)));
          setState(() {});
          return;
        }

        await SecureStorage.setBiometricEnabled(true);
        if (!mounted) return;
        setState(() {});
        messenger.showSnackBar(SnackBar(content: Text(i18nBioEnabled)));
      } else {
        // Yêu cầu xác thực trước khi tắt
        final ok = await _authenticateUser(reason: i18nBioDisableReason);
        if (!ok) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text(i18nAuthFailed)));
          setState(() {});
          return;
        }
        await SecureStorage.setBiometricEnabled(false);
        if (!mounted) return;
        setState(() {});
        messenger.showSnackBar(SnackBar(content: Text(i18nBioDisabled)));
      }
    } catch (e) {
      dev.log('Toggle biometric error: $e', name: 'settings');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(i18nBioChangeFailed)));
      setState(() {});
    }
  }

  void _selectNetwork() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppI18n.tr(context, 'settings.select_network')),
        children: [
          SimpleDialogOption(
            onPressed: () {
              _settingsService.setNetwork('BSC_MAINNET');
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('BSC Mainnet'),
          ),
          SimpleDialogOption(
            onPressed: () {
              _settingsService.setNetwork('BSC_TESTNET');
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('BSC Testnet'),
          ),
        ],
      ),
    );
  }

  void _setCustomRPC() {
    final controller = TextEditingController(text: _settingsService.customRpcUrl ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppI18n.tr(context, 'settings.custom_rpc')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppI18n.tr(context, 'settings.custom_rpc'),
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppI18n.tr(context, 'common.cancel')),
          ),
          TextButton(
            onPressed: () async {
              final value = controller.text.trim();
              Navigator.pop(context);
              await _settingsService.setCustomRpcUrl(value);
              if (!mounted) return;
              setState(() {});
            },
            child: Text(AppI18n.tr(context, 'common.save')),
          ),
        ],
      ),
    );
  }

  void _setSlippage() {
    final controller = TextEditingController(text: _settingsService.slippage.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppI18n.tr(context, 'settings.slippage')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: AppI18n.tr(context, 'settings.slippage'),
            hintText: '0.1 - 1.0',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppI18n.tr(context, 'common.cancel')),
          ),
          TextButton(
            onPressed: () async {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0 && value <= 50) {
                Navigator.pop(context);
                await _settingsService.setSlippage(value);
                if (!mounted) return;
                setState(() {});
              }
            },
            child: Text(AppI18n.tr(context, 'common.save')),
          ),
        ],
      ),
    );
  }

  void _setDeadline() {
    final controller = TextEditingController(text: _settingsService.deadline.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppI18n.tr(context, 'settings.deadline')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppI18n.tr(context, 'settings.deadline'),
            hintText: '5 - 60',
            suffixText: AppI18n.tr(context, 'settings.minutes'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppI18n.tr(context, 'common.cancel')),
          ),
          TextButton(
            onPressed: () async {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0 && value <= 120) {
                Navigator.pop(context);
                await _settingsService.setDeadline(value);
                if (!mounted) return;
                setState(() {});
              }
            },
            child: Text(AppI18n.tr(context, 'common.save')),
          ),
        ],
      ),
    );
  }

  void _refreshTokenList() async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final i18nRefreshed = AppI18n.tr(context, 'settings.tokens_refreshed');
      await widget.serviceLocator.tokenRegistry.clearCacheAndRefresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(i18nRefreshed)));
    } catch (e) {
      dev.log('Failed to refresh tokens: $e', name: 'settings');
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final i18nFailed = AppI18n.tr(context, 'settings.tokens_refresh_failed');
      messenger.showSnackBar(SnackBar(content: Text('$i18nFailed: $e')));
    }
  }

  void _resetSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final i18nConfirmTitle = AppI18n.tr(context, 'settings.reset_settings.confirm_title');
    final i18nConfirmText = AppI18n.tr(context, 'settings.reset_settings.confirm_text');
    final i18nCancel = AppI18n.tr(context, 'common.cancel');
    final i18nReset = AppI18n.tr(context, 'common.reset');
    final i18nDone = AppI18n.tr(context, 'settings.reset_done');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18nConfirmTitle),
        content: Text(i18nConfirmText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(i18nCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(i18nReset, style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _settingsService.clearAllSettings();
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(SnackBar(content: Text(i18nDone)));
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    // Precompute i18n before async and make available to catch
    final i18nAuthFailed = AppI18n.tr(context, 'auth.failed');
    final i18nConfirmTitle = AppI18n.tr(context, 'settings.sign_out.confirm_title');
    final i18nConfirmText = AppI18n.tr(context, 'settings.sign_out.confirm_text');
    final i18nCancel = AppI18n.tr(context, 'settings.sign_out.cancel');
    final i18nOk = AppI18n.tr(context, 'settings.sign_out.ok');
    final i18nDone = AppI18n.tr(context, 'settings.sign_out.done');
    final i18nFailed = AppI18n.tr(context, 'settings.sign_out.failed');
    final i18nAuthReasonSignOut = AppI18n.tr(context, 'auth.reason.sign_out');
    try {
      // Require auth only if security is configured
      final hasPin = await SecureStorage.hasPinSet();
      final bio = await SecureStorage.isBiometricEnabled();
      if (hasPin || bio) {
        final ok = await _authenticateUser(reason: i18nAuthReasonSignOut);
        if (!ok) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text(i18nAuthFailed)));
          return;
        }
      }

      // Confirm destructive action
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(i18nConfirmTitle),
          content: Text(i18nConfirmText),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(i18nCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(i18nOk, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      // Securely delete wallet and clear in-memory state
      await SecureStorage.deleteWallet();
      widget.serviceLocator.walletService.dispose();

      // Optional: reset last selected tab
      await widget.prefsStore.setLastSelectedTab(0);

      if (!mounted) return;
      // Feedback before switching UI
      messenger.showSnackBar(SnackBar(content: Text(i18nDone)));

      // Notify app to switch to onboarding
      widget.onSignOut();
    } catch (e) {
      dev.log('Sign out error: $e', name: 'settings');
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text(i18nFailed)));
    }
  }

  String _getNetworkDisplayName(String network) {
    switch (network) {
      case 'BSC_MAINNET':
        return 'BSC Mainnet';
      case 'BSC_TESTNET':
        return 'BSC Testnet';
      default:
        return 'BSC Mainnet';
    }
  }
}
