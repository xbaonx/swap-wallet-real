import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/service_locator.dart';
import '../../data/settings/settings_service.dart';
import '../../core/storage.dart';

class SettingsScreen extends StatefulWidget {
  final ServiceLocator serviceLocator;

  const SettingsScreen({
    super.key,
    required this.serviceLocator,
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
              onTap: _showBackupSeed,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Export Private Key
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Export Private Key'),
              subtitle: const Text('Export wallet private key'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportPrivateKey,
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
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('App Version'),
              subtitle: const Text('1.0.0'),
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

  void _showBackupSeed() {
    // TODO: Show backup seed with authentication
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Seed Phrase'),
        content: const Text('This feature requires wallet authentication.\n\nIn a real app, this would show your 12-word recovery phrase after PIN/biometric verification.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _exportPrivateKey() {
    // TODO: Export private key with authentication
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Private Key'),
        content: const Text('⚠️ Warning: Never share your private key!\n\nThis feature requires PIN/biometric authentication.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // In real app, would show private key after auth
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _changePIN() {
    // TODO: Implement PIN change flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN management not implemented yet')),
    );
  }

  void _toggleBiometric(bool enabled) async {
    await SecureStorage.setBiometricEnabled(enabled);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(enabled ? 'Biometric enabled' : 'Biometric disabled')),
    );
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
              await _settingsService.setCustomRpcUrl(controller.text.trim());
              Navigator.pop(context);
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
                await _settingsService.setSlippage(value);
                Navigator.pop(context);
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
                await _settingsService.setDeadline(value);
                Navigator.pop(context);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token list refreshed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh tokens: $e')),
      );
    }
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to default? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _settingsService.clearAllSettings();
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to default')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
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
