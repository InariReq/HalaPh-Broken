import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/destination_service.dart';

void main() {
  test(
    'deduplicateDestinationsById removes duplicates by id preserving first',
    () {
      final d1 = Destination(
        id: 'A',
        name: 'Place A',
        description: 'desc',
        location: 'Location A',
        imageUrl: 'https://example.com/a.jpg',
        category: DestinationCategory.landmark,
        budget: BudgetInfo(minCost: 0, maxCost: 0, currency: 'PHP'),
      );
      final d2 = Destination(
        id: 'B',
        name: 'Place B',
        description: 'desc',
        location: 'Location B',
        imageUrl: 'https://example.com/b.jpg',
        category: DestinationCategory.park,
        budget: BudgetInfo(minCost: 0, maxCost: 0, currency: 'PHP'),
      );
      final d2Dup = Destination(
        id: 'B',
        name: 'Place B Duplicate',
        description: 'desc',
        location: 'Location B',
        imageUrl: 'https://example.com/b2.jpg',
        category: DestinationCategory.park,
        budget: BudgetInfo(minCost: 0, maxCost: 0, currency: 'PHP'),
      );
      final input = [d1, d2, d2Dup];

      final deduped = DestinationService.deduplicateDestinationsById(input);
      expect(deduped.length, 2);
      expect(deduped.map((d) => d.id).toSet().length, 2);
      // Ensure first occurrence kept (A then B)
      expect(deduped[0].id, 'A');
      expect(deduped[1].id, 'B');
    },
  );

  test('fallbackDestinations returns usable category and query results', () {
    final foodResults = DestinationService.fallbackDestinations(
      category: DestinationCategory.food,
    );
    expect(foodResults, isNotEmpty);
    expect(
      foodResults.every(
        (destination) => destination.category == DestinationCategory.food,
      ),
      isTrue,
    );

    final queryResults = DestinationService.fallbackDestinations(
      query: 'intramuros',
    );
    expect(
      queryResults.map((destination) => destination.name),
      contains('Intramuros'),
    );
  });
}
