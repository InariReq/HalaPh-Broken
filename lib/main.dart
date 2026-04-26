import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

import 'models/destination.dart';
import 'services/simple_plan_service.dart';
import 'services/auth_service.dart';
import 'db/local_db.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';

import 'screens/explore_screen.dart';

import 'screens/create_plan_screen.dart';

import 'screens/plan_details_screen.dart';

import 'screens/explore_details_screen.dart';

import 'screens/my_plans_screen.dart';

import 'screens/profile_screen.dart';

import 'screens/map_screen.dart';
import 'screens/db_inspector_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/share_plan_screen.dart';
import 'screens/route_options_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/add_place_screen.dart';
import 'screens/friends_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnvSafe();
  await LocalDb.instance.init();
  await SimplePlanService.initialize();
  runApp(const HalaPhApp());
}

Future<void> _loadEnvSafe() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Running without .env is supported; APIs will gracefully fall back.
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoggedIn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final auth = AuthService();
    final user = await auth.getCurrentUser();
    if (mounted) {
      setState(() {
        _isLoggedIn = user != null;
        _loading = false;
      });
    }
  }

  void _onLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isLoggedIn) {
      return AccountsScreen(onLoginSuccess: _onLoginSuccess);
    }
    return const MainNavigation();
  }
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthWrapper()),
    GoRoute(
      path: '/explore-details',
      builder: (context, state) {
        final destination = _decodeDestinationQuery(
          state.uri.queryParameters['destination'],
        );
        return ExploreDetailsScreen(
          destinationId:
              state.uri.queryParameters['destinationId'] ??
              destination?.id ??
              '',
          source: state.uri.queryParameters['source'],
          destination: destination,
        );
      },
    ),
    GoRoute(
      path: '/plan-details',
      builder: (context, state) {
        final planId = state.uri.queryParameters['planId'];
        return PlanDetailsScreen(planId: planId);
      },
    ),
    GoRoute(path: '/view', builder: (context, state) => const MapScreen()),
    GoRoute(
      path: '/db-inspector',
      builder: (context, state) => const DbInspectorScreen(),
    ),
    GoRoute(
      path: '/create-plan',
      builder: (context, state) => const CreatePlanScreen(),
    ),
    GoRoute(
      path: '/my-plans',
      builder: (context, state) => const MyPlansScreen(),
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    GoRoute(
      path: '/accounts',
      builder: (context, state) => const AccountsScreen(),
    ),
    GoRoute(
      path: '/share-plan',
      builder: (context, state) =>
          SharePlanScreen(planId: state.uri.queryParameters['planId'] ?? ''),
    ),
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/add-place',
      builder: (context, state) => const AddPlaceScreen(),
    ),
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendsScreen(),
    ),
    GoRoute(
      path: '/route-options',
      builder: (context, state) {
        final destination = _decodeDestinationQuery(
          state.uri.queryParameters['destination'],
        );
        return RouteOptionsScreen(
          destinationId:
              state.uri.queryParameters['destinationId'] ??
              destination?.id ??
              '',
          destinationName:
              state.uri.queryParameters['destinationName'] ??
              destination?.name ??
              'Destination',
          source: state.uri.queryParameters['source'],
          destination: destination,
        );
      },
    ),
  ],
);

Destination? _decodeDestinationQuery(String? encoded) {
  if (encoded == null || encoded.isEmpty) return null;
  try {
    final dynamic decoded = jsonDecode(encoded);
    if (decoded is Map<String, dynamic>) {
      return Destination.fromJson(decoded);
    }
    if (decoded is Map) {
      return Destination.fromJson(Map<String, dynamic>.from(decoded));
    }
  } catch (_) {
    return null;
  }
  return null;
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          ExploreScreen(),
          MyPlansScreen(),
          FavoritesScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(Icons.home, 'Home', 0),
                _buildNavItem(Icons.explore, 'Explore', 1),
                _buildNavItem(Icons.calendar_today, 'Plans', 2),
                _buildNavItem(Icons.favorite, 'Favorites', 3),
                _buildNavItem(Icons.person, 'Profile', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? Colors.blue[600] : Colors.grey[400],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.blue[600] : Colors.grey[400],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class HalaPhApp extends StatelessWidget {
  const HalaPhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'HalaPH - Discover Philippines',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      routerDelegate: _router.routerDelegate,
      routeInformationParser: _router.routeInformationParser,
      routeInformationProvider: _router.routeInformationProvider,
    );
  }
}
