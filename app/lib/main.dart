import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app/app.dart';
import 'app/auto_run.dart';
import 'app/services.dart';
import 'core/logger.dart';
import 'core/secret_store.dart';
import 'features/runner/notifier.dart';
import 'features/runner/os_schedule.dart';
import 'features/update/installer.dart';
import 'features/voice/voice_io.dart';
import 'stages.dart';
import 'ui/common.dart';

/// 안드로이드 앱 꾸미기 (MainActivity.kt)
const _look = MethodChannel('channel_biseo/look');

Future<void> main(List<String> args) async {
  AppLogger? logger;
  // 어떤 오류가 나도 앱이 죽지 않게 모두 붙잡아 기록한다.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final support = await getApplicationSupportDirectory();
    final docs = await _documentsDir(support);
    logger = AppLogger(file: File(p.join(support.path, 'logs', 'app.log')));
    final log = logger!;
    FlutterError.onError = (d) {
      log.error('화면 오류', d.exception, d.stack);
      if (kDebugMode) FlutterError.presentError(d);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      log.error('처리되지 않은 오류', e, st);
      return true;
    };
    ErrorWidget.builder = friendlyErrorWidget;

    final info = await PackageInfo.fromPlatform();
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final env = AppEnv(
      baseDir: support.path,
      documentsDir: docs,
      secrets: OsSecretStore(),
      httpClient: http.Client(),
      logger: log,
      speech: DeviceSpeechInput(log),
      speaker: DeviceSpeaker(log),
      notifier: DeviceNotifier(log),
      isDesktop: isDesktop,
      platformName: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      appVersion: '${info.version}+${info.buildNumber}',
      launchUrl: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
      pickFile: (ext) async {
        final f = await FilePicker.pickFile(
          type: ext.isEmpty ? FileType.any : FileType.custom,
          allowedExtensions: ext.isEmpty ? null : ext,
        );
        return f?.path;
      },
      pickDirectory: () => FilePicker.getDirectoryPath(),
      // 안드로이드: 앱을 지우면 앱 안의 파일도 지워지므로, 백업은 "다른 이름으로 저장" 창으로 앱 밖에 둔다.
      saveFile: Platform.isAndroid
          ? (name, bytes) async => _shownPath(
              await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: 'application/octet-stream'),
            )
          : null,
      // 앱 안에서 바로 설치는 윈도우만 (설치 프로그램이 같은 자리에 덮어씀, 자료 유지).
      // 안드로이드는 백업 → 예전 앱 삭제 → 새 파일 설치 → 복원이라 다운로드 페이지를 연다.
      // 맥·리눅스도 직접 받아서 바꾸는 방식 (다운로드 페이지).
      installUpdate: Platform.isWindows ? UpdateInstaller(log).install : null,
      osName: Platform.operatingSystem,
      osScheduler: isDesktop
          ? OsScheduler(
              os: Platform.operatingSystem,
              exePath: Platform.resolvedExecutable,
              homeDir: Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? support.path,
              tempDir: Directory.systemTemp.path,
              run: (exe, a) => Process.run(exe, a),
              logger: log,
            )
          : null,
      setLauncherIcon: Platform.isAndroid ? (id) => _look.invokeMethod<void>('setLauncherIcon', {'id': id}) : null,
      pinShortcut: Platform.isAndroid
          ? (label, png) async => await _look.invokeMethod<bool>('pinShortcut', {'label': label, 'png': png}) ?? false
          : null,
    );
    log.info('앱 시작 ${env.appVersion} ${env.platformName}');
    registerStages();
    // 운영체제 예약으로 켜졌으면: 자동 작업만 하고 닫힘
    final autoUser = isDesktop ? OsScheduler.autoRunUser(args, Platform.environment) : null;
    if (autoUser != null) {
      log.info('예약 실행 시작 (u$autoUser)');
      runApp(const AutoRunWindow());
      await runScheduled(env, autoUser);
      exit(0);
    }
    final state = AppState(env);
    await state.tryAutoLogin();
    runApp(ChannelBiseoApp(state: state));
  }, (e, st) => logger?.error('앱 오류', e, st));
}

/// 저장한 곳을 사람이 읽을 수 있게 (취소하면 null)
String? _shownPath(Uri? saved) {
  if (saved == null) return null;
  try {
    return Uri.decodeFull(saved.path);
  } catch (_) {
    return saved.path;
  }
}

Future<String> _documentsDir(Directory fallback) async {
  try {
    final d = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(d.path, '채널관리비서'));
    dir.createSync(recursive: true);
    return dir.path;
  } catch (_) {
    return fallback.path;
  }
}
