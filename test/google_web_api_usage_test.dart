import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app source does not call driving or legacy Google web APIs', () {
    final forbidden = [
      'GoogleMapsApiService',
      '/maps/api/place/textsearch/json',
      '/maps/api/place/nearbysearch/json',
      '/maps/api/place/details/json',
      '/maps/api/place/photo',
      '/maps/api/directions/json',
      '/maps/api/geocode/json',
      'travelMode: \'driving\'',
      'TravelMode.driving',
    ];

    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in sourceFiles) {
      final contents = file.readAsStringSync();
      for (final token in forbidden) {
        expect(
          contents.contains(token),
          isFalse,
          reason: '${file.path} contains $token',
        );
      }
    }
  });
}
