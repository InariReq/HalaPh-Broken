import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:halaph/models/destination.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

class MapAdapter {
  static bool get isDesktop {
    if (kIsWeb) return false; // treat web as non-desktop for map, we'll use a fallback
    final p = defaultTargetPlatform;
    return p == TargetPlatform.macOS || p == TargetPlatform.windows;
  }

  static Widget buildMap({List<Destination>? destinations, Destination? selectedDestination}) {
    if (isDesktop) {
      final list = destinations ?? [];
      return Container(
        height: 320,
        color: Colors.grey[200],
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final d = list[i];
            return ListTile(
              leading: d.imageUrl.isNotEmpty
                  ? Image.network(d.imageUrl, width: 40, height: 40, fit: BoxFit.cover)
                  : const Icon(Icons.place),
              title: Text(d.name),
              subtitle: Text(d.location),
            );
          },
        ),
      );
    } else {
      // Fallback: show a minimal placeholder map area; actual map on mobile/web handled by GoogleMap
      return Container(
        height: 320,
        color: Colors.grey[300],
        child: const Center(child: Text('Map view (mobile)')),
      );
    }
  }
}
