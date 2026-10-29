import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'dashboard_page.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;
  String errorMessage = '';
  StreamSubscription<AuthState>? authSubscription;
  bool isOpeningDashboard = false;
  bool isOpeningRecovery = false;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (state) {
          if (state.event == AuthChangeEvent.passwordRecovery) {
            openPasswordRecovery();
          } else if (!isOpeningRecovery &&
              state.session != null &&
              (state.event == AuthChangeEvent.initialSession ||
                  state.event == AuthChangeEvent.signedIn)) {
            openDashboard();
          }
        },
      );
    }
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void openDashboard() {
    if (!mounted || isOpeningDashboard) return;
    isOpeningDashboard = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DashboardPage()),
      (route) => false,
    );
  }

  void openPasswordRecovery() {
    if (!mounted || isOpeningRecovery) return;
    isOpeningRecovery = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ResetPasswordPage()),
      (route) => false,
    );
  }

  Future<void> requestPasswordReset() async {
    if (isLoading) return;
    var enteredEmail = usernameController.text.trim();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextFormField(
          initialValue: enteredEmail,
          keyboardType: TextInputType.emailAddress,
          autofocus: enteredEmail.isEmpty,
          decoration: const InputDecoration(
            labelText: 'Teacher email',
            hintText: 'teacher@example.com',
          ),
          onChanged: (value) => enteredEmail = value,
          onFieldSubmitted: (value) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, enteredEmail.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (!mounted || email == null || email.isEmpty) return;
    if (!email.contains('@') || email.endsWith('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      await AuthService().sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If that account exists, Supabase will send a password reset link.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = describePasswordResetError(error));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String describePasswordResetError(Object error) {
    if (error is AuthException) {
      final message = error.message;
      final normalized = message.toLowerCase();
      if (normalized.contains('redirect') ||
          normalized.contains('not allowed')) {
        return 'Supabase rejected the app return URL. Add '
            '${AuthService.mobileAuthRedirectUrl} under Authentication → '
            'URL Configuration → Redirect URLs, then save.';
      }
      if (normalized.contains('rate limit') ||
          normalized.contains('too many requests')) {
        return 'Too many reset requests. Wait a few minutes and try again.';
      }
      return message.isEmpty
          ? 'Supabase could not send the reset email.'
          : message;
    }
    return 'Could not reach Supabase. Check your internet connection and try again.';
  }

  Future<void> openRegistration() async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(builder: (context) => const RegisterPage()),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String describeSignInError(Object error) {
    if (error is AuthException) {
      final message = error.message;
      final normalized = message.toLowerCase();
      if (normalized.contains('email not confirmed') ||
          normalized.contains('email_not_confirmed')) {
        return 'Your email is not confirmed yet. Check your inbox and spam '
            'for the latest confirmation email, then try signing in again.';
      }
      if (normalized.contains('invalid login credentials')) {
        return 'Email or password is incorrect. Check your details and try again.';
      }
      return message.isEmpty ? 'Sign-in failed. Please try again.' : message;
    }
    if (error is StateError) return error.message.toString();
    return 'Could not reach the sign-in service. Check your internet '
        'connection and try again.';
  }

  Future<void> login() async {
    if (isLoading) return;
    setState(() {
      errorMessage = '';
    });

    // Check the form fields first
    if (!formKey.currentState!.validate()) {
      return;
    }

    String username = usernameController.text.trim();
    String password = passwordController.text;

    setState(() {
      isLoading = true;
    });

    try {
      await AuthService().signIn(
        emailOrUsername: username,
        password: password,
      );
      openDashboard();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = describeSignInError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).height < 500;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  // Logo
                  Container(
                    padding: EdgeInsets.all(compact ? 10 : 16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.how_to_reg,
                      size: compact ? 38 : 48,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 12),
                  Text(
                    'CheckInGo',
                    style: TextStyle(
                      fontSize: compact ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Teacher Attendance Tracking System',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Simple Attendance. Better Monitoring.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                  SizedBox(height: compact ? 8 : 20),

                  // Login form
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 10 : 16),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: usernameController,
                              keyboardType: SupabaseConfig.isConfigured
                                  ? TextInputType.emailAddress
                                  : TextInputType.text,
                              textCapitalization: TextCapitalization.none,
                              autofillHints: SupabaseConfig.isConfigured
                                  ? const [AutofillHints.email]
                                  : null,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: SupabaseConfig.isConfigured
                                    ? 'Teacher email'
                                    : 'Username',
                                hintText: SupabaseConfig.isConfigured
                                    ? 'teacher@example.com'
                                    : null,
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Username is required.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: passwordController,
                              obscureText: hidePassword,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    hidePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      hidePassword = !hidePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Password is required.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (value) {
                                login();
                              },
                            ),
                            const SizedBox(height: 10),
                            if (errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  errorMessage,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : login,
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'LOGIN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            if (SupabaseConfig.isConfigured)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed:
                                      isLoading ? null : requestPasswordReset,
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (SupabaseConfig.isConfigured) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isLoading ? null : openRegistration,
                      child: const Text('New teacher? Create an account'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (kDebugMode && SupabaseConfig.isDemoMode)
                    const Text(
                      'Sample account: teacher / 1234',
                      style: TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
