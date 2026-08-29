import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/singapore_towns.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../dashboard/presentation/dashboard_repository.dart';

/// Standalone profile screen: shows the signed-in user's name, streak,
/// points, and residential area, and lets them update their area or sign
/// out. Reached from the dashboard's avatar button.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _repository = const DashboardRepository();
  late Future<DashboardSummary> _summaryFuture;

  String? _selectedTown;
  bool _isSavingTown = false;
  bool _isSigningOut = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _repository.fetchSummary();
  }

  Future<void> _saveTown(String town) async {
    setState(() {
      _isSavingTown = true;
      _saveError = null;
    });

    try {
      await _repository.updateResidentialArea(town);
      if (!mounted) return;
      setState(() => _selectedTown = town);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Residential area updated')),
      );
    } catch (_) {
      setState(() => _saveError = "Couldn't save your area. Try again.");
    } finally {
      if (mounted) setState(() => _isSavingTown = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await supabase.auth.signOut();
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: FutureBuilder<DashboardSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Couldn't load your profile."),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() {
                        _summaryFuture = _repository.fetchSummary();
                      }),
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isSigningOut ? null : _signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            );
          }

          final summary = snapshot.data!;
          _selectedTown ??= summary.residentialArea;
          final initials = summary.displayName.trim().isEmpty
              ? '?'
              : summary.displayName.trim().substring(0, 1).toUpperCase();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      summary.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileStat(
                        theme: theme,
                        label: 'Streak',
                        value: '${summary.streakDays} days',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileStat(
                        theme: theme,
                        label: 'Best streak',
                        value: '${summary.bestStreak} days',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileStat(
                        theme: theme,
                        label: 'Points',
                        value: '${summary.points}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Residential area',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTown,
                  decoration: InputDecoration(
                    errorText: _saveError,
                    suffixIcon: _isSavingTown
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  isExpanded: true,
                  items: kSingaporeTowns
                      .map((town) => DropdownMenuItem(
                            value: town,
                            child: Text(town),
                          ))
                      .toList(),
                  onChanged: _isSavingTown
                      ? null
                      : (value) {
                          if (value != null) _saveTown(value);
                        },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isSigningOut ? null : _signOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: _isSigningOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign out'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.theme,
    required this.label,
    required this.value,
  });

  final ThemeData theme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}