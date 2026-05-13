import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

import 'admin/admin_app.dart';
import 'models/destination.dart';
import 'services/simple_plan_service.dart';
import 'services/auth_service.dart';
import 'services/firebase_app_service.dart';
import 'services/theme_mode_service.dart';
import 'services/app_tutorial_service.dart';
import 'services/guide_presenter_controller.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';

import 'screens/explore_screen.dart';

import 'screens/create_plan_screen.dart';

import 'screens/plan_details_screen.dart';

import 'screens/explore_details_screen.dart';

import 'screens/my_plans_screen.dart';

import 'screens/profile_screen.dart';
import 'screens/trip_history_screen.dart';

import 'screens/map_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/share_plan_screen.dart';
import 'screens/route_options_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/add_place_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/app_tutorial_screen.dart';
import 'widgets/halaph_launch_preflight.dart';
import 'widgets/halaph_logo_loading.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnvSafe();
  // Allow time for env to be ready
  await Future.delayed(const Duration(milliseconds: 100));
  await FirebaseAppService.initialize().timeout(
    const Duration(seconds: 4),
    onTimeout: () {
      debugPrint('Startup: Firebase initialization timed out; continuing.');
      return false;
    },
  );
  await ThemeModeService.initialize().timeout(
    const Duration(milliseconds: 900),
    onTimeout: () {
      debugPrint(
          'Startup: theme initialization timed out; using default theme.');
    },
  );
  debugPrint(
      'Startup: notification initialization deferred until reminders use.');

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Flutter widget error: ${details.exceptionAsString()}');
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _HalaPhErrorPanel(
        message: kReleaseMode
            ? 'Something went wrong, but HalaPH is still running.'
            : details.exceptionAsString(),
      ),
    );
  };

  runApp(kIsWeb ? const AdminApp() : const HalaPhApp());
}

