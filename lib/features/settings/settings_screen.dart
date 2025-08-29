import 'package:flutter/material.dart';
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

  Widget _buildAppearanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
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
                  title: const Text('Theme'),
                  subtitle: Text(_themeLabel(mode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectThemeMode,
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
            const Text('⚠️ Tuyệt đối không chia sẻ thông tin này với bất kỳ ai.'),
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
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Gợi ý: Hãy ghi lại seed phrase ra giấy và cất giữ an toàn.'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _copyToClipboard(value);
              Navigator.pop(context);
            },
            child: const Text('Sao chép & Đóng'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _selectThemeMode() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Theme'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              widget.prefsStore.setThemeMode(ThemeMode.system);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('System'),
          ),
          SimpleDialogOption(
            onPressed: () {
              widget.prefsStore.setThemeMode(ThemeMode.light);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Light'),
          ),
          SimpleDialogOption(
            onPressed: () {
              widget.prefsStore.setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Dark'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
              'Wallet',
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
                  title: const Text('Current Address'),
                  subtitle: address != null 
                      ? Text('${address.substring(0, 6)}...${address.substring(address.length - 4)}')
                      : const Text('No wallet connected'),
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
              title: const Text('Backup Seed Phrase'),
              subtitle: const Text('View your recovery phrase'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showBackupSeed(),
              contentPadding: EdgeInsets.zero,
            ),
            
            // Export Private Key
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Export Private Key'),
              subtitle: const Text('Export wallet private key'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportPrivateKey(),
              contentPadding: EdgeInsets.zero,
            ),

            // Sign out & remove wallet
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất & Xóa ví', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Xóa ví, PIN và sinh trắc học khỏi thiết bị này'),
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
              'Security',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Set PIN
            ListTile(
              leading: const Icon(Icons.pin),
              title: const Text('Change PIN'),
              subtitle: const Text('Set or change your PIN code'),
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
                  title: const Text('Biometric Unlock'),
                  subtitle: const Text('Use fingerprint or Face ID'),
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
              'Network & RPC',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Network Selection
            ListTile(
              leading: const Icon(Icons.lan),
              title: const Text('Network'),
              subtitle: Text(_getNetworkDisplayName(_settingsService.selectedNetwork)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectNetwork,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Custom RPC
            ListTile(
              leading: const Icon(Icons.dns),
              title: const Text('Custom RPC URL'),
              subtitle: Text(_settingsService.customRpcUrl ?? 'Using default'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _setCustomRPC,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Current Active RPC
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Active RPC'),
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
              'Swap Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Slippage
            ListTile(
              leading: const Icon(Icons.trending_down),
              title: const Text('Slippage Tolerance'),
              subtitle: Text('${_settingsService.slippage}%'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _setSlippage,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Deadline
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Transaction Deadline'),
              subtitle: Text('${_settingsService.deadline} minutes'),
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
              'Other',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // App Version
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('App Version'),
              subtitle: Text('1.0.0'),
              contentPadding: EdgeInsets.zero,
            ),
            
            // Clear Token Cache
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh Token List'),
              subtitle: const Text('Re-download token list from 1inch'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _refreshTokenList,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Reset All Settings
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.orange),
              title: const Text('Reset Settings', style: TextStyle(color: Colors.orange)),
              subtitle: const Text('Reset all settings to default'),
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
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _showBackupSeed() async {
    dev.log('Request to show backup seed', name: 'settings');
    final authed = await _authenticateUser(reason: 'Xác thực để xem Seed Phrase');
    if (!authed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xác thực thất bại')),
        );
      }
      return;
    }

    try {
      final mnemonic = await SecureStorage.getMnemonic();
      if (mnemonic == null || mnemonic.isEmpty) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Backup Seed Phrase'),
            content: Text('Không tìm thấy seed phrase. Ví có thể đã được nhập bằng private key hoặc bạn chưa lưu seed phrase.'),
          ),
        );
        return;
      }

      await _showSensitiveDialog(
        title: 'Backup Seed Phrase',
        value: mnemonic,
        isSeed: true,
      );
    } catch (e) {
      dev.log('Failed to get mnemonic: $e', name: 'settings');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lấy seed phrase')),
        );
      }
    }
  }

  Future<void> _exportPrivateKey() async {
    dev.log('Request to export private key', name: 'settings');
    final wallet = widget.serviceLocator.walletService;
    if (!wallet.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet chưa khởi tạo')),
        );
      }
      return;
    }

    final authed = await _authenticateUser(reason: 'Xác thực để xuất Private Key');
    if (!authed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xác thực thất bại')),
        );
      }
      return;
    }

    try {
      if (wallet.isLocked) {
        await wallet.unlock();
      }
      final pk = await wallet.exportPrivateKey();
      await _showSensitiveDialog(
        title: 'Private Key',
        value: pk,
        isSeed: false,
      );
    } catch (e) {
      dev.log('Failed to export private key: $e', name: 'settings');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xuất Private Key')),
        );
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
          reason: 'Xác thực để thay đổi PIN',
        );
        if (!authed) return;
      }

      // Dùng PinSetupScreen để nhập & xác nhận PIN mới (UI thống nhất với onboarding)
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PinSetupScreen(
            title: 'Đặt PIN mới',
            showSkip: false,
            onBack: () => Navigator.pop(ctx),
            onSkip: () {},
            onPinSet: (pin) async {
              try {
                await SecureStorage.storePinHash(pin);
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cập nhật PIN thành công')),
                );
              } catch (e) {
                dev.log('Store new PIN error: $e', name: 'settings');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Không thể cập nhật PIN')),
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
        const SnackBar(content: Text('Không thể cập nhật PIN')),
      );
    }
  }

  void _toggleBiometric(bool enabled) async {
    try {
      if (enabled) {
        final available = await AuthGuard.isBiometricAvailable();
        if (!available) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thiết bị không hỗ trợ hoặc chưa đăng ký sinh trắc học')),
          );
          setState(() {});
          return;
        }

        // Yêu cầu đặt PIN trước khi bật sinh trắc học
        final hasPin = await SecureStorage.hasPinSet();
        if (!hasPin) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng đặt PIN trước khi bật sinh trắc học')),
          );
          await _changePIN();
          final recheck = await SecureStorage.hasPinSet();
          if (!recheck) {
            setState(() {});
            return;
          }
        }

        // Xác thực sinh trắc học để bật
        final didAuth = await AuthGuard.authenticateBiometricOnly(
          reason: 'Xác thực để bật mở khóa sinh trắc học',
        );
        if (!didAuth) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xác thực sinh trắc học thất bại')),
          );
          setState(() {});
          return;
        }

        await SecureStorage.setBiometricEnabled(true);
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã bật mở khóa sinh trắc học')),
        );
      } else {
        // Yêu cầu xác thực trước khi tắt
        final ok = await _authenticateUser(reason: 'Xác thực để tắt mở khóa sinh trắc học');
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xác thực thất bại')),
          );
          setState(() {});
          return;
        }
        await SecureStorage.setBiometricEnabled(false);
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tắt mở khóa sinh trắc học')),
        );
      }
    } catch (e) {
      dev.log('Toggle biometric error: $e', name: 'settings');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể thay đổi cài đặt sinh trắc học')),
      );
      setState(() {});
    }
  }

  void _selectNetwork() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Network'),
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
        title: const Text('Custom RPC URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'RPC URL',
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final value = controller.text.trim();
              Navigator.pop(context);
              await _settingsService.setCustomRpcUrl(value);
              if (!mounted) return;
              setState(() {});
            },
            child: const Text('Save'),
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
        title: const Text('Slippage Tolerance'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Slippage (%)',
            hintText: '0.1 - 1.0',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Save'),
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
        title: const Text('Transaction Deadline'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Deadline (minutes)',
            hintText: '5 - 60',
            suffixText: 'min',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _refreshTokenList() async {
    try {
      await widget.serviceLocator.tokenRegistry.clearCacheAndRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token list refreshed successfully')),
      );
    } catch (e) {
      dev.log('Failed to refresh tokens: $e', name: 'settings');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh tokens: $e')),
      );
    }
  }

  void _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to default? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _settingsService.clearAllSettings();
    if (!mounted) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Settings reset to default')),
    );
  }

  Future<void> _signOut() async {
    try {
      // Require auth only if security is configured
      final hasPin = await SecureStorage.hasPinSet();
      final bio = await SecureStorage.isBiometricEnabled();
      if (hasPin || bio) {
        final ok = await _authenticateUser(reason: 'Xác thực để đăng xuất và xóa ví');
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xác thực thất bại')),
          );
          return;
        }
      }

      // Confirm destructive action
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Đăng xuất & Xóa ví'),
          content: const Text('Hành động này sẽ xóa ví, PIN và thiết lập sinh trắc học khỏi thiết bị này. Bạn có thể khôi phục lại bằng seed phrase đã sao lưu. Tiếp tục?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đăng xuất')),
      );

      // Notify app to switch to onboarding
      widget.onSignOut();
    } catch (e) {
      dev.log('Sign out error: $e', name: 'settings');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng xuất thất bại')),
      );
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
