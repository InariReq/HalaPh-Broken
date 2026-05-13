import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  final AdminAuthService authService;

  const AdminLoginScreen({super.key, required this.authService});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message ?? 'Admin sign in failed.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Admin sign in failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    width: 460,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(26),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.route_rounded,
                                size: 46,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'HalaPH Admin',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Sign in with a Firebase account that has an active admin_users document.',
                              ),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_rounded),
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (!text.contains('@')) {
                                    return 'Enter a valid email address.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_rounded),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Enter your password.';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _signIn(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _loading ? null : _signIn,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.login_rounded),
                                  label: const Text('Sign in'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 460, child: _OwnerSetupCard()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerSetupCard extends StatelessWidget {
  const _OwnerSetupCard();

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Go to Firebase Console.',
      'Open Authentication.',
      'Find jeraldforschool@gmail.com.',
      'Copy the UID.',
      'Open Firestore.',
      'Create collection admin_users if it does not exist.',
      'Create a document using the copied UID as the document ID.',
      'Add email, displayName, role owner, isActive true, timestamps, and manual_setup audit fields.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'First owner setup',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Do not create admin accounts from the client. The first owner must be added manually.',
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. '),
                    Expanded(child: Text(steps[i])),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const SelectableText(
              'admin_users/{uid}\n'
              'email: jeraldforschool@gmail.com\n'
              'displayName: Cheong, C Jerald Jia Le D.\n'
              'role: owner\n'
              'isActive: true\n'
              'createdAt: current timestamp\n'
              'updatedAt: current timestamp\n'
              'createdBy: manual_setup\n'
              'updatedBy: manual_setup',
            ),
          ],
        ),
      ),
    );
  }
}
