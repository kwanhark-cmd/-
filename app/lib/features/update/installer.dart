import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/failure.dart';
import '../../core/logger.dart';

/// 내려받은 설치 파일로 실제 설치를 시작한다. 사용자가 "설치"를 눌렀을 때만 불린다.
/// 앱에서는 윈도우만 쓴다 (main.dart): 설치 프로그램을 실행하고 앱을 닫는다. 같은 자리에 덮어써서 설치된다.
/// 안드로이드는 앱 안에서 설치하지 않는다: 서명 키를 쓰지 않으므로 예전 앱을 지우고 새로 설치해야 하고,
/// 앱을 지우면 앱 안의 자료가 지워져서 "백업 → 삭제 → 설치 → 복원" 순서 안내와 다운로드 페이지로 대신한다.
/// 맥 코드는 남겨 두지만 앱에서는 쓰지 않는다 (샌드박스 안에서는 응용 프로그램 폴더의 앱을 바꿀 수 없음).
/// 어느 경우든 사용자 자료 폴더와 보안 저장소는 건드리지 않는다.
class UpdateInstaller {
  UpdateInstaller(this.logger);
  final AppLogger logger;

  Future<void> install(File file) async {
    if (Platform.isAndroid) {
      // 덮어쓰기 설치는 서명이 달라 거절되고, 예전 앱을 지우면 자료가 지워진다. 절대 여기서 설치하지 않는다.
      throw AppFailure(FailureKind.notFound, 'no in-app install on android');
    }
    if (Platform.isWindows) {
      logger.info('업데이트 설치 프로그램 실행 [윈도우]');
      await Process.start(file.path, ['/SILENT', '/SP-', '/CLOSEAPPLICATIONS'], mode: ProcessStartMode.detached);
      exit(0);
    }
    if (Platform.isMacOS) {
      await _installMac(file);
      exit(0);
    }
    throw AppFailure(FailureKind.notFound, 'no installer for ${Platform.operatingSystem}');
  }

  /// 지금 실행 중인 .app 경로 (…/채널비서.app/Contents/MacOS/실행파일)
  static String? currentMacApp() {
    final exe = Platform.resolvedExecutable;
    final app = p.dirname(p.dirname(p.dirname(exe)));
    return app.endsWith('.app') ? app : null;
  }

  Future<void> _installMac(File zip) async {
    final current = currentMacApp();
    if (current == null) throw AppFailure(FailureKind.notFound, 'app path');
    final work = Directory(p.join(p.dirname(zip.path), 'new-app'));
    if (work.existsSync()) work.deleteSync(recursive: true);
    work.createSync(recursive: true);
    final unzip = await Process.run('/usr/bin/ditto', ['-x', '-k', zip.path, work.path]);
    if (unzip.exitCode != 0) {
      logger.error('업데이트 압축 풀기 실패 [맥] ${unzip.stderr}');
      throw AppFailure(FailureKind.unknown, 'unzip');
    }
    final newApp = work.listSync().whereType<Directory>().firstWhere(
      (d) => d.path.endsWith('.app'),
      orElse: () => throw AppFailure(FailureKind.notFound, 'no .app in zip'),
    );
    // 앱이 완전히 닫힌 뒤 바꿔 끼우고 다시 연다. 실패하면 이전 앱으로 되돌린다.
    final script = File(p.join(p.dirname(zip.path), 'install.sh'));
    String q(String s) => "'${s.replaceAll("'", "'\\''")}'";
    script.writeAsStringSync('''
#!/bin/sh
while kill -0 $pid 2>/dev/null; do sleep 0.5; done
OLD=${q(current)}
NEW=${q(newApp.path)}
rm -rf "\$OLD.old"
mv "\$OLD" "\$OLD.old" || exit 1
if mv "\$NEW" "\$OLD"; then
  xattr -dr com.apple.quarantine "\$OLD" 2>/dev/null
  rm -rf "\$OLD.old"
else
  mv "\$OLD.old" "\$OLD"
fi
open "\$OLD"
''');
    logger.info('업데이트 설치 준비 [맥]');
    await Process.start('/bin/sh', [script.path], mode: ProcessStartMode.detached);
  }
}
