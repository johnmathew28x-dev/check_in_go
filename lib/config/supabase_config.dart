import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
  static bool get isPartiallyConfigured =>
      url.isNotEmpty != publishableKey.isNotEmpty;

  /// Local demo accounts and data are only available in development builds.
  static bool get isDemoMode => kDebugMode && !isConfigured;

  /// A packaged app must use the authenticated Supabase backend.
  static bool get isMissingReleaseConfiguration => !kDebugMode && !isConfigured;
}
