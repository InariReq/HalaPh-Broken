import 'package:flutter/material.dart';

class AdminFeaturedPlacesScreen extends StatelessWidget {
  const AdminFeaturedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = ['Featured', 'Recommended', 'Sponsored', 'Trending'];
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Featured Places',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prioritize destinations for Explore, Search, and recommendations.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final section in sections) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.label_important_rounded),
              title: Text(section),
              subtitle:
                  const Text('Featured placement controls arrive in Phase 2.'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
