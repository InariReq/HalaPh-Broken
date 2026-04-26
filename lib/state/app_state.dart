import 'package:halaph/models/destination.dart';

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // Simple in-app itinerary state shared across screens
  final Map<int, List<Destination>> currentItinerary = {};

  void addToDay(Destination dest, int day) {
    currentItinerary.putIfAbsent(day, () => []);
    currentItinerary[day]!.add(dest);
  }

  List<Destination> destinationsForDay(int day) => currentItinerary[day] ?? [];
}
