import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  bool hidePassword = true;
  bool hideConfirmation = true;
  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  Future<void> savePassword() async {
    if (isSaving || !formKey.currentState!.validate()) return;
    setState(() {
      isSaving = true;
      errorMessage = null;
    });
    var navigatedAway = false;
    try {
      await AuthService().updatePassword(passwordController.text);
      await AuthService().signOut();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      setState(() => isSaving = false);
      navigatedAway = true;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (_) => false,
      );
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Password updated. Sign in with your new password.')),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        final message = error.message;
        final normalized = message.toLowerCase();
        if (normalized.contains('weak password')) {
          errorMessage = 'Choose a stronger password. $message';
        } else if (normalized.contains('expired') ||
            normalized.contains('invalid') ||
            normalized.contains('session')) {
          errorMessage =
              'This reset link may have expired or already been used. Request a new link. $message';
        } else {
          errorMessage = message.isEmpty
              ? 'Could not update your password. Request a fresh reset link and try again.'
              : message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage =
            'Could not reach Supabase. Check your connection and open the latest reset link again.';
      });
    } finally {
      if (mounted && !navigatedAway) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Choose a new password',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: colors.primary),
                        ),
                        const SizedBox(height: 8),
                        const Text('Use at least 8 characters.'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          obscureText: hidePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'New password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: hidePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => hidePassword = !hidePassword,
                              ),
                              icon: Icon(hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: (value) => (value?.length ?? 0) < 8
                              ? 'Password must be at least 8 characters.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmationController,
                          obscureText: hideConfirmation,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Confirm new password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: hideConfirmation
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => hideConfirmation = !hideConfirmation,
                              ),
                              icon: Icon(hideConfirmation
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: (value) => value != passwordController.text
                              ? 'The passwords do not match.'
                              : null,
                          onFieldSubmitted: (_) => savePassword(),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            style: TextStyle(color: colors.error),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: isSaving ? null : savePassword,
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Update password'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
