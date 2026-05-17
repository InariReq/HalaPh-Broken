import 'package:flutter/material.dart';

class RouteAccuracyBadge extends StatelessWidget {
  final String confidenceLevel;
  final String sourceType;
  final bool large;

  const RouteAccuracyBadge({
    super.key,
    required this.confidenceLevel,
    required this.sourceType,
    this.large = false,
  });

  String get label => routeAccuracyLabel(
        confidenceLevel: confidenceLevel,
        sourceType: sourceType,
      );

  @override
  Widget build(BuildContext context) {
    final visual = _visualForLabel(label);
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: visual.backgroundColor,
      avatar: Icon(
        visual.icon,
        size: large ? 20 : 16,
        color: visual.foregroundColor,
      ),
      label: Text(
        large ? label : label,
        style: TextStyle(
          color: visual.foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: large ? 13 : 11,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: large ? 8 : 4,
        vertical: large ? 4 : 0,
      ),
    );
  }
}

String routeAccuracyLabel({
  required String confidenceLevel,
  required String sourceType,
}) {
  final confidence = confidenceLevel.trim().toLowerCase();
  final source = sourceType.trim().toLowerCase();

  if (confidence == 'high' && (source == 'official' || source == 'operator')) {
    return 'Verified';
  }
  if (confidence == 'medium') return 'Community Reported';
  if (source == 'estimated' || confidence == 'low') return 'Estimated';
  return 'Needs Review';
}

_RouteAccuracyVisual _visualForLabel(String label) {
  return switch (label) {
    'Verified' => _RouteAccuracyVisual(
        backgroundColor: Colors.green.shade100,
        foregroundColor: Colors.green.shade800,
        icon: Icons.verified_rounded,
      ),
    'Community Reported' => _RouteAccuracyVisual(
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade800,
        icon: Icons.groups_rounded,
      ),
    'Estimated' => _RouteAccuracyVisual(
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade900,
        icon: Icons.info_outline_rounded,
      ),
    _ => _RouteAccuracyVisual(
        backgroundColor: Colors.red.shade100,
        foregroundColor: Colors.red.shade800,
        icon: Icons.warning_amber_rounded,
      ),
  };
}

class _RouteAccuracyVisual {
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  const _RouteAccuracyVisual({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });
}