Future<void> _loadEnvSafe() async {
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('main: .env loaded, keys: ${dotenv.env.keys.toList()}');
  } catch (e) {
    debugPrint('main: Failed to load .env: $e');
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _launchAccepted = false;
  bool _checkingGuideMode = false;
  bool _showGuideMode = false;
  bool _guideModeShownThisSession = false;
  bool _guideModeStartupEvaluated = false;
  bool _guideModeStartupInFlight = false;
  bool _isLoggedIn = false;
  bool _loading = true;
  String? _sessionUid;
  StreamSubscription<firebase_auth.User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    AppTutorialService.guideReplayRequests
        .addListener(_handleGuideReplayRequest);
    _startAuthListener();
    _checkLogin();
  }

  Future<void> _startAuthListener() async {
    final firebaseReady = await FirebaseAppService.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('AuthWrapper: Firebase listener setup timed out.');
        return false;
      },
    );
    if (!firebaseReady) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;

    _authSubscription =
        firebase_auth.FirebaseAuth.instance.userChanges().listen((user) {
      if (!mounted) return;
      final nextUid = user?.uid;
      final sessionChanged = _sessionUid != nextUid;
      setState(() {
        _isLoggedIn = user != null;
        _sessionUid = nextUid;
        _loading = false;
        if (sessionChanged) {
          _guideModeStartupEvaluated = false;
          _guideModeStartupInFlight = false;
          _checkingGuideMode = false;
          if (nextUid == null) {
            _showGuideMode = false;
            _guideModeShownThisSession = false;
          } else if (!_showGuideMode) {
            _guideModeShownThisSession = false;
          }
        }
      });
    });
  }

  Future<void> _checkLogin() async {
    final auth = AuthService();
    final user = await auth.getCurrentUser().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('AuthWrapper: auth session check timed out.');
        return null;
      },
    );
    if (user != null) {
      unawaited(SimplePlanService.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('AuthWrapper: plan initialization timed out; continuing.');
        },
      ));
    }
    if (mounted) {
      setState(() {
        _isLoggedIn = user != null;
        _sessionUid = _safeCurrentFirebaseUid();
        _loading = false;
        _guideModeStartupEvaluated = false;
        if (user == null) {
          _showGuideMode = false;
          _guideModeShownThisSession = false;
        }
      });
    }
  }

  void _onLoginSuccess() {
    unawaited(SimplePlanService.initialize());
    setState(() {
      _isLoggedIn = true;
      _sessionUid = _safeCurrentFirebaseUid();
      _guideModeStartupEvaluated = false;
      _guideModeStartupInFlight = false;
      _checkingGuideMode = false;
    });
  }

  void _onLaunchStart() {
    setState(() {
      _launchAccepted = true;
    });
  }

  String? _safeCurrentFirebaseUid() {
    if (!FirebaseAppService.isInitialized) return null;
    try {
      return firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    } catch (error) {
      debugPrint('AuthWrapper: current Firebase UID unavailable: $error');
      return null;
    }
  }

  void _continueAfterTutorial(String reason) {
    debugPrint('Guide Mode closed: $reason');
    setState(() {
      _showGuideMode = false;
      _guideModeShownThisSession = true;
      _guideModeStartupEvaluated = true;
      _guideModeStartupInFlight = false;
      _checkingGuideMode = false;
    });
  }

  void _scheduleGuideModeStartupEvaluation() {
    if (!_launchAccepted ||
        _loading ||
        !_isLoggedIn ||
        _guideModeStartupEvaluated ||
        _guideModeStartupInFlight ||
        _guideModeShownThisSession ||
        _showGuideMode) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_evaluateGuideModeStartup());
      }
    });
  }

  Future<void> _evaluateGuideModeStartup() async {
    if (_guideModeStartupInFlight) return;

    if (!_launchAccepted) {
      _logGuideModeDecisionSkip('launch not accepted');
      return;
    }
    if (!_isLoggedIn) {
      _logGuideModeDecisionSkip('user is logged out');
      return;
    }
    if (_guideModeShownThisSession) {
      _logGuideModeDecisionSkip('already shown this session');
      _guideModeStartupEvaluated = true;
      return;
    }

    setState(() {
      _guideModeStartupInFlight = true;
      _checkingGuideMode = true;
    });

    var enabledEveryStart = false;
    var completed = false;
    var failed = false;
    try {
      final results = await Future.wait([
        AppTutorialService.isGuideModeEnabledOnStart(),
        AppTutorialService.isTutorialCompleted(),
      ]).timeout(const Duration(seconds: 2));
      enabledEveryStart = results[0];
      completed = results[1];
    } catch (error) {
      debugPrint('Guide Mode startup: skipped because settings failed: $error');
      failed = true;
    }

    if (!mounted) return;

    debugPrint(
      'Guide Mode decision: loggedIn=$_isLoggedIn, loading=$_loading, '
      'showEveryStart=$enabledEveryStart, completed=$completed, '
      'shownThisSession=$_guideModeShownThisSession, forceReplay=false',
    );

    if (failed) {
      debugPrint('Guide Mode decision: skipped because settings failed');
      setState(() {
        _checkingGuideMode = false;
        _guideModeStartupInFlight = false;
        _guideModeStartupEvaluated = true;
      });
      return;
    }

    if (!enabledEveryStart) {
      debugPrint('Guide Mode decision: skipped because every start is off');
      setState(() {
        _checkingGuideMode = false;
        _guideModeStartupInFlight = false;
        _guideModeStartupEvaluated = true;
      });
      return;
    }

    debugPrint('Guide Mode decision: showing because every start is on');
    setState(() {
      _checkingGuideMode = false;
      _guideModeStartupInFlight = false;
      _guideModeStartupEvaluated = true;
      _showGuideMode = true;
    });
  }

  void _handleGuideReplayRequest() {
    if (!mounted) return;
    debugPrint('Guide Mode replay: received by app shell');

    if (_showGuideMode) {
      debugPrint('Guide Mode replay: ignored because guide is already showing');
      return;
    }

    if (!_isLoggedIn) {
      debugPrint('Guide Mode replay: ignored because user is logged out');
      return;
    }

    setState(() {
      _showGuideMode = true;
      _guideModeShownThisSession = true;
      _guideModeStartupEvaluated = true;
      _guideModeStartupInFlight = false;
    });
  }

  void _logGuideModeDecisionSkip(String reason) {
    debugPrint(
      'Guide Mode decision: loggedIn=$_isLoggedIn, loading=$_loading, '
      'showEveryStart=unknown, completed=unknown, '
      'shownThisSession=$_guideModeShownThisSession, forceReplay=false',
    );
    debugPrint('Guide Mode decision: skipped because $reason');
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    AppTutorialService.guideReplayRequests
        .removeListener(_handleGuideReplayRequest);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_launchAccepted) {
      return HalaPhLaunchPreflight(
        onStart: _onLaunchStart,
      );
    }

    if (_checkingGuideMode) {
      return const HalaPhLogoLoading(
        label: 'Preparing HalaPH...',
        fullScreen: true,
      );
    }

    if (_loading) {
      return const HalaPhLogoLoading(
        label: 'Preparing HalaPH...',
        fullScreen: true,
      );
    }
    if (!_isLoggedIn) {
      return AccountsScreen(onLoginSuccess: _onLoginSuccess);
    }
    _scheduleGuideModeStartupEvaluation();
    return MainNavigation(
      key: ValueKey(_sessionUid ?? 'signed-in'),
      showGuideMode: _showGuideMode,
      onGuideModeFinished: () => _continueAfterTutorial('finish'),
      onGuideModeSkipped: () => _continueAfterTutorial('skip'),
    );
  }
}

