import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../core/widgets.dart';

<<<<<<< HEAD
enum AuthMode { login, register }

=======
/// The backend has no login yet, so people say who they are and in which role.
/// The name is sent to the backend as the actor (issuedBy, approver, ...).
>>>>>>> 644b51d7db41bc6a7eda86fbababccd98d16d8fb
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
<<<<<<< HEAD
  final _id = TextEditingController(); // email / username on sign in, email on register
  final _pw = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false, _remember = false, _policy = false, _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final c in [_id, _pw, _first, _last, _phone, _confirm]) {
      c.dispose();
    }
=======
  late final _name = TextEditingController(text: ref.read(prefsProvider).getString('user_name') ?? '');
  late final _server = TextEditingController(text: ref.read(apiBaseProvider));
  Role _role = Role.requester;
  String? _status;
  bool _ok = false, _testing = false;

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
>>>>>>> 644b51d7db41bc6a7eda86fbababccd98d16d8fb
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      final d = await ApiClient(_server.text).get('/departments');
      setState(() {
        _ok = true;
        _status = 'Connected. ${(d as List).length} item departments found.';
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _status = '$e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

<<<<<<< HEAD
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

  void _submit() {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!_form.currentState!.validate()) return;
    final store = ref.read(storeProvider);
    if (_mode == AuthMode.login) {
      final err = store.login(_id.text, _pw.text);
      if (err != null) {
        setState(() => _error = err);
      } else {
        context.go('/app/dashboard');
      }
    } else {
      if (!_policy) {
        setState(() => _error = 'Please accept the school IT use policy.');
        return;
      }
      final err = store.register(
        firstName: _first.text,
        lastName: _last.text,
        email: _id.text,
        phoneNumber: _phone.text,
        password: _pw.text,
      );
      if (err != null) {
        setState(() => _error = err);
      } else {
        setState(() {
          _mode = AuthMode.login;
          _info = 'Registration received. Your account stays inactive until the System Administrator assigns your role and department and activates it.';
          _pw.clear();
          _confirm.clear();
        });
      }
    }
  }

  void _demo(AppUser u) {
    setState(() {
      _mode = AuthMode.login;
      _id.text = u.email;
      _pw.text = kDemoPassword;
      _error = null;
    });
=======
  void _go() {
    if (!_form.currentState!.validate()) return;
    ref.read(apiBaseProvider.notifier).set(_server.text);
    ref.read(sessionProvider.notifier).login(_name.text, _role);
    context.go('/app/dashboard');
>>>>>>> 644b51d7db41bc6a7eda86fbababccd98d16d8fb
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
                    return Form(
                      key: _form,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Welcome', style: t.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        const Text('Say who you are. Your name is recorded on every action you take.'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                              labelText: 'Your full name', prefixIcon: Icon(Icons.person_outline_rounded)),
                          validator: (v) => (v == null || v.trim().length < 3) ? 'Enter your full name' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Role>(
                          value: _role,
                          decoration: const InputDecoration(labelText: 'Your role'),
                          items: [for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.label))],
                          onChanged: (v) => setState(() => _role = v ?? _role),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _server,
                          decoration: const InputDecoration(
                              labelText: 'Server address', prefixIcon: Icon(Icons.dns_rounded)),
                          validator: (v) =>
                              (v == null || !v.trim().startsWith('http')) ? 'Start with http:// or https://' : null,
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          OutlinedButton.icon(
                            onPressed: _testing ? null : _test,
                            icon: const Icon(Icons.wifi_tethering_rounded),
                            label: Text(_testing ? 'Testing...' : 'Test connection'),
                          ),
                        ]),
                        if (_status != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_status!,
                                style: TextStyle(color: _ok ? t.colorScheme.tertiary : t.colorScheme.error)),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(style: ctaStyle(c), onPressed: _go, child: const Text('Continue')),
                        ),
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
<<<<<<< HEAD

  Widget _formBody(BuildContext context) {
    final store = ref.watch(storeProvider);
    final login = _mode == AuthMode.login;
    return Builder(builder: (c) {
      final t = Theme.of(c);
      return Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(login ? 'Welcome back' : 'Create your account', style: t.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(login ? 'Sign in to manage requisitions' : 'Register to request access to the procurement portal'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AuthMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: AuthMode.login, label: Text('Sign in')),
                ButtonSegment(value: AuthMode.register, label: Text('Register')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _error = null;
                _info = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          if (_info != null) _banner(c, _info!, false),
          if (_error != null) _banner(c, _error!, true),
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
            onFieldSubmitted: (_) => _submit(),
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
            obscureText: !_show,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
            validator: login ? (v) => (v == null || v.isEmpty) ? 'Required' : null : _pwRule,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          if (!login) ...[
            TextFormField(
              controller: _confirm,
              obscureText: !_show,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (v) => v != _pw.text ? 'Passwords do not match' : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _policy,
              onChanged: (v) => setState(() => _policy = v ?? false),
              title: const Text('I accept the school IT use policy'),
            ),
          ] else
            Row(children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? false),
                  title: const Text('Remember me'),
                ),
              ),
              TextButton(
                onPressed: () => snack(context, 'Demo: a reset link would be emailed here.'),
                child: const Text('Forgot password?'),
              ),
            ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: login ? null : ctaStyle(c),
              onPressed: _busy ? null : _submit,
              child: Text(login ? 'Sign in' : 'Register'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              login ? 'Need help? Contact the System Administrator' : 'Accounts are activated by the System Administrator',
              style: t.textTheme.labelSmall,
            ),
          ),
          if (login) ...[
            const Divider(height: 32),
            Text('Demo accounts (password $kDemoPassword)', style: t.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final u in store.users.where((u) => u.active))
                ActionChip(label: Text(u.role.label), onPressed: () => _demo(u)),
            ]),
          ],
        ]),
      );
    });
  }

  Widget _banner(BuildContext c, String msg, bool isError) {
    final s = Theme.of(c).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? s.errorContainer : s.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(msg, style: TextStyle(color: isError ? s.onErrorContainer : s.onPrimaryContainer)),
    );
  }
=======
>>>>>>> 644b51d7db41bc6a7eda86fbababccd98d16d8fb
}
