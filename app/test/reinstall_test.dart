import 'dart:io';

import 'package:channel_biseo/app/app.dart';
import 'package:channel_biseo/app/services.dart';
import 'package:channel_biseo/core/logger.dart';
import 'package:channel_biseo/core/secret_store.dart';
import 'package:channel_biseo/core/strings.dart';
import 'package:channel_biseo/features/runner/notifier.dart';
import 'package:channel_biseo/features/settings/maintenance.dart';
import 'package:channel_biseo/features/voice/voice_io.dart';
import 'package:channel_biseo/stages.dart';
import 'package:channel_biseo/ui/backup_flow.dart';
import 'package:channel_biseo/ui/home_shell.dart';
import 'package:channel_biseo/ui/onboarding.dart';
import 'package:channel_biseo/ui/settings_screen.dart';
import 'package:flutter/material.dart';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'helpers.dart';
import 'update_test.dart' show copyFixture, fakeGithub, releaseJson;

/// 주인이 정한 설치 방식 (서명 키 없음):
/// - 안드로이드: 백업 파일을 앱 밖에 저장 → 새 설치 파일 받기 → 예전 앱 삭제 → 설치 → 백업에서 복원.
/// - 윈도우·맥·리눅스: 새 파일을 받아 설치하거나 바꾸기. 자료는 사용자 폴더에 그대로.
/// 안드로이드에서 앱을 지우면 앱 안의 자료가 모두 지워지므로, 백업이 앱 밖에 실제로 저장되는지와
/// 새로 설치한 앱에서 되살릴 수 있는지를 확인한다.

/// "휴대폰의 다운로드 폴더" 흉내: 앱 자료 폴더와 다른 곳.
class FakeSharedFolder {
  final dir = Directory.systemTemp.createTempSync('cb_shared_downloads');
  final saved = <String>[];
  bool cancel = false;

  Future<String?> save(String name, Uint8List bytes) async {
    if (cancel) return null;
    final f = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
    saved.add(f.path);
    return f.path;
  }
}

AppEnv phoneEnv({
  required String base,
  String osName = 'android',
  MemorySecretStore? secrets,
  http.Client? client,
  FakeSharedFolder? shared,
  List<Uri>? opened,
  String? Function()? pick,
  List<List<String>>? pickedExt,
}) => AppEnv(
  baseDir: base,
  documentsDir: Directory.systemTemp.createTempSync('cb_phone_docs').path,
  secrets: secrets ?? MemorySecretStore(),
  httpClient: client ?? noNetwork(),
  logger: AppLogger(),
  speech: FakeSpeechInput(const []),
  speaker: FakeSpeaker(),
  notifier: MemoryNotifier(),
  isDesktop: osName != 'android',
  platformName: 'test',
  appVersion: '1.1.0+6',
  launchUrl: (u) async {
    opened?.add(u);
    return true;
  },
  now: () => DateTime(2026, 11, 13, 9),
  osName: osName,
  // main.dart 와 같게: 앱 안 설치는 윈도우만, 앱 밖 저장은 안드로이드만
  installUpdate: null,
  saveFile: osName == 'android' ? shared?.save : null,
  pickFile: (ext) async {
    pickedExt?.add(ext);
    return pick?.call();
  },
  pickDirectory: () async => null,
);

List<String> filesIn(String dir) =>
    Directory(dir).listSync(recursive: true).whereType<File>().map((f) => p.relative(f.path, from: dir)).toList();