final GoRouter _router = GoRouter(
  errorBuilder: (context, state) {
    debugPrint('GoRouter error: ${state.error}');
    return const _HalaPhErrorScreen();
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthWrapper()),
    GoRoute(
      path: '/explore-details',
      builder: (context, state) {
        final destination = _decodeDestinationQuery(
          state.uri.queryParameters['destination'],
        );
        return ExploreDetailsScreen(
          destinationId: state.uri.queryParameters['destinationId'] ??
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
      path: '/trip-history',
      builder: (context, state) => const TripHistoryScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/accounts',
      builder: (context, state) =>
          AccountsScreen(onLoginSuccess: () => context.go('/')),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) =>
          AccountsScreen(onLoginSuccess: () => context.go('/')),
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
          destinationId: state.uri.queryParameters['destinationId'] ??
              destination?.id ??
              '',
          destinationName: state.uri.queryParameters['destinationName'] ??
              destination?.name ??
              'Destination',
          source: state.uri.queryParameters['source'],
          destination: destination,
        );
      },
    ),
  ],
);

class _HalaPhErrorScreen extends StatelessWidget {
  const _HalaPhErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HalaPH')),
      body: _HalaPhErrorPanel(
        message: 'This page could not be opened.',
        onGoHome: () => context.go('/'),
      ),
    );
  }
}

