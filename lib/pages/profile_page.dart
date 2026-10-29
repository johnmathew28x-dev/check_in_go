import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  User? get _user {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  String _displayName(User? user) {
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    for (final key in ['full_name', 'name', 'display_name']) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Teacher';
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final name = _displayName(user);
    final email = user?.email;
    final colors = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF173B59), Color(0xFF137C72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Teacher account',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Account details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: Column(
                children: [
                  _ProfileDetail(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email ?? 'Local demo account',
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  const _ProfileDetail(
                    icon: Icons.school_outlined,
                    label: 'School',
                    value: 'Northeastern College',
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  const _ProfileDetail(
                    icon: Icons.location_on_outlined,
                    label: 'Campus',
                    value: 'Santiago City, Isabela',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 3),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
