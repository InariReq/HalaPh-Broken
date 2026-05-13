import 'package:flutter/material.dart';

import 'admin_shell.dart';
import 'admin_theme.dart';
import 'screens/admin_login_screen.dart';
import 'services/admin_auth_service.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HalaPH Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.light(),
      home: const _AdminAuthGate(),
    );
  }
}

class _AdminAuthGate extends StatefulWidget {
  const _AdminAuthGate();

  @override
  State<_AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<_AdminAuthGate> {
  final _authService = AdminAuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminAuthState>(
      stream: _authService.watchAdminState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AdminLoadingScreen();
        }

        final state = snapshot.data;
        if (state == null || state.firebaseUser == null) {
          return AdminLoginScreen(authService: _authService);
        }

        if (state.error == 'access-denied' || state.adminUser == null) {
          return _AccessProblemScreen(
            title: 'Access denied',
            message:
                'This Firebase account is not registered as a HalaPH admin.',
            authService: _authService,
          );
        }

        if (!state.adminUser!.isActive) {
          return _AccessProblemScreen(
            title: 'Access disabled',
            message: 'This admin account has been disabled by an owner.',
            authService: _authService,
          );
        }

        return AdminShell(
          adminUser: state.adminUser!,
          authService: _authService,
        );
      },
    );
  }
}

class _AdminLoadingScreen extends StatelessWidget {
  const _AdminLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking admin access...'),
          ],
        ),
      ),
    );
  }
}

class _AccessProblemScreen extends StatelessWidget {
  final String title;
  final String message;
  final AdminAuthService authService;

  const _AccessProblemScreen({
    required this.title,
    required this.message,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(message),
                    const SizedBox(height: 20),
                    const _FirstOwnerSetupNote(),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: authService.signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FirstOwnerSetupNote extends StatelessWidget {
  const _FirstOwnerSetupNote();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'First owner setup: create admin_users/{uid} manually in Firestore '
        'for jeraldforschool@gmail.com with displayName '
        '"Cheong, C Jerald Jia Le D.", role owner, isActive true, and '
        'createdBy/updatedBy manual_setup. Firestore rules must enforce '
        'admin-only access before production.',
        style: style,
      ),
    );
  }
}