class _HalaPhErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback? onGoHome;

  const _HalaPhErrorPanel({
    required this.message,
    this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Colors.orange[700],
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  maxLines: kReleaseMode ? 3 : 6,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (onGoHome != null) ...[
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onGoHome,
                    child: const Text('Go Home'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
  final bool showGuideMode;
  final VoidCallback? onGuideModeFinished;
  final VoidCallback? onGuideModeSkipped;

  const MainNavigation({
    super.key,
    this.showGuideMode = false,
    this.onGuideModeFinished,
    this.onGuideModeSkipped,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final _guidePresenterController = GuidePresenterController();
  final _homeNavKey = GlobalKey();
  final _exploreNavKey = GlobalKey();
  final _plansNavKey = GlobalKey();
  final _favoritesNavKey = GlobalKey();
  final _friendsNavKey = GlobalKey();
  final _profileNavKey = GlobalKey();

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (!widget.showGuideMode) return;
    switch (index) {
      case 1:
        _guidePresenterController
            .signalSafely(GuidePresenterSignal.openExplore);
        break;
      case 2:
        _guidePresenterController.signalSafely(GuidePresenterSignal.openPlans);
        break;
      case 3:
        _guidePresenterController
            .signalSafely(GuidePresenterSignal.openFavorites);
        break;
      case 4:
        _guidePresenterController
            .signalSafely(GuidePresenterSignal.openFriends);
        break;
      case 5:
        _guidePresenterController
            .signalSafely(GuidePresenterSignal.openSettings);
        break;
    }
  }

  void _onGuideStepChanged(int stepIndex) {
    final targetIndex = switch (stepIndex) {
      0 => 0,
      1 => 1,
      2 => 1,
      3 => 1,
      4 => 1,
      5 => 1,
      6 => 3,
      7 => 3,
      8 => 2,
      9 => 2,
      10 => 4,
      11 => 5,
      12 => 5,
      _ => _currentIndex,
    };
    if (targetIndex == _currentIndex) return;
    setState(() {
      _currentIndex = targetIndex;
    });
  }

  @override
  void dispose() {
    _guidePresenterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBackground =
        isDark ? const Color(0xFF111827) : Colors.white.withValues(alpha: 0.96);
    final navBorder =
        isDark ? const Color(0xFF263244) : const Color(0xFFE3ECF8);

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(guideModeDemo: widget.showGuideMode),
              ExploreScreen(
                guideModeDemo: widget.showGuideMode,
                guidePresenterController:
                    widget.showGuideMode ? _guidePresenterController : null,
                onGuideDestinationSelected: widget.showGuideMode
                    ? _guidePresenterController.selectDestination
                    : null,
              ),
              MyPlansScreen(
                guideModeDemo: widget.showGuideMode,
                guidePresenterController:
                    widget.showGuideMode ? _guidePresenterController : null,
              ),
              FavoritesScreen(
                guideModeDemo: widget.showGuideMode,
                guidePresenterController:
                    widget.showGuideMode ? _guidePresenterController : null,
              ),
              FriendsScreen(
                guideModeDemo: widget.showGuideMode,
                guidePresenterController:
                    widget.showGuideMode ? _guidePresenterController : null,
              ),
              ProfileScreen(
                guideModeDemo: widget.showGuideMode,
                guidePresenterController:
                    widget.showGuideMode ? _guidePresenterController : null,
              ),
            ],
          ),
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            decoration: BoxDecoration(
              color: navBackground,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: navBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(Icons.home_rounded, 'Home', 0, _homeNavKey),
                    _buildNavItem(
                      Icons.explore_rounded,
                      'Explore',
                      1,
                      _exploreNavKey,
                    ),
                    _buildNavItem(
                      Icons.calendar_month_rounded,
                      'Plans',
                      2,
                      _plansNavKey,
                    ),
                    _buildNavItem(
                      Icons.favorite_rounded,
                      'Favorites',
                      3,
                      _favoritesNavKey,
                    ),
                    _buildNavItem(
                      Icons.people_alt_rounded,
                      'Friends',
                      4,
                      _friendsNavKey,
                    ),
                    _buildNavItem(
                      Icons.person_rounded,
                      'Profile',
                      5,
                      _profileNavKey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.showGuideMode)
          Positioned.fill(
            child: AppTutorialScreen(
              launchedFromSettings: false,
              targetKeys: GuideModeTargetKeys(
                homeNavKey: _homeNavKey,
                exploreNavKey: _exploreNavKey,
                plansNavKey: _plansNavKey,
                favoritesNavKey: _favoritesNavKey,
                friendsNavKey: _friendsNavKey,
                profileNavKey: _profileNavKey,
              ),
              presenterController: _guidePresenterController,
              onStepChanged: _onGuideStepChanged,
              onFinish: widget.onGuideModeFinished ?? () {},
              onSkip: widget.onGuideModeSkipped ?? () {},
            ),
          ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, GlobalKey key) {
    final isActive = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = Colors.blue[isDark ? 300 : 700]!;
    final inactiveColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final activeBackground =
        isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEAF3FF);

    return Expanded(
      child: KeyedSubtree(
        key: key,
        child: GestureDetector(
          onTap: () => _onTabChanged(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? activeBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: isActive ? 1.08 : 1,
                  child: Icon(
                    icon,
                    size: 23,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1,
                    color: isActive ? activeColor : inactiveColor,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _buildHalaTheme(Brightness brightness) {
  const seedBlue = Color(0xFF1976D2);
  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedBlue,
    brightness: brightness,
  );

  final scaffoldBackground =
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF6F8FC);
  final surfaceColor = isDark ? const Color(0xFF111827) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
    fontFamily: 'Roboto',
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(
        color: textColor,
        height: 1.35,
        letterSpacing: -0.1,
      ),
      bodyMedium: TextStyle(
        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
        height: 1.35,
        letterSpacing: -0.05,
      ),
      labelLarge: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scaffoldBackground,
      foregroundColor: textColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF263244) : const Color(0xFFE5EAF3),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: seedBlue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      labelStyle: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    ),
  );
}

class HalaPhApp extends StatelessWidget {
  const HalaPhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeModeService.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'HalaPH - Discover Philippines',
          theme: _buildHalaTheme(Brightness.light),
          darkTheme: _buildHalaTheme(Brightness.dark),
          themeMode: themeMode,
          routerDelegate: _router.routerDelegate,
          routeInformationParser: _router.routeInformationParser,
          routeInformationProvider: _router.routeInformationProvider,
        );
      },
    );
  }
}
