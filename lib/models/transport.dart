enum TransportType {
  jeepney,
  bus,
  train,
  tricycle,
  pedicab,
  walking,
  taxi,
  rideShare,
}

class TransportOption {
  final String id;
  final TransportType type;
  final String route;
  final String description;
  final double cost;
  final Duration duration;
  final bool hasTolls;
  final List<String> instructions;

  TransportOption({
    required this.id,
    required this.type,
    required this.route,
    required this.description,
    required this.cost,
    required this.duration,
    this.hasTolls = false,
    this.instructions = const [],
  });

  factory TransportOption.fromJson(Map<String, dynamic> json) {
    return TransportOption(
      id: json['id'],
      type: TransportType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransportType.jeepney,
      ),
      route: json['route'],
      description: json['description'],
      cost: json['cost']?.toDouble() ?? 0.0,
      duration: Duration(minutes: json['durationMinutes'] ?? 0),
      hasTolls: json['hasTolls'] ?? false,
      instructions: List<String>.from(json['instructions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'route': route,
      'description': description,
      'cost': cost,
      'durationMinutes': duration.inMinutes,
      'hasTolls': hasTolls,
      'instructions': instructions,
    };
  }

  String get formattedCost => '₱${cost.toStringAsFixed(2)}';
  String get formattedDuration => '${duration.inMinutes} min';
}

class RoutePlan {
  final String id;
  final String from;
  final String to;
  final List<TransportOption> options;
  final TransportOption? recommended;

  RoutePlan({
    required this.id,
    required this.from,
    required this.to,
    required this.options,
    this.recommended,
  });

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    return RoutePlan(
      id: json['id'],
      from: json['from'],
      to: json['to'],
      options: (json['options'] as List?)
          ?.map((e) => TransportOption.fromJson(e))
          .toList() ?? [],
      recommended: json['recommended'] != null 
          ? TransportOption.fromJson(json['recommended'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from,
      'to': to,
      'options': options.map((e) => e.toJson()).toList(),
      'recommended': recommended?.toJson(),
    };
  }
}
