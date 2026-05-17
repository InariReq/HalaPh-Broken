import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/models/admin_terminal_route.dart';
import '../services/user_terminal_route_service.dart';
import '../widgets/route_accuracy_badge.dart';

class TerminalRoutesScreen extends StatefulWidget {
  const TerminalRoutesScreen({super.key});

  @override
  State<TerminalRoutesScreen> createState() => _TerminalRoutesScreenState();
}

class _TerminalRoutesScreenState extends State<TerminalRoutesScreen> {
  final _service = UserTerminalRouteService();
  final _searchController = TextEditingController();
  late Stream<List<AdminTerminalRoute>> _routesStream;

  @override
  void initState() {
    super.initState();
    _routesStream = _service.streamActiveRoutes();
    _searchController.addListener(_refreshSearch);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() {
    setState(() {});
  }

  void _retryRoutes() {
    setState(() => _routesStream = _service.streamActiveRoutes());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terminal Routes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search terminals, destinations, or operators',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AdminTerminalRoute>>(
              stream: _routesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _RoutesErrorState(onRetry: _retryRoutes);
                }

                final routes = _filterRoutes(
                  snapshot.data ?? const <AdminTerminalRoute>[],
                );
                if (routes.isEmpty) return const _RoutesEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    return _TerminalRouteCard(
                      route: route,
                      onTap: () => _openDetailSheet(context, route),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<AdminTerminalRoute> _filterRoutes(List<AdminTerminalRoute> routes) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return routes;
    return routes.where((route) {
      return route.terminalName.toLowerCase().contains(query) ||
          route.destination.toLowerCase().contains(query) ||
          route.operatorName.toLowerCase().contains(query);
    }).toList(growable: false);
  }
}

Future<void> showTerminalRouteDetailSheet(
  BuildContext context,
  AdminTerminalRoute route,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TerminalRouteDetailSheet(route: route),
  );
}

void _openDetailSheet(BuildContext context, AdminTerminalRoute route) {
  showTerminalRouteDetailSheet(context, route);
}

class _TerminalRouteCard extends StatelessWidget {
  final AdminTerminalRoute route;
  final VoidCallback onTap;

