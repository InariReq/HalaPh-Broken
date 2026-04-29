import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/notification_service.dart';
import 'package:halaph/models/user.dart';

class AccountsScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AccountsScreen({super.key, this.onLoginSuccess});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _auth = AuthService();
  User? _user;
  bool _loading = false;
  bool _isLogin = true;
  bool _notificationsEnabled = false;
  TimeOfDay _notificationTime = TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await _auth.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = u;
    });
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
    });
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final user = await _auth.login(email, pass);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _user = user;
    });
    if (user != null) {
      widget.onLoginSuccess?.call();
    } else {
      _showAuthError(
        _auth.lastAuthError ??
            'Could not log in. Check your email and password.',
      );
    }
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
    });
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final user = await _auth.register(
      email,
      pass,
      name: name.isNotEmpty ? name : null,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _user = user;
    });
    if (user != null) {
      widget.onLoginSuccess?.call();
    } else {
      _showAuthError(
        _auth.lastAuthError ??
            'Could not create the account. Try another email.',
      );
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    if (value) {
      await NotificationService.initialize();
      final hour = _notificationTime.hour;
      final minute = _notificationTime.minute;
      await NotificationService.scheduleDailyNotification(
        hour: hour,
        minute: minute,
        title: 'Plan Reminder',
        body: 'Review your itinerary for today!',
      );
    }
  }

  bool get _canLeaveAccountScreen {
    if (!_isLogin) return true;
    if (_user != null) return true;
    if (widget.onLoginSuccess == null) return true;
    return false;
  }

  void _handleClose() {
    if (!_isLogin) {
      setState(() => _isLogin = true);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user == null ? 'Accounts' : 'Account'),
        leading: _canLeaveAccountScreen
            ? IconButton(
                icon: Icon(_isLogin ? Icons.arrow_back : Icons.close),
                onPressed: _handleClose,
                tooltip: _isLogin ? 'Back' : 'Close',
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _user == null ? _buildLogin() : _buildAccountDetails(),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isLogin ? 'Sign in to your account' : 'Create an account',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (!_isLogin)
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _loading ? null : (_isLogin ? _login : _register),
          child: _loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isLogin ? 'Login' : 'Register'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _isLogin = !_isLogin),
          child: Text(
            _isLogin ? 'No account? Register' : 'Have an account? Login',
          ),
        ),
      ],
    );
  }

  Widget _buildAccountDetails() {
    final name = _user?.name ?? '';
    final email = _user?.email ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, $name',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text('Email: $email'),
        SizedBox(height: 20),
        ElevatedButton(onPressed: _logout, child: Text('Logout')),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Reminders'),
            Switch(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
          ],
        ),
        SizedBox(height: 8),
        Text('Time: ${_notificationTime.format(context)}'),
        ElevatedButton(
          onPressed: _notificationsEnabled
              ? () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _notificationTime,
                  );
                  if (picked != null) {
                    setState(() {
                      _notificationTime = picked;
                    });
                    await NotificationService.initialize();
                    await NotificationService.scheduleDailyNotification(
                      hour: picked.hour,
                      minute: picked.minute,
                      title: 'Plan Reminder',
                      body: 'Review your itinerary for today!',
                    );
                  }
                }
              : null,
          child: const Text('Set Reminder Time'),
        ),
      ],
    );
  }
}
