import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/admin_featured_place.dart';
import '../models/admin_user.dart';
import '../services/admin_featured_places_service.dart';

class AdminFeaturedPlacesScreen extends StatefulWidget {
  final AdminUser currentAdmin;

  const AdminFeaturedPlacesScreen({
    super.key,
    required this.currentAdmin,
  });

  @override
  State<AdminFeaturedPlacesScreen> createState() =>
      _AdminFeaturedPlacesScreenState();
}

class _AdminFeaturedPlacesScreenState extends State<AdminFeaturedPlacesScreen> {
  final _service = AdminFeaturedPlacesService();

  bool get _canManage => widget.currentAdmin.role.canManageContent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminFeaturedPlace>>(
      stream: _service.watchFeaturedPlaces(),
      builder: (context, snapshot) {
        final places = snapshot.data ?? const <AdminFeaturedPlace>[];
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
            else if (places.isEmpty)
              const _EmptyFeaturedPlacesCard()
            else
              _FeaturedPlacesList(
                places: places,
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
                    Icons.star_rounded,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Featured Places',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Prioritize destinations for Explore, Search, and recommendations.',
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
              label: const Text('Add Featured Place'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<AdminFeaturedPlace>(
      context: context,
      builder: (context) => const _FeaturedPlaceFormDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await _service.createFeaturedPlace(
        place: result,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) _showSnack('Featured place added.');
    } catch (_) {
      if (mounted) _showSnack('Could not add featured place.');
    }
  }

  Future<void> _openEditDialog(AdminFeaturedPlace place) async {
    final result = await showDialog<AdminFeaturedPlace>(
      context: context,
      builder: (context) => _FeaturedPlaceFormDialog(existingPlace: place),
    );
    if (result == null || !mounted) return;
    try {
      await _service.updateFeaturedPlace(
        place: result,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) _showSnack('Featured place updated.');
    } catch (_) {
      if (mounted) _showSnack('Could not update featured place.');
    }
  }

  Future<void> _toggleActive(AdminFeaturedPlace place) async {
    try {
      await _service.setActive(
        placeId: place.id,
        isActive: !place.isActive,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) {
        _showSnack(place.isActive
            ? 'Featured place disabled.'
            : 'Featured place activated.');
      }
    } catch (_) {
      if (mounted) _showSnack('Could not update featured place status.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FeaturedPlacesList extends StatelessWidget {
  final List<AdminFeaturedPlace> places;
  final bool canManage;
  final ValueChanged<AdminFeaturedPlace> onEdit;
  final ValueChanged<AdminFeaturedPlace> onToggleActive;

  const _FeaturedPlacesList({
    required this.places,
    required this.canManage,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            children: [
              for (final place in places)
                _FeaturedPlaceCard(
                  place: place,
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
                DataColumn(label: Text('Place')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final place in places)
                  DataRow(
                    cells: [
                      DataCell(Text(place.priority.toString())),
                      DataCell(
                        SizedBox(
                          width: 280,
                          child: _PlaceTextSummary(place: place),
                        ),
                      ),
                      DataCell(Text(place.category)),
                      DataCell(Text(place.city)),
                      DataCell(_StatusBadge(isActive: place.isActive)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: canManage ? () => onEdit(place) : null,
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: place.isActive ? 'Disable' : 'Activate',
                              onPressed: canManage
                                  ? () => onToggleActive(place)
                                  : null,
                              icon: Icon(
                                place.isActive
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

class _FeaturedPlaceCard extends StatelessWidget {
  final AdminFeaturedPlace place;
  final bool canManage;
  final ValueChanged<AdminFeaturedPlace> onEdit;
  final ValueChanged<AdminFeaturedPlace> onToggleActive;

  const _FeaturedPlaceCard({
    required this.place,
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
                Expanded(child: _PlaceTextSummary(place: place)),
                const SizedBox(width: 12),
                _StatusBadge(isActive: place.isActive),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                    icon: Icons.sort_rounded,
                    label: 'Priority ${place.priority}'),
                _InfoChip(icon: Icons.category_rounded, label: place.category),
                _InfoChip(icon: Icons.location_city_rounded, label: place.city),
              ],
            ),
            if (place.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText('Image URL: ${place.imageUrl}'),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: canManage ? () => onEdit(place) : null,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: canManage ? () => onToggleActive(place) : null,
                  icon: Icon(
                    place.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(place.isActive ? 'Disable' : 'Activate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceTextSummary extends StatelessWidget {
  final AdminFeaturedPlace place;

  const _PlaceTextSummary({required this.place});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          place.name,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (place.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            place.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (place.imageUrl.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            place.imageUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _FeaturedPlaceFormDialog extends StatefulWidget {
  final AdminFeaturedPlace? existingPlace;

  const _FeaturedPlaceFormDialog({this.existingPlace});

  @override
  State<_FeaturedPlaceFormDialog> createState() =>
      _FeaturedPlaceFormDialogState();
}

class _FeaturedPlaceFormDialogState extends State<_FeaturedPlaceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _priorityController;
  late bool _isActive;

  bool get _isEditing => widget.existingPlace != null;

  @override
  void initState() {
    super.initState();
    final place = widget.existingPlace;
    _nameController = TextEditingController(text: place?.name ?? '');
    _cityController = TextEditingController(text: place?.city ?? '');
    _categoryController = TextEditingController(text: place?.category ?? '');
    _descriptionController =
        TextEditingController(text: place?.description ?? '');
    _imageUrlController = TextEditingController(text: place?.imageUrl ?? '');
    _priorityController =
        TextEditingController(text: (place?.priority ?? 10).toString());
    _isActive = place?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Featured Place' : 'Add Featured Place'),
      content: SizedBox(
        width: 560,
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
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                  keyboardType: TextInputType.url,
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
          child: Text(_isEditing ? 'Save changes' : 'Add place'),
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existingPlace;
    final place = AdminFeaturedPlace(
      id: existing?.id ?? '',
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      imageUrl: _imageUrlController.text.trim(),
      priority: int.parse(_priorityController.text.trim()),
      isActive: _isActive,
    );
    Navigator.pop(context, place);
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
          'Admins can view featured places. Owner or Head Admin access is required to make changes.',
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
        ? 'Firestore rules do not allow this admin to read featured places yet.'
        : 'Featured places could not be loaded. Try again later.';
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
                    'Featured places unavailable',
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

class _EmptyFeaturedPlacesCard extends StatelessWidget {
  const _EmptyFeaturedPlacesCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.star_border_rounded, size: 44),
            SizedBox(height: 12),
            Text('No featured places yet'),
            SizedBox(height: 6),
            Text(
              'Owner or Head Admin users can add featured destinations here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
