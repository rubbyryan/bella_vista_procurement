import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/user_store.dart';
import '../../core/widgets.dart';

enum AuthMode { login, register }

/// Sign in / register. Accounts are in-memory demo accounts (see
/// core/user_store.dart); no backend call is made for them. The server address
/// below is only used by the pages that already talk to the backend.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController(); // email / username on sign in, email on register
  final _pw = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _confirm = TextEditingController();
  late final _server = TextEditingController(text: ref.read(apiBaseProvider));

  AuthMode _mode = AuthMode.login;
  bool _showPw = false;
  String? _error;
  String? _info;
  String? _serverStatus;
  bool _serverOk = false, _testing = false;

  @override
  void dispose() {
    for (final c in [_id, _pw, _first, _last, _phone, _confirm, _server]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switch(AuthMode m) => setState(() {
        _mode = m;
        _error = null;
        _info = null;
        _form.currentState?.reset();
      });

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _emailRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  String? _phoneRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[0-9+\-()\s]+$').hasMatch(s) || digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  // Same rule as the backend: 8+ characters with upper, lower and a number.
  String? _passwordRule(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Required';
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,100}$').hasMatch(s)) {
      return 'Use 8+ characters with upper, lower case and a number';
    }
    return null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final users = ref.read(userStoreProvider);
    if (_mode == AuthMode.login) {
      final r = users.login(_id.text, _pw.text);
      if (r.error != null) {
        setState(() => _error = r.error);
        return;
      }
      ref.read(apiBaseProvider.notifier).set(_server.text);
      ref.read(sessionProvider.notifier).login(r.user!.name, r.user!.role, department: r.user!.department);
      context.go('/app/dashboard');
    } else {
      final err = users.register(
        firstName: _first.text,
        lastName: _last.text,
        email: _id.text,
        phoneNumber: _phone.text,
        password: _pw.text,
      );
      if (err != null) {
        setState(() => _error = err);
        return;
      }
      setState(() {
        _mode = AuthMode.login;
        _error = null;
        _info = 'Registration received. Your account stays inactive until the System Administrator '
            'assigns your role and department and activates it.';
        _pw.clear();
        _confirm.clear();
      });
    }
  }

  Future<void> _testServer() async {
    setState(() {
      _testing = true;
      _serverStatus = null;
    });
    try {
      final d = await ApiClient(_server.text).get('/departments');
      setState(() {
        _serverOk = true;
        _serverStatus = 'Connected. ${(d as List).length} item departments found.';
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

  @override
  Widget build(BuildContext context) {
    final login = _mode == AuthMode.login;
    final demo = ref.watch(userStoreProvider).users.where((u) => u.active && !u.accountLocked).toList();

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
                    return Form(
                      key: _form,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(login ? 'Welcome back' : 'Create your account', style: t.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(login
                            ? 'Sign in to manage requisitions'
                            : 'Register to request access to the procurement portal'),
                        const SizedBox(height: 16),
                        if (_info != null) ...[
                          Text(_info!, style: TextStyle(color: t.colorScheme.tertiary)),
                          const SizedBox(height: 12),
                        ],
                        if (!login) ...[
                          LayoutBuilder(builder: (context, box) {
                            final first = TextFormField(
                              controller: _first,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'First name'),
                              validator: _required,
                            );
                            final last = TextFormField(
                              controller: _last,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'Surname'),
                              validator: _required,
                            );
                            if (box.maxWidth < 380) {
                              return Column(children: [first, const SizedBox(height: 12), last]);
                            }
                            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: first),
                              const SizedBox(width: 12),
                              Expanded(child: last),
                            ]);
                          }),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _id,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: login ? 'Email or username' : 'Email address',
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                          ),
                          validator: login ? _required : _emailRule,
                        ),
                        const SizedBox(height: 12),
                        if (!login) ...[
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              hintText: '+263 77 123 4567',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: _phoneRule,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _pw,
                          obscureText: !_showPw,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _showPw ? 'Hide password' : 'Show password',
                              onPressed: () => setState(() => _showPw = !_showPw),
                              icon: Icon(_showPw ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                            ),
                          ),
                          validator: login ? _required : _passwordRule,
                          onFieldSubmitted: (_) {
                            if (login) _submit();
                          },
                        ),
                        if (!login) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirm,
                            obscureText: !_showPw,
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            validator: (v) => (v ?? '') != _pw.text ? 'Passwords do not match' : null,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: ctaStyle(c),
                            onPressed: _submit,
                            child: Text(login ? 'Sign in' : 'Register'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: () => _switch(login ? AuthMode.register : AuthMode.login),
                            child: Text(login ? 'New here? Register' : 'Already registered? Sign in'),
                          ),
                        ),
                        Center(
                          child: Text(
                            login
                                ? 'Need help? Contact the System Administrator'
                                : 'Accounts are activated by the System Administrator',
                            style: t.textTheme.labelMedium,
                          ),
                        ),
                        if (login) ...[
                          const Divider(height: 32),
                          Text('Demo accounts (password $kDemoPassword)', style: t.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final u in demo)
                              ActionChip(
                                label: Text(u.role.label),
                                onPressed: () => setState(() {
                                  _id.text = u.email;
                                  _pw.text = kDemoPassword;
                                  _error = null;
                                }),
                              ),
                          ]),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Server address'),
                            subtitle: const Text('Used by departments, requisitions and stock'),
                            children: [
                              TextFormField(
                                controller: _server,
                                decoration: const InputDecoration(
                                    labelText: 'Server address', prefixIcon: Icon(Icons.dns_rounded)),
                                validator: (v) => (v == null || !v.trim().startsWith('http'))
                                    ? 'Start with http:// or https://'
                                    : null,
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
                        ],
                      ]),
                    );
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
