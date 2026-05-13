import 'package:flutter/material.dart';

import '../models/admin_ad.dart';
import '../models/admin_user.dart';
import '../services/admin_ads_service.dart';

class AdminAdsScreen extends StatefulWidget {
  final AdminUser currentAdmin;

  const AdminAdsScreen({
    super.key,
    required this.currentAdmin,
  });

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> {
  final _service = AdminAdsService();

  bool get _canManage => widget.currentAdmin.role.canManageContent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminAd>>(
      stream: _service.watchAds(),
      builder: (context, snapshot) {
        final ads = snapshot.data ?? const <AdminAd>[];
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            if (!_canManage) ...[
              const _ReadOnlyNotice(),
              const SizedBox(height: 16),
            ],
            if (snapshot.connectionState == ConnectionState.waiting)
              const _LoadingCard()
            else if (snapshot.hasError)
              _ErrorCard(error: snapshot.error)
            else if (ads.isEmpty)
              const _EmptyAdsCard()
            else
              _AdsList(
                ads: ads,
                canManage: _canManage,
                onEdit: _openEditDialog,
                onToggleActive: _toggleActive,
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
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 560,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.campaign_rounded,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advertisements Management',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Manage banner, fullscreen, and sponsored card ads for HalaPH.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _canManage ? _openAddDialog : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Advertisement'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<AdminAd>(
      context: context,
      builder: (context) => const _AdFormDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await _service.createAd(
        ad: result,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) _showSnack('Advertisement added.');
    } catch (_) {
      if (mounted) _showSnack('Could not add advertisement.');
    }
  }

  Future<void> _openEditDialog(AdminAd ad) async {
    final result = await showDialog<AdminAd>(
      context: context,
      builder: (context) => _AdFormDialog(existingAd: ad),
    );
    if (result == null || !mounted) return;
    try {
      await _service.updateAd(
        ad: result,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) _showSnack('Advertisement updated.');
    } catch (_) {
      if (mounted) _showSnack('Could not update advertisement.');
    }
  }

  Future<void> _toggleActive(AdminAd ad) async {
    try {
      await _service.setActive(
        adId: ad.id,
        isActive: !ad.isActive,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) {
        _showSnack(
            ad.isActive ? 'Advertisement disabled.' : 'Advertisement enabled.');
      }
    } catch (_) {
      if (mounted) _showSnack('Could not update advertisement status.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdsList extends StatelessWidget {
  final List<AdminAd> ads;
  final bool canManage;
  final ValueChanged<AdminAd> onEdit;
  final ValueChanged<AdminAd> onToggleActive;

  const _AdsList({
    required this.ads,
    required this.canManage,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 960) {
          return Column(
            children: [
              for (final ad in ads)
                _AdCard(
                  ad: ad,
                  canManage: canManage,
                  onEdit: onEdit,
                  onToggleActive: onToggleActive,
                ),
            ],
          );
        }
        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Priority')),
                DataColumn(label: Text('Advertisement')),
                DataColumn(label: Text('Advertiser')),
                DataColumn(label: Text('Placement')),
                DataColumn(label: Text('Schedule')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final ad in ads)
                  DataRow(
                    cells: [
                      DataCell(Text(ad.priority.toString())),
                      DataCell(
                        SizedBox(
                          width: 320,
                          child: _AdTextSummary(ad: ad),
                        ),
                      ),
                      DataCell(Text(ad.advertiserName)),
                      DataCell(Text(ad.placement.label)),
                      DataCell(_ScheduleText(ad: ad)),
                      DataCell(_StatusBadge(isActive: ad.isActive)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: canManage ? () => onEdit(ad) : null,
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: ad.isActive ? 'Disable' : 'Enable',
                              onPressed:
                                  canManage ? () => onToggleActive(ad) : null,
                              icon: Icon(
                                ad.isActive
                                    ? Icons.block_rounded
                                    : Icons.check_circle_rounded,
                              ),
                            ),
                          ],
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

class _AdCard extends StatelessWidget {
  final AdminAd ad;
  final bool canManage;
  final ValueChanged<AdminAd> onEdit;
  final ValueChanged<AdminAd> onToggleActive;

  const _AdCard({
    required this.ad,
    required this.canManage,
    required this.onEdit,
    required this.onToggleActive,
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
                Expanded(child: _AdTextSummary(ad: ad)),
                const SizedBox(width: 12),
                _StatusBadge(isActive: ad.isActive),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.sort_rounded,
                  label: 'Priority ${ad.priority}',
                ),
                _InfoChip(
                  icon: Icons.campaign_rounded,
                  label: ad.placement.label,
                ),
                _InfoChip(
                  icon: Icons.business_rounded,
                  label: ad.advertiserName,
                ),
                if (ad.hasSchedule)
                  _InfoChip(
                    icon: Icons.event_rounded,
                    label: _formatSchedule(ad),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: canManage ? () => onEdit(ad) : null,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: canManage ? () => onToggleActive(ad) : null,
                  icon: Icon(
                    ad.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(ad.isActive ? 'Disable' : 'Enable'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdTextSummary extends StatelessWidget {
  final AdminAd ad;

  const _AdTextSummary({required this.ad});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ad.title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (ad.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            ad.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (ad.imageUrl.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Image: ${ad.imageUrl}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (ad.targetUrl.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Target: ${ad.targetUrl}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _ScheduleText extends StatelessWidget {
  final AdminAd ad;

  const _ScheduleText({required this.ad});

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatSchedule(ad),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _AdFormDialog extends StatefulWidget {
  final AdminAd? existingAd;

  const _AdFormDialog({this.existingAd});

  @override
  State<_AdFormDialog> createState() => _AdFormDialogState();
}

class _AdFormDialogState extends State<_AdFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _advertiserController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _targetUrlController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priorityController;
  late final TextEditingController _startsAtController;
  late final TextEditingController _endsAtController;
  late AdminAdPlacement _placement;
  late bool _isActive;

  bool get _isEditing => widget.existingAd != null;

  @override
  void initState() {
    super.initState();
    final ad = widget.existingAd;
    _titleController = TextEditingController(text: ad?.title ?? '');
    _advertiserController =
        TextEditingController(text: ad?.advertiserName ?? '');
    _imageUrlController = TextEditingController(text: ad?.imageUrl ?? '');
    _targetUrlController = TextEditingController(text: ad?.targetUrl ?? '');
    _descriptionController = TextEditingController(text: ad?.description ?? '');
    _priorityController =
        TextEditingController(text: (ad?.priority ?? 10).toString());
    _startsAtController = TextEditingController(
      text: ad?.startsAt == null ? '' : _formatDateInput(ad!.startsAt!),
    );
    _endsAtController = TextEditingController(
      text: ad?.endsAt == null ? '' : _formatDateInput(ad!.endsAt!),
    );
    _placement = ad?.placement ?? AdminAdPlacement.banner;
    _isActive = ad?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _advertiserController.dispose();
    _imageUrlController.dispose();
    _targetUrlController.dispose();
    _descriptionController.dispose();
    _priorityController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Advertisement' : 'Add Advertisement'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: _requiredValidator('Title'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _advertiserController,
                  decoration:
                      const InputDecoration(labelText: 'Advertiser name'),
                  validator: _requiredValidator('Advertiser name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdminAdPlacement>(
                  initialValue: _placement,
                  decoration: const InputDecoration(labelText: 'Placement'),
                  items: [
                    for (final placement in AdminAdPlacement.values)
                      DropdownMenuItem(
                        value: placement,
                        child: Text(placement.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _placement = value);
                  },
                  validator: (value) =>
                      value == null ? 'Placement is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetUrlController,
                  decoration: const InputDecoration(labelText: 'Target URL'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startsAtController,
                        decoration: const InputDecoration(
                          labelText: 'Starts at',
                          hintText: 'YYYY-MM-DD or ISO date',
                        ),
                        keyboardType: TextInputType.datetime,
                        validator: _optionalIsoDateValidator('Starts at'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endsAtController,
                        decoration: const InputDecoration(
                          labelText: 'Ends at',
                          hintText: 'YYYY-MM-DD or ISO date',
                        ),
                        keyboardType: TextInputType.datetime,
                        validator: _optionalIsoDateValidator('Ends at'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priorityController,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Priority is required.';
                    if (int.tryParse(text) == null) {
                      return 'Priority must be a whole number.';
                    }
                    return null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save changes' : 'Add advertisement'),
        ),
      ],
    );
  }

  FormFieldValidator<String> _requiredValidator(String label) {
    return (value) {
      if ((value ?? '').trim().isEmpty) return '$label is required.';
      return null;
    };
  }

  FormFieldValidator<String> _optionalIsoDateValidator(String label) {
    return (value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return null;
      if (DateTime.tryParse(text) == null) {
        return '$label must use YYYY-MM-DD or ISO date format.';
      }
      return null;
    };
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existingAd;
    final ad = AdminAd(
      id: existing?.id ?? '',
      title: _titleController.text.trim(),
      advertiserName: _advertiserController.text.trim(),
      placement: _placement,
      imageUrl: _imageUrlController.text.trim(),
      targetUrl: _targetUrlController.text.trim(),
      description: _descriptionController.text.trim(),
      priority: int.parse(_priorityController.text.trim()),
      isActive: _isActive,
      startsAt: _parseOptionalDate(_startsAtController.text),
      endsAt: _parseOptionalDate(_endsAtController.text),
    );
    Navigator.pop(context, ad);
  }

  DateTime? _parseOptionalDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return DateTime.parse(text);
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.visibility_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Read-only access'),
        subtitle: const Text(
          'Admin accounts can view advertisements. Owner or Head Admin access is required to add, edit, enable, or disable ads.',
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmptyAdsCard extends StatelessWidget {
  const _EmptyAdsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No advertisements yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add banner, fullscreen, or sponsored card ads when they are ready for admin management.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object? error;

  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.error_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Advertisements unavailable'),
        subtitle: Text(
          'Could not load advertisement records. Check admin permissions and try again. ${error ?? ''}',
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        isActive ? Icons.check_circle_rounded : Icons.block_rounded,
        size: 16,
      ),
      label: Text(isActive ? 'Active' : 'Inactive'),
    );
  }
}

String _formatSchedule(AdminAd ad) {
  if (!ad.hasSchedule) return 'No schedule';
  final start =
      ad.startsAt == null ? 'Any start' : _formatDateInput(ad.startsAt!);
  final end = ad.endsAt == null ? 'No end' : _formatDateInput(ad.endsAt!);
  return '$start to $end';
}

String _formatDateInput(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
