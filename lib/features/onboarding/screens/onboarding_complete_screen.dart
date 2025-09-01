import 'package:flutter/material.dart';
import '../../../core/i18n.dart';

class OnboardingCompleteScreen extends StatefulWidget {
  final bool isImporting;
  final Future<void> Function() onComplete;

  const OnboardingCompleteScreen({
    super.key,
    required this.isImporting,
    required this.onComplete,
  });

  @override
  State<OnboardingCompleteScreen> createState() => _OnboardingCompleteScreenState();
}

class _OnboardingCompleteScreenState extends State<OnboardingCompleteScreen> {
  bool _isCompleting = false;

  Future<void> _handleComplete() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppI18n.tr(context, 'onboarding.complete.error.failed')}: $e')),
      );
      setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              
              // Success Animation/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green.withOpacity(0.3), width: 3),
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                widget.isImporting
                    ? AppI18n.tr(context, 'onboarding.complete.title.imported')
                    : AppI18n.tr(context, 'onboarding.complete.title.created'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                widget.isImporting 
                    ? AppI18n.tr(context, 'onboarding.complete.subtitle.imported')
                    : AppI18n.tr(context, 'onboarding.complete.subtitle.created'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Next Steps
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Text(
                      AppI18n.tr(context, 'onboarding.complete.whats_next'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildNextStep(
                      context,
                      Icons.account_balance_wallet,
                      AppI18n.tr(context, 'onboarding.complete.next.fund.title'),
                      AppI18n.tr(context, 'onboarding.complete.next.fund.desc'),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildNextStep(
                      context,
                      Icons.swap_horiz,
                      AppI18n.tr(context, 'onboarding.complete.next.trade.title'),
                      AppI18n.tr(context, 'onboarding.complete.next.trade.desc'),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildNextStep(
                      context,
                      Icons.trending_up,
                      AppI18n.tr(context, 'onboarding.complete.next.track.title'),
                      AppI18n.tr(context, 'onboarding.complete.next.track.desc'),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Security Reminder
              if (!widget.isImporting) ...[
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
                        Icons.backup,
                        color: Colors.amber[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppI18n.tr(context, 'onboarding.complete.reminder.title'),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppI18n.tr(context, 'onboarding.complete.reminder.desc'),
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
                const SizedBox(height: 24),
              ],
              
              // Get Started Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isCompleting ? null : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isCompleting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rocket_launch),
                            const SizedBox(width: 8),
                            Text(
                              AppI18n.tr(context, 'onboarding.complete.button.start'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextStep(BuildContext context, IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.blue,
            size: 22,
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
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
