import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class AuthService {
  static const mobileAuthRedirectUrl =
      'io.supabase.checkingo://login-callback/';

  Future<void> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      if (SupabaseConfig.isDemoMode &&
          emailOrUsername == 'teacher' &&
          password == '1234') {
        return;
      }
      throw StateError('Sign-in service is unavailable.');
    }

    await Supabase.instance.client.auth.signInWithPassword(
      email: emailOrUsername,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (SupabaseConfig.isConfigured) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  Future<AuthResponse> registerTeacher({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Registration requires a configured Supabase project.');
    }

    return Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
      emailRedirectTo: kIsWeb ? null : mobileAuthRedirectUrl,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
          'Password recovery requires a configured Supabase project.');
    }
    await Supabase.instance.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? null : mobileAuthRedirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
          'Password recovery requires a configured Supabase project.');
    }
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: password),
    );
  }
}
