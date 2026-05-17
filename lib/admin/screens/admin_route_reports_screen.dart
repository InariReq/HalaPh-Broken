import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/admin_route_correction_report.dart';
import '../services/admin_route_correction_report_service.dart';

class AdminRouteReportsScreen extends StatefulWidget {
  const AdminRouteReportsScreen({super.key});

  @override
  State<AdminRouteReportsScreen> createState() =>
      _AdminRouteReportsScreenState();
}

class _AdminRouteReportsScreenState extends State<AdminRouteReportsScreen> {
  final _service = AdminRouteCorrectionReportService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminRouteCorrectionReport>>(
      stream: _service.streamAll(),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <AdminRouteCorrectionReport>[];
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const _LoadingCard()
            else if (snapshot.hasError)
              _ErrorCard(
                error: snapshot.error,
                onRetry: () => setState(() {}),
              )
            else if (reports.isEmpty)
              const _EmptyRouteReportsCard()
            else
              _RouteReportsList(
                reports: reports,
                onOpen: _openDetailDialog,
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.fact_check_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route Reports',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Read-only inbox for user-submitted terminal route correction reports.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetailDialog(
    AdminRouteCorrectionReport report,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _RouteReportDetailDialog(report: report),
    );
  }
}

class _RouteReportsList extends StatelessWidget {
  final List<AdminRouteCorrectionReport> reports;
  final ValueChanged<AdminRouteCorrectionReport> onOpen;

  const _RouteReportsList({
    required this.reports,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: [
              for (final report in reports)
                _RouteReportCard(
                  report: report,
                  onOpen: onOpen,
                ),
            ],
          );
        }

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Route')),
                DataColumn(label: Text('Terminal')),
                DataColumn(label: Text('Destination')),
                DataColumn(label: Text('Correction note')),
                DataColumn(label: Text('Submitted by')),
                DataColumn(label: Text('Submitted at')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final report in reports)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            _routeLabel(report),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(report.terminalName)),
                      DataCell(Text(report.destination)),
                      DataCell(
                        SizedBox(
                          width: 320,
                          child: Text(
                            report.correctionNote,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(_submittedByLabel(report))),
                      DataCell(Text(_formatSubmittedAt(report.submittedAt))),
                      DataCell(
                        IconButton(
                          tooltip: 'View report',
                          onPressed: () => onOpen(report),
                          icon: const Icon(Icons.visibility_rounded),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RouteReportCard extends StatelessWidget {
  final AdminRouteCorrectionReport report;
  final ValueChanged<AdminRouteCorrectionReport> onOpen;

  const _RouteReportCard({
    required this.report,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _routeLabel(report),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'View report',
                  onPressed: () => onOpen(report),
                  icon: const Icon(Icons.visibility_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.correctionNote,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.place_rounded,
                  label: report.terminalName,
                ),
                _InfoChip(
                  icon: Icons.flag_rounded,
                  label: report.destination,
                ),
                _InfoChip(
                  icon: Icons.person_rounded,
                  label: _submittedByLabel(report),
                ),
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: _formatSubmittedAt(report.submittedAt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteReportDetailDialog extends StatelessWidget {
  final AdminRouteCorrectionReport report;

  const _RouteReportDetailDialog({required this.report});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Correction Report'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Route', value: _routeLabel(report)),
              _DetailRow(
                  label: 'Route ID', value: _valueOrDash(report.routeId)),
              _DetailRow(
                label: 'Terminal',
                value: _valueOrDash(report.terminalName),
              ),
              _DetailRow(
                label: 'Destination',
                value: _valueOrDash(report.destination),
              ),
              _DetailRow(
                label: 'Submitted by',
                value: _submittedByLabel(report),
              ),
              _DetailRow(
                label: 'Submitted at',
                value: _formatSubmittedAt(report.submittedAt),
              ),
              const SizedBox(height: 16),
              Text(
                'Correction note',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SelectableText(_valueOrDash(report.correctionNote)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
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
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmptyRouteReportsCard extends StatelessWidget {
  const _EmptyRouteReportsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fact_check_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No correction reports yet.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final message = error is FirebaseException &&
            (error as FirebaseException).code == 'permission-denied'
        ? 'Firestore rules do not allow this admin to read route reports.'
        : 'Route reports could not be loaded. Try again later.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route reports unavailable',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(message),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _routeLabel(AdminRouteCorrectionReport report) {
  return _valueOrDash(report.routeName);
}

String _submittedByLabel(AdminRouteCorrectionReport report) {
  return _valueOrDash(report.submittedByUid);
}

String _valueOrDash(String value) {
  return value.trim().isEmpty ? '—' : value.trim();
}

String _formatSubmittedAt(DateTime? value) {
  if (value == null) return 'Pending timestamp';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
