import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/state.dart';
import '../../core/user_store.dart';
import '../../core/widgets.dart';

enum _Mode { signIn, register }

/// Sign in (POST /api/auth/login) or create an account (POST /api/auth/register).
/// New accounts are inactive until an administrator activates them on the Users page.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _loginForm = GlobalKey<FormState>();
  final _regForm = GlobalKey<FormState>();

  // sign in
  final _username = TextEditingController();
  final _pw = TextEditingController();

  // register
  final _emp = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _regUser = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _job = TextEditingController();
  final _regPw = TextEditingController();
  final _regPw2 = TextEditingController();

  late final _server = TextEditingController(text: ref.read(apiBaseProvider));

  _Mode _mode = _Mode.signIn;
  bool _showPw = false;
  bool _busy = false;
  String? _error;
  String? _notice; // success message shown on the sign-in screen after registering
  String? _serverStatus;
  bool _serverOk = false, _testing = false;

  @override
  void dispose() {
    for (final c in [_username, _pw, _emp, _first, _last, _regUser, _email, _phone, _job, _regPw, _regPw2, _server]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _emailRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  String? _usernameRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (s.contains(RegExp(r'\s'))) return 'No spaces allowed';
    return null;
  }

  String? _passwordRule(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Required';
    if (s.length < 8) return 'At least 8 characters';
    if (s.length > 72) return 'At most 72 characters';
    return null;
  }

  static String _str(dynamic v) => v == null ? '' : '$v';

  void _switch(_Mode m) => setState(() {
    _mode = m;
    _error = null;
    if (m == _Mode.register) _notice = null;
  });

  // ------------------------------------------------------------ sign in
  Future<void> _signIn() async {
    if (_busy || !_loginForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final base = _server.text.trim();
      final r = await ApiClient(base).post('/api/auth/login', body: {
        'username': _username.text.trim(),
        'password': _pw.text,
      });
      final j = Map<String, dynamic>.from(r as Map);
      final token = _str(j['accessToken']);
      if (token.isEmpty) throw ApiException('The server did not return an access token.');
      final code = _str(j['role']);
      final name = '${_str(j['firstName'])} ${_str(j['lastName'])}'.trim();
      final expires = j['expiresIn'] is num ? (j['expiresIn'] as num).toInt() : 86400;

      ref.read(apiBaseProvider.notifier).set(base);
      ref.read(sessionProvider.notifier).login(
        name: name.isEmpty ? _str(j['username']) : name,
        role: appRoleFor(code),
        roleCode: code,
        userId: j['userId'] is num ? (j['userId'] as num).toInt() : 0,
        username: _str(j['username']),
        token: token,
        expiresInSeconds: expires,
        department: _str(j['department']),
      );
      if (!mounted) return;
      context.go('/app/dashboard');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.status) {
          401 => 'Incorrect username or password.',
          403 => 'This account is not active yet, or it is locked. New accounts must be activated by an '
              'administrator before you can sign in.',
          _ => e.message,
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----------------------------------------------------------- register
  Future<void> _register() async {
    if (_busy || !_regForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    try {
      final base = _server.text.trim();
      final r = await ApiClient(base).post('/api/auth/register', body: {
        'employeeNumber': _emp.text.trim(),
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'username': _regUser.text.trim(),
        'email': _email.text.trim(),
        'phoneNumber': opt(_phone.text),
        'password': _regPw.text,
        'jobTitle': opt(_job.text),
      });
      final msg = r is Map ? _str(r['message']) : '';
      ref.read(apiBaseProvider.notifier).set(base);
      if (!mounted) return;
      setState(() {
        _username.text = _regUser.text.trim();
        _pw.clear();
        _notice = msg.isEmpty
            ? 'Registration received. An administrator must activate your account before you can sign in.'
            : msg;
        for (final c in [_emp, _first, _last, _regUser, _email, _phone, _job, _regPw, _regPw2]) {
          c.clear();
        }
        _mode = _Mode.signIn;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------ server address
  Future<void> _testServer() async {
    setState(() {
      _testing = true;
      _serverStatus = null;
    });
    try {
      await ApiClient(_server.text).ping();
      setState(() {
        _serverOk = true;
        _serverStatus = 'Connected. The server is reachable.';
      });
    } catch (e) {
      setState(() {
        _serverOk = false;
        _serverStatus = '$e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // ---------------------------------------------------------------- UI
  Widget _pwToggle() => IconButton(
    tooltip: _showPw ? 'Hide password' : 'Show password',
    onPressed: () => setState(() => _showPw = !_showPw),
    icon: Icon(_showPw ? Icons.visibility_off_rounded : Icons.visibility_rounded),
  );

  Widget _signInForm(BuildContext c, ThemeData t) => Form(
    key: _loginForm,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Welcome back', style: t.textTheme.headlineMedium),
      const SizedBox(height: 4),
      const Text('Sign in to manage requisitions'),
      if (_notice != null) ...[
        const SizedBox(height: 12),
        Text(_notice!, style: TextStyle(color: t.colorScheme.tertiary)),
      ],
      const SizedBox(height: 16),
      TextFormField(
        controller: _username,
        autocorrect: false,
        enabled: !_busy,
        decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline_rounded)),
        validator: _required,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _pw,
        obscureText: !_showPw,
        enabled: !_busy,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: _pwToggle(),
        ),
        validator: _required,
        onFieldSubmitted: (_) => _signIn(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: t.colorScheme.error)),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: ctaStyle(c),
          onPressed: _busy ? null : _signIn,
          child: Text(_busy ? 'Signing in...' : 'Sign in'),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: _busy ? null : () => _switch(_Mode.register),
          child: const Text('New here? Create an account'),
        ),
      ),
    ]),
  );

  Widget _registerForm(BuildContext c, ThemeData t) {
    return Form(
      key: _regForm,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Create your account', style: t.textTheme.headlineMedium),
        const SizedBox(height: 4),
        const Text('An administrator will assign your role and department and activate your account before you can sign in.'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emp,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Employee number', prefixIcon: Icon(Icons.badge_outlined)),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _first,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'First name'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _last,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Last name'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _regUser,
          enabled: !_busy,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Username',
            helperText: 'You will use this to sign in',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          validator: _usernameRule,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
          validator: _emailRule,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number (optional)', hintText: '+263 77 123 4567'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _job,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Job title (optional)',
            helperText: 'Helps the administrator choose your role and department',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _regPw,
          obscureText: !_showPw,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: '8 to 72 characters',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: _pwToggle(),
          ),
          validator: _passwordRule,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _regPw2,
          obscureText: !_showPw,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_rounded)),
          validator: (v) => v != _regPw.text ? 'Passwords do not match' : null,
          onFieldSubmitted: (_) => _register(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: t.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: ctaStyle(c),
            onPressed: _busy ? null : _register,
            child: Text(_busy ? 'Submitting...' : 'Create account'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => _switch(_Mode.signIn),
            child: const Text('Already have an account? Sign in'),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(children: [
                const Align(alignment: Alignment.centerRight, child: AppearanceMenuButton()),
                const LogoBadge(size: 96),
                const SizedBox(height: 16),
                Panel(
                  padding: const EdgeInsets.all(24),
                  child: Builder(builder: (c) {
                    final t = Theme.of(c);
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _mode == _Mode.signIn ? _signInForm(c, t) : _registerForm(c, t),
                      const Divider(height: 32),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Server address'),
                        subtitle: const Text('Where the backend is running'),
                        children: [
                          TextFormField(
                            controller: _server,
                            decoration: const InputDecoration(
                                labelText: 'Server address', prefixIcon: Icon(Icons.dns_rounded)),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _testing ? null : _testServer,
                              icon: const Icon(Icons.wifi_tethering_rounded),
                              label: Text(_testing ? 'Testing...' : 'Test connection'),
                            ),
                          ),
                          if (_serverStatus != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_serverStatus!,
                                  style: TextStyle(color: _serverOk ? t.colorScheme.tertiary : t.colorScheme.error)),
                            ),
                        ],
                      ),
                    ]);
                  }),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}