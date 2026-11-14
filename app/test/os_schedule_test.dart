import 'dart:io';

import 'package:channel_biseo/app/app.dart';
import 'package:channel_biseo/app/auto_run.dart';
import 'package:channel_biseo/core/failure.dart';
import 'package:channel_biseo/core/logger.dart';
import 'package:channel_biseo/features/runner/os_schedule.dart';
import 'package:channel_biseo/stages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 앱이 꺼져 있어도 자동 작업 (운영체제 예약).
class FakeOs {
  final calls = <List<String>>[];

  /// crontab 처럼 파일로 넘긴 내용 기록
  final written = <String>[];
  String crontab = '';
  int failCode = 0;
  bool registered = false;

  Future<ProcessResult> run(String exe, List<String> args) async {
    calls.add([exe, ...args]);
    if (failCode != 0) return ProcessResult(0, failCode, '', '권한 없음');
    if (exe == 'crontab' && args.first == '-l') return ProcessResult(0, crontab.isEmpty ? 1 : 0, crontab, '');
    if (exe == 'crontab') {
      crontab = File(args.first).readAsStringSync();
      written.add(crontab);
    }
    if (exe == 'schtasks') {
      if (args.first == '/Create') registered = true;
      if (args.first == '/Delete') registered = false;
      if (args.first == '/Query') return ProcessResult(0, registered ? 0 : 1, '', '');
    }
    return ProcessResult(0, 0, '', '');
  }

  OsScheduler scheduler(String os, {String? home}) => OsScheduler(
    os: os,
    exePath: os == 'windows'
        ? r'C:\Users\kim\AppData\Local\Programs\ChannelBiseo\channel_biseo.exe'
        : '/opt/채널 비서/channel_biseo',
    homeDir: home ?? Directory.systemTemp.createTempSync('home').path,
    tempDir: Directory.systemTemp.createTempSync('tmp').path,
    run: run,
    logger: AppLogger(),
  );
}

