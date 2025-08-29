import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import 'auth_guard.dart';

class LockScreen extends StatefulWidget {
  final String reason;
  const LockScreen({super.key, this.reason = 'Xác thực để tiếp tục'});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    // Tự động yêu cầu xác thực khi màn hình hiển thị
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptAuth());
  }

  Future<void> _attemptAuth() async {
    if (!mounted || _authInProgress) return;
    setState(() => _authInProgress = true);
    try {
      final ok = await AuthGuard.requireAuth(context, reason: widget.reason);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      dev.log('LockScreen auth error: $e', name: 'lock');
    } finally {
      if (mounted) setState(() => _authInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // chặn back
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 72),
                const SizedBox(height: 16),
                const Text(
                  'Ứng dụng đã khóa',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.reason,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _authInProgress ? null : _attemptAuth,
                  icon: const Icon(Icons.verified_user),
                  label: Text(_authInProgress ? 'Đang xác thực...' : 'Xác thực'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
