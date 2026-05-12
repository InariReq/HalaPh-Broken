import 'package:flutter/material.dart';
import 'package:halaph/services/budget_routing_service.dart';

IconData iconForTravelMode(TravelMode mode) {
  switch (mode) {
    case TravelMode.walking:
      return Icons.directions_walk_rounded;
    case TravelMode.jeepney:
      return Icons.directions_bus_filled_rounded;
    case TravelMode.bus:
      return Icons.directions_bus_rounded;
    case TravelMode.train:
      return Icons.train_rounded;
    case TravelMode.fx:
      return Icons.airport_shuttle_rounded;
  }
}

String labelForTravelMode(TravelMode mode) {
  switch (mode) {
    case TravelMode.walking:
      return 'Walk';
    case TravelMode.jeepney:
      return 'Jeepney';
    case TravelMode.bus:
      return 'Bus';
    case TravelMode.train:
      return 'Train';
    case TravelMode.fx:
      return 'FX/UV';
  }
}

Color colorForTravelMode(BuildContext context, TravelMode mode) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (mode) {
    case TravelMode.walking:
      return isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    case TravelMode.jeepney:
      return isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
    case TravelMode.bus:
      return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    case TravelMode.train:
      return isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);
    case TravelMode.fx:
      return isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);
  }
}

class TransportModeSequence extends StatelessWidget {
  final List<TravelMode> modes;
  final bool compact;

  const TransportModeSequence({
    super.key,
    required this.modes,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (modes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < modes.length; i++) ...[
          TransportModeChip(mode: modes[i], compact: compact),
          if (i != modes.length - 1)
            Icon(
              Icons.chevron_right_rounded,
              size: compact ? 15 : 17,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        ],
      ],
    );
  }
}

class TransportModeChip extends StatelessWidget {
  final TravelMode mode;
  final bool compact;

  const TransportModeChip({
    super.key,
    required this.mode,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorForTravelMode(context, mode);
    final label = labelForTravelMode(mode);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForTravelMode(mode), size: compact ? 14 : 16, color: color),
          if (!compact || mode != TravelMode.walking) ...[
            SizedBox(width: compact ? 4 : 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