void main() {
  setUpAll(registerStages);

  group('안드로이드 새 버전 안내 (앱 안에서 설치하지 않음)', () {
    Future<(AppState, List<String>, List<Uri>, FakeSharedFolder)> open(WidgetTester t) async {
      final calls = <String>[];
      final opened = <Uri>[];
      final shared = FakeSharedFolder();
      final base = copyFixture();
      final env = phoneEnv(
        base: base,
        client: fakeGithub(releaseJson('v1.2.1'), calls: calls),
        shared: shared,
        opened: opened,
      );
      final s = AppState(env);
      await s.login(env.accounts.verify(1, '1234')!);
      s.user!.settings.reduceMotion = true;
      await t.pumpWidget(ChannelBiseoApp(state: s));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.settings).last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('update-check')));
      await t.pumpAndSettle();
      return (s, calls, opened, shared);
    }

    testWidgets('백업이 먼저인 순서 안내, "그대로예요" 약속 없음, 설치하기 버튼 없음', (t) async {
      final (_, calls, opened, _) = await open(t);
      expect(find.byKey(const Key('update-dialog')), findsOneWidget);
      expect(find.textContaining('그대로예요'), findsNothing);
      expect(find.text(S.updInstall), findsNothing);
      expect(find.byKey(const Key('update-android-warn')), findsOneWidget);
      // 순서: 1번이 백업, 앱 삭제는 그 뒤
      final steps = S.updAndroidSteps;
      expect(steps.indexOf('1.'), lessThan(steps.indexOf('백업')));
      expect(steps.indexOf('백업'), lessThan(steps.indexOf('지워요')));
      expect(steps, contains('앱 밖'));
      expect(steps, contains('백업에서 복원'));
      expect(find.byKey(const Key('update-backup')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, S.updDownloadFile), findsOneWidget);
      await t.tap(find.text(S.updLater));
      await t.pumpAndSettle();
      expect(opened, isEmpty);
      expect(calls.where((c) => c.contains('x/')), isEmpty);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('백업 없이 "설치 파일 받기" → 경고 → 백업 만들기(앱 밖) → 다시 안내 → 브라우저로 설치 파일', (t) async {
      final (s, calls, opened, shared) = await open(t);
      await t.tap(find.byKey(const Key('update-install')));
      await t.pumpAndSettle();
      // 백업을 아직 안 했으면 먼저 경고
      expect(find.byKey(const Key('update-no-backup')), findsOneWidget);
      expect(opened, isEmpty);
      await t.tap(find.byKey(const Key('update-backup-first')));
      await t.pumpAndSettle();
      // 앱 밖(공용 폴더)에 진짜 백업 파일
      expect(shared.saved, hasLength(1));
      expect(Maintenance.isValidBackup(shared.saved.single), isTrue);
      expect(p.isWithin(s.env.baseDir, shared.saved.single), isFalse);
      expect(find.byKey(const Key('backup-done')), findsOneWidget);
      await t.tap(find.text(S.ok));
      await t.pumpAndSettle();
      // 안내가 다시 열리고 백업했다는 표시
      expect(find.byKey(const Key('update-dialog')), findsOneWidget);
      expect(find.byKey(const Key('update-backup-saved')), findsOneWidget);
      await t.tap(find.byKey(const Key('update-install')));
      await t.pumpAndSettle();
      // 브라우저로 안드로이드 설치 파일 주소만 연다. 앱은 내려받지도, 설치하지도 않는다.
      expect(opened.map((u) => u.toString()), ['https://x/a.apk']);
      expect(calls.where((c) => c.contains('x/')), isEmpty);
      expect(s.user!.lastUpdateBackup, isNull);
      expect(Directory(p.join(s.env.documentsDir, '업데이트-백업')).existsSync(), isFalse);
      expect(Directory(p.join(s.env.documentsDir, 'updates')).existsSync(), isFalse);
      // 임시로 만든 백업은 앱 안에 남기지 않음
      final tmp = Directory(p.join(s.env.baseDir, 'tmp'));
      expect(tmp.existsSync() ? tmp.listSync() : const [], isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('경고 창을 그냥 닫으면 받지 않고 안내로 돌아감', (t) async {
      final (_, _, opened, _) = await open(t);
      await t.tap(find.byKey(const Key('update-install')));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(5, 5)); // 바깥을 눌러 닫기
      await t.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.byKey(const Key('update-dialog')), findsOneWidget);
      // "이미 백업했어요" 를 고르면 받기
      await t.tap(find.byKey(const Key('update-install')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('update-skip-backup')));
      await t.pumpAndSettle();
      expect(opened.map((u) => u.toString()), ['https://x/a.apk']);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('맥·리눅스: 다운로드 페이지 (자료 유지 안내)', () {
    for (final os in ['macos', 'linux']) {
      testWidgets('$os: 직접 바꾸는 안내 + 다운로드 페이지 열기', (t) async {
        final opened = <Uri>[];
        final calls = <String>[];
        final env = phoneEnv(
          base: copyFixture(),
          osName: os,
          client: fakeGithub(releaseJson('v1.2.1'), calls: calls),
          opened: opened,
        );
        final s = AppState(env);
        await s.login(env.accounts.verify(1, '1234')!);
        s.user!.settings.reduceMotion = true;
        await t.pumpWidget(ChannelBiseoApp(state: s));
        await t.pumpAndSettle();
        await t.tap(find.byIcon(Icons.settings).last);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('update-check')));
        await t.pumpAndSettle();
        expect(find.text(os == 'macos' ? S.updMacSteps : S.updLinuxSteps), findsOneWidget);
        expect(find.byKey(const Key('update-backup')), findsNothing);
        await t.tap(find.widgetWithText(FilledButton, S.updOpenPage));
        await t.pumpAndSettle();
        expect(opened.map((u) => u.toString()), ['https://github.com/kwanhark-cmd/-/releases/tag/v1.2.1']);
        expect(calls.where((c) => c.contains('x/')), isEmpty);
        await t.pumpWidget(const SizedBox());
      });
    }
  });

  group('안드로이드 백업은 앱 밖에만', () {
    test('저장할 곳을 고르지 않으면 백업이 없음 (앱 안에 몰래 저장하지 않음)', () async {
      final shared = FakeSharedFolder()..cancel = true;
      final env = phoneEnv(base: copyFixture(), shared: shared);
      final s = AppState(env);
      await s.login(env.accounts.verify(1, '1234')!);
      final u = s.user!;
      expect(await saveBackup(u), isNull);
      expect(u.lastSavedBackup, isNull);
      expect(filesIn(env.documentsDir), isEmpty);
      final tmp = Directory(p.join(env.baseDir, 'tmp'));
      expect(tmp.existsSync() ? tmp.listSync() : const [], isEmpty);
    });

    testWidgets('설정 → 백업 만들기: 취소하면 "저장하지 않았어요"', (t) async {
      final shared = FakeSharedFolder()..cancel = true;
      final env = phoneEnv(base: copyFixture(), shared: shared);
      final s = AppState(env);
      await s.login(env.accounts.verify(1, '1234')!);
      s.user!.settings.reduceMotion = true;
      await t.pumpWidget(ChannelBiseoApp(state: s));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.settings).last);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('backup-make')),
        300,
        scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
      );
      await t.ensureVisible(find.byKey(const Key('backup-make')));
      await t.pumpAndSettle();
      expect(find.text(S.backupOutsideHint), findsOneWidget);
      await t.tap(find.byKey(const Key('backup-make')));
      await t.pumpAndSettle();
      expect(find.text(S.backupNotSaved), findsOneWidget);
      expect(find.byKey(const Key('backup-done')), findsNothing);
      expect(filesIn(env.documentsDir), isEmpty);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('백업 → 앱 삭제 → 새로 설치 → 복원', () {
    testWidgets('새 앱 첫 실행 안내에서 "백업에서 복원" → 채널·설정 그대로, 연결 열쇠는 다시 넣기', (t) async {
      // 1) 예전 앱: 자료가 있는 상태에서 백업을 앱 밖에 저장
      final shared = FakeSharedFolder();
      final oldEnv = phoneEnv(base: copyFixture(), shared: shared);
      final old = AppState(oldEnv);
      await old.login(oldEnv.accounts.verify(1, '1234')!);
      final before = old.user!;
      final channels = before.youtube.channels().length;
      expect(channels, 3);
      final backup = await saveBackup(before);
      expect(backup, isNotNull);
      old.logout();

      // 2) 예전 앱 삭제: 앱 자료 폴더와 보안 저장소가 모두 사라짐. 남는 것은 공용 폴더의 백업 파일뿐.
      Directory(oldEnv.baseDir).deleteSync(recursive: true);
      expect(File(backup!).existsSync(), isTrue);

      // 3) 새 앱 설치: 빈 자료 폴더, 빈 보안 저장소 → 사용자 새로 만들기 → 첫 실행 안내
      final picked = <List<String>>[];
      final freshBase = Directory.systemTemp.createTempSync('cb_fresh_install').path;
      final env = phoneEnv(base: freshBase, shared: FakeSharedFolder(), pick: () => backup, pickedExt: picked);
      final s = AppState(env);
      await s.login(env.accounts.create('김사장', '5678'));
      s.user!.settings.reduceMotion = true;
      await t.pumpWidget(ChannelBiseoApp(state: s));
      await t.pumpAndSettle();
      expect(find.byType(OnboardingWizard), findsOneWidget);

      // 4) 첫 실행 안내의 "백업에서 복원"
      await t.ensureVisible(find.byKey(const Key('wizard-restore')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('wizard-restore')));
      await t.pumpAndSettle();
      // 안드로이드 파일 고르기 창은 모든 파일을 보여 줌 (.sqlite 를 모를 수 있어서), 고른 뒤 확인
      expect(picked.single, isEmpty);
      await t.tap(find.widgetWithText(FilledButton, S.settingsRestore));
      await t.pumpAndSettle();

      // 5) 자료가 돌아오고 홈 화면
      expect(find.byType(OnboardingWizard), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
      final u = s.user!;
      expect(u.youtube.channels().length, channels);
      expect(u.settings.onboardingDone, isTrue);
      expect(u.settings.textScale, 1.5);
      // 연결 열쇠는 앱 삭제와 함께 지워져서 다시 넣어야 함
      expect(u.ai.hasKey, isFalse);
      final real = sqlite3.open(env.accounts.userDbPath(u.user.id), mode: OpenMode.readOnly);
      try {
        final statuses = real.select('SELECT status FROM accounts WHERE mock = 0').map((r) => r['status']).toSet();
        expect(statuses.difference({'revoked'}), isEmpty);
      } finally {
        real.close();
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('이 앱의 백업이 아닌 파일은 거절', (t) async {
      final bad = File(p.join(Directory.systemTemp.createTempSync('cb_bad').path, 'photo.jpg'))..writeAsStringSync('x');
      final env = phoneEnv(
        base: Directory.systemTemp.createTempSync('cb_fresh').path,
        shared: FakeSharedFolder(),
        pick: () => bad.path,
      );
      final s = AppState(env);
      await s.login(env.accounts.create('새사람', '1234'));
      s.user!.settings.reduceMotion = true;
      await t.pumpWidget(ChannelBiseoApp(state: s));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('wizard-restore')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('wizard-restore')));
      await t.pumpAndSettle();
      expect(find.text(S.settingsRestoreBad), findsOneWidget);
      expect(find.byType(OnboardingWizard), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('서명 키 없이 빌드·공개 (주인 결정)', () {
    String read(String f) => File(f).readAsStringSync();
    const workflow = '../.github/workflows/build.yml';

    test('빌드 설정 어디에도 서명 키·비밀 값이 없음', () {
      for (final f in [workflow, 'android/app/build.gradle.kts']) {
        final s = read(f);
        expect(s, isNot(contains('ANDROID_KEYSTORE')), reason: f);
        expect(s, isNot(contains('ANDROID_KEY_')), reason: f);
        expect(s, isNot(contains('secrets.')), reason: f);
      }
      // 키를 넣으라는 경고도 없음
      expect(read(workflow), isNot(contains('::warning::')));
    });

    test('안드로이드 앱은 설치 화면을 열 권한을 쓰지 않고, 앱 안 설치는 윈도우만', () {
      expect(read('android/app/src/main/AndroidManifest.xml'), isNot(contains('REQUEST_INSTALL_PACKAGES')));
      expect(
        read('lib/main.dart'),
        contains('installUpdate: Platform.isWindows ? UpdateInstaller(log).install : null'),
      );
    });

    test('안드로이드 설치 파일도 Releases 에 공개', () {
      expect(read(workflow), contains('channel-biseo-android.apk'));
    });

    test('공개 안내 글은 맨 위가 안드로이드 순서 (백업 먼저)', () {
      final s = read(workflow);
      final top = s.indexOf('안드로이드 새 버전으로 바꾸는 순서');
      final changes = s.indexOf('awk -v v=');
      expect(top, greaterThan(0));
      expect(top, lessThan(changes), reason: '이미 설치된 앱의 업데이트 창은 안내 글의 맨 위를 보여 줌');
      final android = s.substring(top, changes);
      expect(android.indexOf('백업 만들기'), lessThan(android.indexOf('예전 앱을 지워요')));
      expect(s, isNot(contains('덮어쓰기, 설정은 유지됨')));
    });

    test('안내 문서에 키 넣기 안내가 없고, 안드로이드는 지우기 전에 백업', () {
      for (final f in ['../README.md', '../BLOCKERS.md', '../PROGRESS.md', 'CHANGELOG.md']) {
        final s = read(f);
        expect(s, isNot(contains('ANDROID_KEYSTORE')), reason: f);
        expect(s, isNot(contains('안드로이드 서명 키" 대로')), reason: f);
        expect(s, isNot(contains('새 버전 설치 = 덮어쓰기')), reason: f);
      }
      final readme = read('../README.md');
      expect(readme, contains('https://github.com/kwanhark-cmd/-/releases'));
      final android = readme.substring(readme.indexOf('**안드로이드 (꼭 이 순서대로)**'));
      expect(android.indexOf('백업 만들기'), lessThan(android.indexOf('예전 앱을 지워요')));
    });

    test('변경 내역 맨 위 버전 = 앱 버전 (새 버전 공개 때 안내 글로 들어감)', () {
      final ver = RegExp(r'^version: (\S+)\+', multiLine: true).firstMatch(read('pubspec.yaml'))!.group(1);
      final first = RegExp(r'^## (\S+)', multiLine: true).firstMatch(read('CHANGELOG.md'))!.group(1);
      expect(first, ver);
    });
  });
}
