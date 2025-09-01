import 'package:flutter/material.dart';
import '../../../core/i18n.dart';

class WalletTypeScreen extends StatelessWidget {
  final Function(bool isImporting) onWalletTypeSelected;
  final VoidCallback onBack;

  const WalletTypeScreen({
    super.key,
    required this.onWalletTypeSelected,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text(AppI18n.tr(context, 'onboarding.wallet_type.appbar')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 32),
              
              Text(
                AppI18n.tr(context, 'onboarding.wallet_type.title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                AppI18n.tr(context, 'onboarding.wallet_type.subtitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Create New Wallet
              _buildWalletOption(
                context,
                icon: Icons.add_circle_outline,
                title: AppI18n.tr(context, 'onboarding.wallet_type.create.title'),
                description: AppI18n.tr(context, 'onboarding.wallet_type.create.desc'),
                onTap: () => onWalletTypeSelected(false),
                color: Colors.blue,
              ),
              
              const SizedBox(height: 20),
              
              // Import Existing Wallet
              _buildWalletOption(
                context,
                icon: Icons.download,
                title: AppI18n.tr(context, 'onboarding.wallet_type.import.title'),
                description: AppI18n.tr(context, 'onboarding.wallet_type.import.desc'),
                onTap: () => onWalletTypeSelected(true),
                color: Colors.green,
              ),
              
              const Spacer(),
              
              // Security Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.amber[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppI18n.tr(context, 'onboarding.wallet_type.security.title'),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppI18n.tr(context, 'onboarding.wallet_type.security.desc'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
