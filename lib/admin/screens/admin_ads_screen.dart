import 'package:flutter/material.dart';

class AdminAdsScreen extends StatelessWidget {
  const AdminAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: const [
        _HeaderCard(
          icon: Icons.campaign_rounded,
          title: 'Advertisements Management',
          description: 'Manage banner and fullscreen ads shown inside HalaPH.',
        ),
        SizedBox(height: 16),
        _SectionCard(title: 'Banner Ads'),
        SizedBox(height: 16),
        _SectionCard(title: 'Fullscreen Ads'),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HeaderCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;

  const _SectionCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_clock_rounded),
        title: Text(title),
        subtitle: const Text('CRUD controls will be added in Phase 2.'),
      ),
    );
  }
}