  const _TerminalRouteCard({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                route.terminalName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      route.destination,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (route.via.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'via ${route.via}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (route.operatorName.isNotEmpty ||
                  route.busType.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  [route.operatorName, route.busType]
                      .where((value) => value.isNotEmpty)
                      .join(' • '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                formatTerminalRouteFare(route),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  RouteAccuracyBadge(
                    confidenceLevel: route.confidenceLevel,
                    sourceType: route.sourceType,
                  ),
                  _StatusChip(status: route.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TerminalRouteDetailSheet extends StatelessWidget {
  final AdminTerminalRoute route;

  const TerminalRouteDetailSheet({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                route.routeName.isEmpty ? route.terminalName : route.routeName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '${route.originTerminal} → ${route.destination}'
                '${route.via.isEmpty ? '' : ' via ${route.via}'}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              _DetailSection(
                title: 'Terminal Info',
                children: [
                  _DetailRow(label: 'Terminal', value: route.terminalName),
                  _DetailRow(label: 'Address', value: route.terminalAddress),
                  _DetailRow(label: 'City', value: route.city),
                  _DetailRow(
                    label: 'Coordinates',
                    value:
                        '${route.latitude.toStringAsFixed(4)}, ${route.longitude.toStringAsFixed(4)}',
                    subtle: true,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(_labelize(route.terminalType)),
                    ),
                  ),
                  if (route.landmarkNotes.isNotEmpty)
                    _DetailRow(label: 'Landmarks', value: route.landmarkNotes),
                  if (route.terminalPhotoUrl.isNotEmpty)
                    _DetailRow(
                      label: 'Photo URL',
                      value: route.terminalPhotoUrl,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Route Info',
                children: [
                  _DetailRow(
                    label: 'Route',
                    value: '${route.originTerminal} → ${route.destination}'
                        '${route.via.isEmpty ? '' : ' via ${route.via}'}',
                  ),
                  if (route.routeName.isNotEmpty)
                    _DetailRow(label: 'Route name', value: route.routeName),
                  if (route.operatorName.isNotEmpty)
                    _DetailRow(label: 'Operator', value: route.operatorName),
                  if (route.busType.isNotEmpty)
                    _DetailRow(label: 'Bus type', value: route.busType),
                  _DetailRow(
                    label: 'Fare',
                    value: formatTerminalRouteFare(route),
                  ),
                  if (route.scheduleText.isNotEmpty)
                    _DetailRow(label: 'Schedule', value: route.scheduleText),
                  if (route.firstTrip.isNotEmpty)
                    _DetailRow(label: 'First trip', value: route.firstTrip),
                  if (route.lastTrip.isNotEmpty)
                    _DetailRow(label: 'Last trip', value: route.lastTrip),
                  if (route.frequencyText.isNotEmpty)
                    _DetailRow(label: 'Frequency', value: route.frequencyText),
                  if (route.boardingGate.isNotEmpty)
                    _DetailRow(
                        label: 'Boarding gate', value: route.boardingGate),
                  if (route.dropOffPoint.isNotEmpty)
                    _DetailRow(
                        label: 'Drop-off point', value: route.dropOffPoint),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Verification',
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RouteAccuracyBadge(
                      confidenceLevel: route.confidenceLevel,
                      sourceType: route.sourceType,
                      large: true,
                    ),
                  ),
                  _DetailRow(
                    label: 'Accuracy',
                    value: terminalRouteAccuracyLabel(route),
                  ),
                  _DetailRow(
                    label: 'Source type',
                    value: _labelize(route.sourceType),
                  ),
                  if (route.sourceName.isNotEmpty)
                    _DetailRow(label: 'Source name', value: route.sourceName),
                  if (route.sourceUrl.isNotEmpty)
                    _DetailRow(label: 'Source URL', value: route.sourceUrl),
                  if (route.sourceScreenshotUrl.isNotEmpty)
                    _DetailRow(
                      label: 'Source screenshot URL',
                      value: route.sourceScreenshotUrl,
                    ),
                  if (route.verifiedBy.isNotEmpty)
                    _DetailRow(label: 'Verified by', value: route.verifiedBy),
                  if (route.verifiedAt != null)
                    _DetailRow(
                      label: 'Verified at',
                      value: _formatShortDate(route.verifiedAt!),
                    ),
                  if (route.lastCheckedAt != null)
                    _DetailRow(
                      label: 'Last checked',
                      value: _formatShortDate(route.lastCheckedAt!),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => showReportCorrectionSheet(context, route),
                icon: const Icon(Icons.report_outlined),
                label: const Text('Report Correction'),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showReportCorrectionSheet(
  BuildContext context,
  AdminTerminalRoute route,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ReportCorrectionSheet(
      parentContext: context,
      route: route,
    ),
  );
}

class _ReportCorrectionSheet extends StatefulWidget {
  final BuildContext parentContext;
  final AdminTerminalRoute route;

  const _ReportCorrectionSheet({
    required this.parentContext,
    required this.route,
  });

  @override
  State<_ReportCorrectionSheet> createState() => _ReportCorrectionSheetState();
}

class _ReportCorrectionSheetState extends State<_ReportCorrectionSheet> {
  final _controller = TextEditingController();
  final _service = UserTerminalRouteService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final routeLabel = route.routeName.isNotEmpty
        ? route.routeName
        : '${route.terminalName} → ${route.destination}';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report a Correction',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(routeLabel),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'What needs to be corrected?',
                helperText: 'At least 10 characters.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    debugPrint('Report correction submit tapped');
    final note = _controller.text.trim();

    if (note.length < 10) {
      debugPrint('Report correction validation failed: note too short');
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least 10 characters.'),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _isSubmitting = true);
    final route = widget.route;
    final parentMessenger = ScaffoldMessenger.of(widget.parentContext);
    try {
      debugPrint('Report correction write started');
      await _service
          .submitCorrection(
            routeId: route.id,
            routeName: route.routeName.isEmpty
                ? '${route.originTerminal} → ${route.destination}'
                : route.routeName,
            terminalName: route.terminalName,
            destination: route.destination,
            correctionNote: note,
            submittedByUid: FirebaseAuth.instance.currentUser?.uid,
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('Report correction write succeeded');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();
      parentMessenger.showSnackBar(
        const SnackBar(
          content: Text('Thank you, your correction has been submitted.'),
        ),
      );
    } catch (error) {
      debugPrint('Report correction write failed: $error');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      parentMessenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool subtle;

  const _DetailRow({
    required this.label,
    required this.value,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: subtle
                ? Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final (label, background, foreground) = switch (normalized) {
      'active' => ('Active', Colors.green.shade100, Colors.green.shade800),
      'needs_review' => (
          'Needs review',
          Colors.orange.shade100,
          Colors.orange.shade900,
        ),
      _ => ('Inactive', Colors.grey.shade300, Colors.grey.shade800),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: background,
      label: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RoutesEmptyState extends StatelessWidget {
  const _RoutesEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bus_outlined, size: 44),
          SizedBox(height: 12),
          Text('No terminal routes found.'),
        ],
      ),
    );
  }
}

class _RoutesErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _RoutesErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44),
          const SizedBox(height: 12),
          const Text('Could not load routes.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

String formatTerminalRouteFare(AdminTerminalRoute route) {
  final min = route.fareMin;
  final max = route.fareMax;
  if (min != null && max != null) {
    return '₱${_formatFareValue(min)} – ₱${_formatFareValue(max)}';
  }
  if (min != null) return 'from ₱${_formatFareValue(min)}';
  if (max != null) return 'up to ₱${_formatFareValue(max)}';
  return 'Fare not listed';
}

String terminalRouteAccuracyLabel(AdminTerminalRoute route) {
  if (route.status.trim().toLowerCase() == 'needs_review') {
    return 'Needs Review';
  }
  return routeAccuracyLabel(
    confidenceLevel: route.confidenceLevel,
    sourceType: route.sourceType,
  );
}

String _formatFareValue(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _labelize(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '—';
  return normalized
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
}
