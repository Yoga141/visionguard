import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../application/auth_controller.dart';

/// UC-03 Lupa kata sandi (bagian S-01). Server mengirim email berisi tautan
/// ke halaman web untuk membuat sandi baru (berlaku 60 menit).
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  bool _sending = false;
  String? _error;
  String? _sentMessage;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  static String? validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Format email tidak valid';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref.read(authControllerProvider.notifier).forgotPassword(_email.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.ok) {
        _sentMessage = result.message;
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lupa kata sandi'),
        leading: BackButton(onPressed: () => context.go(Routes.login)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _sentMessage != null ? _sent(theme) : _form(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(ThemeData theme) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_reset, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Masukkan email akun Anda. Kami akan mengirim tautan untuk membuat kata sandi baru.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: validateEmail,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Kirim tautan reset'),
            ),
          ],
        ),
      );

  Widget _sent(ThemeData theme) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.mark_email_read_outlined, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(_sentMessage!, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const Text(
            'Buka email, ketuk tautan, isi kata sandi baru dua kali, lalu kembali ke sini dan masuk. '
            'Periksa folder spam bila email belum terlihat.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => context.go(Routes.login), child: const Text('Kembali ke halaman masuk')),
        ],
      );
}
