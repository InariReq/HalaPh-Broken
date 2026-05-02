import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/utils/map_utils.dart';

void main() {
  test('decodePolyline empty returns empty list', () {
    final pts = MapUtils.decodePolyline('');
    expect(pts, isA<List<LatLng>>());
    expect(pts.isEmpty, isTrue);
  });

  test('decodePolyline sample decodes to non-empty list', () {
    final poly = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    final pts = MapUtils.decodePolyline(poly);
    expect(pts, isA<List<LatLng>>());
    expect(pts.isNotEmpty, isTrue);
  });
}
