import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/security/security_repository.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _repo = SecurityRepository();
  final _otp = TextEditingController();
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  String _channel = 'EMAIL';
  String? _destination;
  String? _error;
  bool _loading = true;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _send('EMAIL');
  }

  @override
  void dispose() {
    _otp.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _send(String channel) async {
    setState(() { _loading = true; _error = null; });
    final result = await _repo.sendForgotLoginPinOtp(channel);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _channel = result['data']?['channel']?.toString() ?? channel;
        _destination = result['data']?['destination']?.toString();
        _otp.clear();
      } else {
        _error = result['message']?.toString() ?? 'Failed to send OTP.';
      }
    });
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length != 6) {
      setState(() => _error = 'Enter the complete 6-digit OTP.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final result = await _repo.verifyForgotLoginPinOtp(_otp.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _verified = result['success'] == true;
      if (!_verified) _error = result['message']?.toString() ?? 'Invalid OTP.';
    });
  }

  Future<void> _save() async {
    final pin = _pin.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin) || pin != _confirmPin.text.trim()) {
      setState(() => _error = pin.length != 4 ? 'PIN must be exactly 4 digits.' : 'PINs do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final result = await _repo.updateForgottenLoginPin(pin);
    if (!mounted) return;
    if (result['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('logged_in_user_id') ?? '';
      await prefs.setString('app_pin_$userId', pin);
      if (mounted) Navigator.pop(context, true);
      return;
    }
    setState(() { _loading = false; _error = result['message']?.toString() ?? 'Failed to reset PIN.'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot PIN')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(_verified ? Icons.pin_rounded : Icons.mark_email_read_outlined, size: 64, color: const Color(0xFF3D9E6A)),
          const SizedBox(height: 20),
          Text(
            _verified ? 'Set a new PIN' : 'Verify your account',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (!_verified) Text(
            'We sent a new OTP via ${_channel == 'EMAIL' ? 'email' : 'SMS'}${_destination == null ? '' : ' to $_destination'}.',
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          if (!_verified) ...[
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '6-digit OTP', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loading ? null : _verify, child: const Text('Verify OTP')),
            TextButton(
              onPressed: _loading ? null : () => _send(_channel),
              child: Text('Resend via ${_channel == 'EMAIL' ? 'email' : 'SMS'}'),
            ),
            TextButton(
              onPressed: _loading ? null : () => _send(_channel == 'EMAIL' ? 'PHONE' : 'EMAIL'),
              child: Text(_channel == 'EMAIL' ? 'Send OTP to phone instead' : 'Send OTP to email instead'),
            ),
          ] else ...[
            TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'New PIN', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _confirmPin, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Confirm new PIN', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loading ? null : _save, child: const Text('Reset PIN')),
          ],
          if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
