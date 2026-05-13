import 'package:flutter/material.dart';

import '../services/admin_dashboard_service.dart';
import '../widgets/admin_stat_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminDashboardService _dashboardService = AdminDashboardService();

  late Future<AdminDashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _dashboardService.loadStats();
  }

  void _refreshStats() {
    setState(() {
      _statsFuture = _dashboardService.loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboardStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.hasError;

        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operations overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loading
                          ? 'Loading admin metrics...'
                          : error
                              ? 'Some dashboard metrics could not be loaded.'
                              : 'Live Firestore metrics for HalaPH operations.',
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: loading ? null : _refreshStats,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (error) ...[
              _DashboardNotice(
                icon: Icons.error_outline_rounded,
                title: 'Dashboard metrics unavailable',
                message:
                    'The dashboard could not complete the stats request. Try refreshing, then check Firestore rules if the issue continues.',
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                return GridView.count(
                  crossAxisCount: wide ? 3 : 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: wide ? 1.7 : 3.2,
                  children: [
                    _statCard(
                      stats: stats,
                      keyName: 'users',
                      icon: Icons.people_alt_rounded,
                      title: 'App Users',
                    ),
                    _statCard(
                      stats: stats,
                      keyName: 'sharedPlans',
                      icon: Icons.route_rounded,
                      title: 'Shared Plans',
                    ),
                    _statCard(
                      stats: stats,
                      keyName: 'publicProfiles',
                      icon: Icons.badge_rounded,
                      title: 'Public Profiles',
                    ),
                    _statCard(
                      stats: stats,
                      keyName: 'friendCodes',
                      icon: Icons.qr_code_2_rounded,
                      title: 'Friend Codes',
                    ),
                    _statCard(
                      stats: stats,
                      keyName: 'featuredPlaces',
                      icon: Icons.star_rounded,
                      title: 'Featured Places',
                    ),
                    _statCard(
                      stats: stats,
                      keyName: 'adminUsers',
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Admin Users',
                    ),
                    _statCard(
                      stats: stats,
                      keyName: 'activeAdmins',
                      icon: Icons.verified_user_rounded,
                      title: 'Active Admins',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _DashboardNotice(
              icon: Icons.security_rounded,
              title: 'Security status',
              message:
                  'Dashboard reads are protected by Firestore rules. Restricted cards mean the admin UI is ready but the matching collection read rule has not been opened yet.',
              color: Theme.of(context).colorScheme.primary,
            ),
            if (stats != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last updated: ${_formatLoadedAt(stats.loadedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _statCard({
    required AdminDashboardStats? stats,
    required String keyName,
    required IconData icon,
    required String title,
  }) {
    final metric = stats?.metric(keyName);
    return AdminStatCard(
      icon: icon,
      title: title,
      value: metric?.value ?? 'Loading',
      subtitle: metric?.subtitle ?? 'Fetching latest count...',
    );
  }

  String _formatLoadedAt(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

class _DashboardNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _DashboardNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
