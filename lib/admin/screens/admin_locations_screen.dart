import 'package:flutter/material.dart';

class AdminLocationsScreen extends StatelessWidget {
  const AdminLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPage(
      icon: Icons.place_rounded,
      title: 'Locations Management',
      description: 'Add and manage places shown in HalaPH Explore and Search.',
      buttonLabel: 'Add Location',
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;

  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 42, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_clock_rounded),
                  label: Text('$buttonLabel - Phase 2'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
