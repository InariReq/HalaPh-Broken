import 'package:flutter/material.dart';

import '../widgets/admin_stat_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          'Operations overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Phase 1 establishes admin access, shell navigation, and Owner-only admin user management.',
        ),
        const SizedBox(height: 24),
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
              children: const [
                AdminStatCard(
                  icon: Icons.place_rounded,
                  title: 'Active Locations',
                  value: 'Phase 2',
                  subtitle: 'Location CRUD is planned for the next phase.',
                ),
                AdminStatCard(
                  icon: Icons.campaign_rounded,
                  title: 'Active Ads',
                  value: 'Phase 2',
                  subtitle: 'Banner and fullscreen ads are placeholders.',
                ),
                AdminStatCard(
                  icon: Icons.star_rounded,
                  title: 'Featured Places',
                  value: 'Phase 2',
                  subtitle: 'Priority placement controls are not active yet.',
                ),
                AdminStatCard(
                  icon: Icons.rate_review_rounded,
                  title: 'Pending Reviews',
                  value: '0',
                  subtitle: 'No review queue is enabled in Phase 1.',
                ),
                AdminStatCard(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Admin Users',
                  value: 'Managed',
                  subtitle: 'Owners can manage admin access now.',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _SecurityNotice(),
      ],
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.security_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Client-side role checks are for admin UI only. Firestore rules must enforce admin-only reads and writes before production use.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
