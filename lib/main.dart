import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'pages/login_page.dart';
import 'services/secure_supabase_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isPartiallyConfigured ||
      SupabaseConfig.isMissingReleaseConfiguration) {
    runApp(const _SupabaseConfigErrorApp());
    return;
  }

  if (SupabaseConfig.isConfigured) {
    try {
      final projectRef = Uri.parse(SupabaseConfig.url).host.split('.').first;
      final secureStorage = SecureSupabaseStorage(
        legacySessionKey: 'sb-$projectRef-auth-token',
      );
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: secureStorage,
          pkceAsyncStorage: secureStorage,
        ),
      );
    } catch (_) {
      runApp(const _SupabaseConfigErrorApp());
      return;
    }
  }

  runApp(const CheckInGoApp());
}

class _SupabaseConfigErrorApp extends StatelessWidget {
  const _SupabaseConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'CheckInGo could not connect to its secure sign-in service. '
              'Please contact your school administrator.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class CheckInGoApp extends StatelessWidget {
  const CheckInGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF137C72);
    const pageColor = Color(0xFFF4F7FA);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'CheckInGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        textTheme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
        ).textTheme.copyWith(
              titleLarge: const TextStyle(
                fontSize: 18,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
              titleMedium: const TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
              titleSmall: const TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
              bodyLarge: const TextStyle(fontSize: 15, height: 1.4),
              bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
              bodySmall: const TextStyle(fontSize: 13, height: 1.4),
              labelLarge: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              labelMedium: const TextStyle(fontSize: 13, height: 1.25),
            ),
        scaffoldBackgroundColor: pageColor,
        appBarTheme: AppBarTheme(
          backgroundColor: pageColor,
          foregroundColor: const Color(0xFF17324D),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: const TextStyle(
            color: Color(0xFF17324D),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            );
          }),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
