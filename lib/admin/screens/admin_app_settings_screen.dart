import 'package:flutter/material.dart';

class AdminAppSettingsScreen extends StatelessWidget {
  const AdminAppSettingsScreen({super.key});

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
                Icon(
                  Icons.tune_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'App Settings',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configure public app content and admin-controlled flags.',
                ),
                const SizedBox(height: 18),
                const Chip(label: Text('Phase 2 placeholder')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
