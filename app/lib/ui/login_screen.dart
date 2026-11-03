import 'package:flutter/material.dart';

import '../app/app.dart';
import '../core/failure.dart';
import '../core/strings.dart';
import '../features/accounts/local_accounts.dart';
import 'common.dart';

/// 사용자 고르기 + 비밀번호. 여러 사람이 같은 기기를 써도 서로의 자료는 보이지 않는다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});
  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final busy = Busy();

  @override
  Widget build(BuildContext context) {
    final users = widget.state.env.accounts.list();
    return Scaffold(
      appBar: AppBar(title: const Text(S.appName)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(S.loginTitle, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                for (final u in users)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BigButton(
                      key: Key('user-${u.id}'),
                      label: S.loginAs(u.name),
                      icon: Icons.person,
                      onPressed: () => _askPassword(u),
                    ),
                  ),
                const SizedBox(height: 12),
                BigButton(
                  key: const Key('new-user'),
                  label: S.loginNewUser,
                  icon: Icons.person_add,
                  primary: false,
                  onPressed: _createUser,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _askPassword(LocalUser u) async {
    final c = TextEditingController();
    var auto = false;
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(S.loginAs(u.name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('login-password'),
                controller: c,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: S.loginPassword),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
              CheckboxListTile(
                key: const Key('auto-login'),
                contentPadding: EdgeInsets.zero,
                value: auto,
                title: const Text(S.autoLogin),
                onChanged: (v) => setD(() => auto = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text(S.loginButton)),
          ],
        ),
      ),
    );
    if (pw == null || !mounted) return;
    final ok = widget.state.env.accounts.verify(u.id, pw);
    if (ok == null) {
      toast(context, S.loginWrong);
      return;
    }
    await widget.state.setAutoLogin(ok, auto);
    await busy.run(() => widget.state.login(ok));
  }

  Future<void> _createUser() async {
    final name = TextEditingController();
    final pw = TextEditingController();
    final pw2 = TextEditingController();
    String? error;
    final created = await showDialog<LocalUser>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text(S.loginNewUser),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('new-name'),
                  controller: name,
                  decoration: const InputDecoration(labelText: S.loginName),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new-password'),
                  controller: pw,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: S.loginPassword),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new-password2'),
                  controller: pw2,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: S.loginPasswordAgain),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
            FilledButton(
              key: const Key('new-user-ok'),
              onPressed: () {
                if (name.text.trim().isEmpty) return setD(() => error = S.loginNameEmpty);
                if (pw.text.length < 4) return setD(() => error = S.loginPasswordShort);
                if (pw.text != pw2.text) return setD(() => error = S.loginPasswordMismatch);
                try {
                  Navigator.pop(ctx, widget.state.env.accounts.create(name.text, pw.text));
                } on AppFailure catch (e) {
                  setD(() => error = e.kind == FailureKind.conflict ? S.loginNameTaken : e.userMessage);
                }
              },
              child: const Text(S.ok),
            ),
          ],
        ),
      ),
    );
    if (created == null || !mounted) return;
    await busy.run(() => widget.state.login(created));
  }
}
