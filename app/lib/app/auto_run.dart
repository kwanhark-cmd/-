import 'package:flutter/material.dart';

import '../core/strings.dart';
import 'app.dart';
import 'services.dart';

/// 운영체제 예약으로 켜졌을 때 할 일: 그 사용자로 자동 작업을 한 번 하고 끝낸다.
/// 자동 작업 실행기의 규칙(켜짐·시간대·하루 한 번)은 그대로 따른다. 결과를 짧은 말로 돌려준다.
Future<String> runScheduled(AppEnv env, int userId) async {
  final log = env.logger;
  final found = env.accounts.list().where((x) => x.id == userId);
  if (found.isEmpty) {
    log.warn('예약 실행: 사용자 없음 (u$userId)');
    return 'no-user';
  }
  final state = AppState(env);
  await state.login(found.first);
  final u = state.user!;
  try {
    if (!u.settings.osScheduleEnabled) {
      log.info('예약 실행: 꺼져 있어 건너뜀');
      return 'off';
    }
    final ran = await u.runner.tick();
    log.info(ran ? '예약 실행: 자동 작업 끝' : '예약 실행: 오늘 이미 했거나 시간대가 아니어서 건너뜀');
    return ran ? 'ran' : 'skipped';
  } catch (e, st) {
    log.error('예약 실행 실패', e, st);
    return 'error';
  } finally {
    u.close(); // logout() 은 자동 로그인까지 끄므로 쓰지 않음
  }
}

/// 예약 실행 중에 잠깐 보이는 창 (끝나면 저절로 닫힘).
class AutoRunWindow extends StatelessWidget {
  const AutoRunWindow({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            S.osScheduleRunning,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ),
  );
}
