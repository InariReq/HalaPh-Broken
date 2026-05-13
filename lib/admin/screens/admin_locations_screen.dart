import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/admin_location.dart';
import '../models/admin_user.dart';
import '../services/admin_locations_service.dart';

class AdminLocationsScreen extends StatefulWidget {
  final AdminUser currentAdmin;

  const AdminLocationsScreen({
    super.key,
    required this.currentAdmin,
  });

  @override
  State<AdminLocationsScreen> createState() => _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends State<AdminLocationsScreen> {
  final _service = AdminLocationsService();

  bool get _canManage => widget.currentAdmin.role.canManageContent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminLocation>>(
      stream: _service.watchLocations(),
      builder: (context, snapshot) {
        final locations = snapshot.data ?? const <AdminLocation>[];
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
            else if (locations.isEmpty)
              const _EmptyLocationsCard()
            else
              _LocationsList(
                locations: locations,
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
              width: 520,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_rounded,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Locations Management',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add and manage places shown in HalaPH Explore and Search.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _canManage ? _openAddDialog : null,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Add Location'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<AdminLocation>(
      context: context,
      builder: (context) => const _LocationFormDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await _service.createLocation(
        location: result,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) _showSnack('Location added.');
    } catch (_) {
      if (mounted) _showSnack('Could not add location.');
    }
  }

  Future<void> _openEditDialog(AdminLocation location) async {
    final result = await showDialog<AdminLocation>(
      context: context,
      builder: (context) => _LocationFormDialog(existingLocation: location),
    );
    if (result == null || !mounted) return;
    try {
      await _service.updateLocation(
        location: result,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) _showSnack('Location updated.');
    } catch (_) {
      if (mounted) _showSnack('Could not update location.');
    }
  }

  Future<void> _toggleActive(AdminLocation location) async {
    try {
      await _service.setActive(
        locationId: location.id,
        isActive: !location.isActive,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) {
        _showSnack(
            location.isActive ? 'Location disabled.' : 'Location enabled.');
      }
    } catch (_) {
      if (mounted) _showSnack('Could not update location status.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LocationsList extends StatelessWidget {
  final List<AdminLocation> locations;
  final bool canManage;
  final ValueChanged<AdminLocation> onEdit;
  final ValueChanged<AdminLocation> onToggleActive;

  const _LocationsList({
    required this.locations,
    required this.canManage,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (final location in locations)
                _LocationCard(
                  location: location,
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
                DataColumn(label: Text('Location')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Province')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final location in locations)
                  DataRow(
                    cells: [
                      DataCell(Text(location.priority.toString())),
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: _LocationTextSummary(location: location),
                        ),
                      ),
                      DataCell(Text(location.category)),
                      DataCell(Text(location.city)),
                      DataCell(Text(
                          location.province.isEmpty ? '—' : location.province)),
                      DataCell(_StatusBadge(isActive: location.isActive)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed:
                                  canManage ? () => onEdit(location) : null,
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: location.isActive ? 'Disable' : 'Enable',
                              onPressed: canManage
                                  ? () => onToggleActive(location)
                                  : null,
                              icon: Icon(
                                location.isActive
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

class _LocationCard extends StatelessWidget {
  final AdminLocation location;
  final bool canManage;
  final ValueChanged<AdminLocation> onEdit;
  final ValueChanged<AdminLocation> onToggleActive;

  const _LocationCard({
    required this.location,
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
                Expanded(child: _LocationTextSummary(location: location)),
                const SizedBox(width: 12),
                _StatusBadge(isActive: location.isActive),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.sort_rounded,
                  label: 'Priority ${location.priority}',
                ),
                _InfoChip(
                    icon: Icons.category_rounded, label: location.category),
                _InfoChip(
                  icon: Icons.location_city_rounded,
                  label: location.city,
                ),
                if (location.province.isNotEmpty)
                  _InfoChip(icon: Icons.map_rounded, label: location.province),
                if (location.hasCoordinates)
                  _InfoChip(
                    icon: Icons.my_location_rounded,
                    label:
                        '${location.latitude!.toStringAsFixed(5)}, ${location.longitude!.toStringAsFixed(5)}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: canManage ? () => onEdit(location) : null,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: canManage ? () => onToggleActive(location) : null,
                  icon: Icon(
                    location.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(location.isActive ? 'Disable' : 'Enable'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTextSummary extends StatelessWidget {
  final AdminLocation location;

  const _LocationTextSummary({required this.location});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.name,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (location.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            location.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (location.hasCoordinates) ...[
          const SizedBox(height: 4),
          Text(
            'Coordinates: ${location.latitude!.toStringAsFixed(6)}, ${location.longitude!.toStringAsFixed(6)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _LocationFormDialog extends StatefulWidget {
  final AdminLocation? existingLocation;

  const _LocationFormDialog({this.existingLocation});

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _provinceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _priorityController;
  late bool _isActive;

  bool get _isEditing => widget.existingLocation != null;

  @override
  void initState() {
    super.initState();
    final location = widget.existingLocation;
    _nameController = TextEditingController(text: location?.name ?? '');
    _cityController = TextEditingController(text: location?.city ?? '');
    _provinceController = TextEditingController(text: location?.province ?? '');
    _categoryController = TextEditingController(text: location?.category ?? '');
    _descriptionController =
        TextEditingController(text: location?.description ?? '');
    _latitudeController = TextEditingController(
      text: location?.latitude == null ? '' : location!.latitude.toString(),
    );
    _longitudeController = TextEditingController(
      text: location?.longitude == null ? '' : location!.longitude.toString(),
    );
    _priorityController =
        TextEditingController(text: (location?.priority ?? 10).toString());
    _isActive = location?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Location' : 'Add Location'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: _requiredValidator('Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: _requiredValidator('City'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _provinceController,
                  decoration: const InputDecoration(labelText: 'Province'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: _requiredValidator('Category'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        decoration:
                            const InputDecoration(labelText: 'Latitude'),
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        validator: _optionalDoubleValidator('Latitude'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        decoration:
                            const InputDecoration(labelText: 'Longitude'),
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        validator: _optionalDoubleValidator('Longitude'),
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
          child: Text(_isEditing ? 'Save changes' : 'Add location'),
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

  FormFieldValidator<String> _optionalDoubleValidator(String label) {
    return (value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return null;
      if (double.tryParse(text) == null) return '$label must be a number.';
      return null;
    };
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existingLocation;
    final latitudeText = _latitudeController.text.trim();
    final longitudeText = _longitudeController.text.trim();
    final location = AdminLocation(
      id: existing?.id ?? '',
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
      province: _provinceController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      latitude: latitudeText.isEmpty ? null : double.parse(latitudeText),
      longitude: longitudeText.isEmpty ? null : double.parse(longitudeText),
      priority: int.parse(_priorityController.text.trim()),
      isActive: _isActive,
    );
    Navigator.pop(context, location);
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

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.visibility_rounded),
        title: Text('Read-only access'),
        subtitle: Text(
          'Admins can view locations. Owner or Head Admin access is required to make changes.',
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
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object? error;

  const _ErrorCard({this.error});

  @override
  Widget build(BuildContext context) {
    final message = error is FirebaseException &&
            (error as FirebaseException).code == 'permission-denied'
        ? 'Firestore rules do not allow this admin to read locations yet.'
        : 'Locations could not be loaded. Try again later.';
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
                    'Locations unavailable',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLocationsCard extends StatelessWidget {
  const _EmptyLocationsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.place_outlined, size: 44),
            SizedBox(height: 12),
            Text('No locations yet'),
            SizedBox(height: 6),
            Text(
              'Owner or Head Admin users can add admin-managed locations here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
