import 'package:flutter/material.dart';

import 'models/admin_user_role.dart';

enum AdminRouteId {
  dashboard,
  locations,
  terminalRoutes,
  advertisements,
  featuredPlaces,
  appSettings,
  adminUsers,
}

class AdminRouteConfig {
  final AdminRouteId id;
  final String title;
  final IconData icon;
  final AdminUserRole minimumRole;

  const AdminRouteConfig({
    required this.id,
    required this.title,
    required this.icon,
    required this.minimumRole,
  });
}

class AdminRoutes {
  static const routes = [
    AdminRouteConfig(
      id: AdminRouteId.dashboard,
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
      minimumRole: AdminUserRole.admin,
    ),
    AdminRouteConfig(
      id: AdminRouteId.locations,
      title: 'Locations',
      icon: Icons.place_rounded,
      minimumRole: AdminUserRole.admin,
    ),
    AdminRouteConfig(
      id: AdminRouteId.terminalRoutes,
      title: 'Terminal Routes',
      icon: Icons.directions_bus_outlined,
      minimumRole: AdminUserRole.admin,
    ),
    AdminRouteConfig(
      id: AdminRouteId.advertisements,
      title: 'Advertisements',
      icon: Icons.campaign_rounded,
      minimumRole: AdminUserRole.admin,
    ),
    AdminRouteConfig(
      id: AdminRouteId.featuredPlaces,
      title: 'Featured Places',
      icon: Icons.star_rounded,
      minimumRole: AdminUserRole.admin,
    ),
    AdminRouteConfig(
      id: AdminRouteId.appSettings,
      title: 'App Settings',
      icon: Icons.tune_rounded,
      minimumRole: AdminUserRole.headAdmin,
    ),
    AdminRouteConfig(
      id: AdminRouteId.adminUsers,
      title: 'Admin Users',
      icon: Icons.admin_panel_settings_rounded,
      minimumRole: AdminUserRole.headAdmin,
    ),
  ];

  static AdminRouteConfig byId(AdminRouteId id) {
    return routes.firstWhere((route) => route.id == id);
  }
}
