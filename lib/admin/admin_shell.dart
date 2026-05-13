import 'package:flutter/material.dart';

import 'admin_routes.dart';
import 'models/admin_user.dart';
import 'models/admin_user_role.dart';
import 'screens/admin_ads_screen.dart';
import 'screens/admin_app_settings_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_featured_places_screen.dart';
import 'screens/admin_locations_screen.dart';
import 'screens/admin_users_screen.dart';
import 'services/admin_auth_service.dart';
import 'widgets/admin_guard.dart';
import 'widgets/admin_nav_item.dart';

class AdminShell extends StatefulWidget {
  final AdminUser adminUser;
  final AdminAuthService authService;

  const AdminShell({
    super.key,
    required this.adminUser,
    required this.authService,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminRouteId _selectedRoute = AdminRouteId.dashboard;

  AdminRouteConfig get _route => AdminRoutes.byId(_selectedRoute);

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final content = Row(
      children: [
        if (isWide) _buildSidebar(context),
        Expanded(child: _buildMainContent(context)),
      ],
    );

    return Scaffold(
      appBar: isWide ? null : _buildAppBar(context),
      drawer: isWide ? null : Drawer(child: _buildNavigation(context)),
      body: SafeArea(child: content),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(_route.title),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: widget.authService.signOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 284,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE1EAF5))),
      ),
      child: _buildNavigation(context),
    );
  }

  Widget _buildNavigation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.route_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HalaPH Admin',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      widget.adminUser.role.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final route in AdminRoutes.routes)
                AdminNavItem(
                  icon: route.icon,
                  label: route.title,
                  selected: route.id == _selectedRoute,
                  locked: !_canAccess(route.minimumRole),
                  onTap: () {
                    setState(() => _selectedRoute = route.id);
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.adminUser.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: widget.authService.signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE1EAF5))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _route.title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Signed in as ${widget.adminUser.email}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Chip(
                avatar: const Icon(Icons.verified_user_rounded, size: 18),
                label: Text(widget.adminUser.role.label),
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminGuard(
            adminUser: widget.adminUser,
            minimumRole: _route.minimumRole,
            child: _buildPage(),
          ),
        ),
      ],
    );
  }

  Widget _buildPage() {
    return switch (_selectedRoute) {
      AdminRouteId.dashboard => const AdminDashboardScreen(),
      AdminRouteId.locations =>
        AdminLocationsScreen(currentAdmin: widget.adminUser),
      AdminRouteId.advertisements =>
        AdminAdsScreen(currentAdmin: widget.adminUser),
      AdminRouteId.featuredPlaces =>
        AdminFeaturedPlacesScreen(currentAdmin: widget.adminUser),
      AdminRouteId.appSettings =>
        AdminAppSettingsScreen(currentAdmin: widget.adminUser),
      AdminRouteId.adminUsers =>
        AdminUsersScreen(currentAdmin: widget.adminUser),
    };
  }

  bool _canAccess(AdminUserRole minimumRole) {
    return switch (minimumRole) {
      AdminUserRole.owner => widget.adminUser.role == AdminUserRole.owner,
      AdminUserRole.headAdmin => widget.adminUser.role == AdminUserRole.owner ||
          widget.adminUser.role == AdminUserRole.headAdmin,
      AdminUserRole.admin => true,
    };
  }
}