void main() {
  group('실행 인자', () {
    test('--auto-run=N 또는 환경 변수에서 사용자 번호', () {
      expect(OsScheduler.autoRunUser(['--auto-run=3'], {}), 3);
      expect(OsScheduler.autoRunUser([], {'CHANNEL_BISEO_AUTORUN': '7'}), 7);
      expect(OsScheduler.autoRunUser(['--other'], {}), isNull);
      expect(OsScheduler.autoRunUser(['--auto-run=x'], {}), isNull);
    });
  });

  group('운영체제별 등록', () {
    test('윈도우: 작업 스케줄러에 매일, 내 계정, 사용자별 이름', () async {
      final os = FakeOs();
      final s = os.scheduler('windows');
      await s.enable(2, 3, 5);
      final c = os.calls.single;
      expect(c.sublist(0, 6), ['schtasks', '/Create', '/F', '/SC', 'DAILY', '/TN']);
      expect(c[6], 'ChannelBiseo-AutoRun-u2');
      expect(c[8], '"${s.exePath}" --auto-run=2'); // 빈칸 있는 경로도 따옴표로
      expect(c[10], '03:05');
      expect(c, isNot(contains('/RU'))); // 다른 계정·관리자 권한 안 씀
      expect(await s.isEnabled(2), isTrue);
      await s.disable(2);
      expect(await s.isEnabled(2), isFalse);
    });

    test('맥: LaunchAgent 파일 + launchctl, 끄면 파일 지움', () async {
      final os = FakeOs();
      final s = os.scheduler('macos');
      await s.enable(1, 2, 5);
      final f = File(s.plistPath(1));
      expect(f.existsSync(), isTrue);
      final xml = f.readAsStringSync();
      expect(xml, contains('<key>Hour</key><integer>2</integer>'));
      expect(xml, contains('<string>--auto-run=1</string>'));
      expect(xml, contains('CHANNEL_BISEO_AUTORUN'));
      expect(os.calls.last, ['launchctl', 'load', '-w', f.path]);
      await s.disable(1);
      expect(f.existsSync(), isFalse);
    });

    test('리눅스: crontab 의 다른 줄은 그대로, 내 줄만 넣고 바꾸고 뺌', () async {
      final os = FakeOs()..crontab = '0 1 * * * /usr/bin/backup.sh\n';
      final s = os.scheduler('linux');
      await s.enable(1, 2, 5);
      expect(os.crontab, contains('/usr/bin/backup.sh'));
      expect(os.crontab, contains("5 2 * * * '/opt/채널 비서/channel_biseo' --auto-run=1 # channel-biseo-autorun-1"));
      await s.enable(1, 4, 5); // 시각 바꾸기 → 한 줄만
      expect('channel-biseo-autorun-1'.allMatches(os.crontab).length, 1);
      expect(os.crontab, contains('5 4 * * *'));
      await s.enable(2, 3, 5); // 다른 사용자
      await s.disable(1);
      expect(os.crontab, isNot(contains('autorun-1')));
      expect(os.crontab, contains('autorun-2'));
      expect(os.crontab, contains('/usr/bin/backup.sh'));
    });

    test('등록 실패는 알려 줌 / 지원하지 않는 운영체제', () async {
      final os = FakeOs()..failCode = 1;
      await expectLater(os.scheduler('windows').enable(1, 2, 5), throwsA(isA<AppFailure>()));
      expect(os.scheduler('android').supported, isFalse);
    });
  });

  group('예약으로 켜졌을 때', () {
    test('그 사용자로 자동 작업 한 번 → 같은 날 다시 켜지면 건너뜀, 자동 로그인은 그대로', () async {
      registerStages();
      final k = TestKit(start: DateTime(2026, 11, 14, 2, 5), inMemoryDb: false);
      final s = AppState(k.env);
      final user = k.env.accounts.create('예약', '1234');
      await s.login(user);
      final u = s.user!;
      await u.youtube.connectGoogle();
      u.settings
        ..runnerEnabled = true
        ..osScheduleEnabled = true
        ..runnerFromHour = 2
        ..runnerToHour = 6;
      s.logout();
      await k.env.secrets.write(AppState.autoLoginKey, '${user.id}');

      expect(await runScheduled(k.env, user.id), 'ran');
      expect(k.notifier.shown, isNotEmpty);
      expect(await runScheduled(k.env, user.id), 'skipped'); // 하루 한 번
      expect(await k.env.secrets.read(AppState.autoLoginKey), '${user.id}');
      expect(await runScheduled(k.env, 999), 'no-user');
    });

    test('설정에서 꺼 두었으면 실행하지 않음', () async {
      registerStages();
      final k = TestKit(start: DateTime(2026, 11, 14, 2, 5), inMemoryDb: false);
      final user = k.env.accounts.create('꺼짐', '1234');
      expect(await runScheduled(k.env, user.id), 'off');
    });
  });

  group('설정 화면', () {
    Future<(FakeOs, AppState)> open(WidgetTester t) async {
      registerStages();
      t.view.physicalSize = const Size(390 * 2, 2400 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final os = FakeOs();
      final k = TestKit(osScheduler: os.scheduler('windows'));
      final s = AppState(k.env);
      await s.login(k.env.accounts.create('설정', '1234'));
      s.user!.settings.onboardingDone = true;
      await t.pumpWidget(ChannelBiseoApp(state: s));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.settings).last);
      await t.pumpAndSettle();
      final f = find.byKey(const Key('os-schedule'));
      await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      return (os, s);
    }

    testWidgets('켜면 시작 시각으로 등록 + 자동 작업도 켜짐, 끄면 지움', (t) async {
      final (os, s) = await open(t);
      final st = s.user!.settings;
      expect(st.runnerEnabled, isFalse);
      await t.tap(find.byKey(const Key('os-schedule')));
      await t.pumpAndSettle();
      expect(st.osScheduleEnabled, isTrue);
      expect(st.runnerEnabled, isTrue);
      expect(os.calls.single[10], '${st.runnerFromHour.toString().padLeft(2, '0')}:05');
      await t.tap(find.byKey(const Key('os-schedule')));
      await t.pumpAndSettle();
      expect(st.osScheduleEnabled, isFalse);
      expect(os.calls.last.sublist(0, 2), ['schtasks', '/Delete']);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('등록에 실패하면 켜지지 않고 실패 창', (t) async {
      final (os, s) = await open(t);
      os.failCode = 5;
      await t.tap(find.byKey(const Key('os-schedule')));
      await t.pumpAndSettle();
      expect(s.user!.settings.osScheduleEnabled, isFalse);
      expect(find.byKey(const Key('failure-action')), findsWidgets);
      await t.pumpWidget(const SizedBox());
    });
  });
}
