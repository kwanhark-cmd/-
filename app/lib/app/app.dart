import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/strings.dart';
import '../features/accounts/local_accounts.dart';
import '../ui/home_shell.dart';
import '../ui/login_screen.dart';
import '../ui/onboarding.dart';
import 'services.dart';

/// 앱 전체 상태: 누가 로그인했는지, 글씨 크기.
class AppState extends ChangeNotifier {
  AppState(this.env);
  final AppEnv env;
  UserContext? user;

  /// 로그인 전 화면의 글씨 크기 (마지막 사용자 설정을 기억).
  double get textScale =>
      user?.settings.textScale ?? (env.accounts.db.getSetting<num>('lastTextScale')?.toDouble() ?? 1.0);

  /// 다른 기능 단계(2~4단계)가 로그인 직후 기능을 붙이는 곳.
  static final List<Future<void> Function(UserContext)> plugins = [];

  Future<void> login(LocalUser u) async {
    user?.close();
    final ctx = await UserContext.open(env, u);
    for (final p in plugins) {
      await p(ctx);
    }
    user = ctx;
    env.logger.info('로그인 #${u.id}');
    notifyListeners();
  }

  void logout() {
    user?.close();
    user = null;
    notifyListeners();
  }

  void setTextScale(double v) {
    user?.settings.textScale = v;
    env.accounts.db.setSetting('lastTextScale', v);
    notifyListeners();
  }

  void refresh() => notifyListeners();
}

ThemeData buildTheme(Brightness b) {
  final cs = ColorScheme.fromSeed(seedColor: const Color(0xFFD32F2F), brightness: b);
  return ThemeData(
    colorScheme: cs,
    fontFamily: 'NotoSansKR',
    useMaterial3: true,
    visualDensity: VisualDensity.comfortable,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 16), bodyLarge: TextStyle(fontSize: 17)),
  );
}

class ChannelBiseoApp extends StatelessWidget {
  const ChannelBiseoApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return MaterialApp(
          title: S.appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          locale: const Locale('ko', 'KR'),
          supportedLocales: const [Locale('ko', 'KR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // 글씨 크기 설정을 모든 화면에 한 번에 적용
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(state.textScale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _root(),
        );
      },
    );
  }

  Widget _root() {
    final u = state.user;
    if (u == null) return LoginScreen(state: state);
    if (!u.settings.onboardingDone) return OnboardingWizard(state: state, user: u);
    return HomeShell(state: state, user: u);
  }
}
