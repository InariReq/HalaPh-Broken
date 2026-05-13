import 'package:flutter/material.dart';

class AdminNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const AdminNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: selected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: Icon(
            locked ? Icons.lock_outline_rounded : icon,
            color:
                selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
