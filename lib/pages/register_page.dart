import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool hidePassword = true;
  bool hideConfirmation = true;
  String errorMessage = '';

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (isLoading || !formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await AuthService().registerTeacher(
        fullName: fullNameController.text,
        email: emailController.text,
        password: passwordController.text,
      );
      if (!mounted) return;

      if (response.session == null) {
        Navigator.pop<String>(
          context,
          'Registration submitted. Check your email for a confirmation link, '
          'then return here to sign in.',
        );
      } else {
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          errorMessage =
              'Could not create your account. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !email.contains('@') || email.endsWith('@')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create teacher account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Join CheckInGo',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Use your teacher email to create an account.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: fullNameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if ((value?.trim().length ?? 0) < 2) {
                              return 'Enter your full name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Teacher email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: validateEmail,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: hidePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText: 'Use at least 8 characters.',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: hidePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () =>
                                  setState(() => hidePassword = !hidePassword),
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value?.length ?? 0) < 8) {
                              return 'Password must be at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: hideConfirmation,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: hideConfirmation
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => hideConfirmation = !hideConfirmation,
                              ),
                              icon: Icon(
                                hideConfirmation
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value != passwordController.text) {
                              return 'The passwords do not match.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => register(),
                        ),
                        if (errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: isLoading ? null : register,
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create account'),
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
