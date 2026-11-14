import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/failure.dart';
import '../../core/logger.dart';

/// 프로그램 실행 (테스트에서는 가짜).
typedef RunCommand = Future<ProcessResult> Function(String exe, List<String> args);

/// 앱이 꺼져 있어도 자동 작업: 운영체제 예약 기능에 "매일 정한 시각에 앱을 --auto-run 으로 실행" 을 등록한다.
/// - 윈도우: 작업 스케줄러 (schtasks)
/// - 맥: 사용자 LaunchAgent (~/Library/LaunchAgents)
/// - 리눅스: 사용자 crontab
/// 사용자가 설정에서 켤 때만 등록하고, 끄면 지운다. 관리자 권한은 쓰지 않는다 (내 계정에만 등록).
/// 실행되면 앱은 자동 작업만 하고 스스로 닫힌다 (자동 작업 실행기 켜짐·시간대·하루 한 번 규칙은 그대로).
class OsScheduler {
  OsScheduler({
    required this.os,
    required this.exePath,
    required this.homeDir,
    required this.tempDir,
    required this.run,
    required this.logger,
  });

  /// 'windows' | 'macos' | 'linux' (그 밖은 지원 안 함)
  final String os;
  final String exePath;
  final String homeDir;
  final String tempDir;
  final RunCommand run;
  final AppLogger logger;

  static const argPrefix = '--auto-run=';
  static const envName = 'CHANNEL_BISEO_AUTORUN';
  static const cronTag = '# channel-biseo-autorun-';

  bool get supported => const ['windows', 'macos', 'linux'].contains(os);

  /// 사용자별로 따로 등록 (한 컴퓨터를 여러 사람이 쓸 수 있음)
  String taskName(int userId) => 'ChannelBiseo-AutoRun-u$userId';
  String plistLabel(int userId) => 'com.channelbiseo.autorun.u$userId';
  String plistPath(int userId) => p.join(homeDir, 'Library', 'LaunchAgents', '${plistLabel(userId)}.plist');

  /// 실행 인자에서 자동 실행할 사용자 번호를 찾는다 (없으면 null).
  static int? autoRunUser(List<String> args, Map<String, String> env) {
    for (final a in args) {
      if (a.startsWith(argPrefix)) return int.tryParse(a.substring(argPrefix.length));
    }
    return int.tryParse(env[envName] ?? '');
  }

  String _hhmm(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Future<void> _ok(Future<ProcessResult> r, String step) async {
    final res = await r;
    if (res.exitCode != 0) {
      logger.error('운영체제 예약 실패 [$step] 코드 ${res.exitCode}: ${res.stderr}');
      throw AppFailure(FailureKind.unknown, 'os schedule $step');
    }
  }

  /// 매일 [hour]:[minute] 에 실행하도록 등록 (이미 있으면 바꿈).
  Future<void> enable(int userId, int hour, int minute) async {
    if (!supported) throw AppFailure(FailureKind.notFound, 'os schedule on $os');
    switch (os) {
      case 'windows':
        await _ok(
          run('schtasks', [
            '/Create',
            '/F',
            '/SC',
            'DAILY',
            '/TN',
            taskName(userId),
            '/TR',
            '"$exePath" $argPrefix$userId',
            '/ST',
            _hhmm(hour, minute),
          ]),
          '작업 스케줄러 등록',
        );
      case 'macos':
        final f = File(plistPath(userId));
        f.parent.createSync(recursive: true);
        f.writeAsStringSync(macPlist(userId, hour, minute));
        // 이미 등록돼 있으면 내렸다가 다시 올림 (실패해도 괜찮음)
        await run('launchctl', ['unload', f.path]);
        await _ok(run('launchctl', ['load', '-w', f.path]), 'LaunchAgent 등록');
      case 'linux':
        final current = await _crontab();
        await _writeCrontab(cronWith(current, userId, hour, minute));
    }
    logger.info('운영체제 예약 등록: 매일 ${_hhmm(hour, minute)}');
  }

  Future<void> disable(int userId) async {
    if (!supported) return;
    switch (os) {
      case 'windows':
        final r = await run('schtasks', ['/Delete', '/F', '/TN', taskName(userId)]);
        if (r.exitCode != 0) logger.warn('운영체제 예약 지우기: 이미 없음');
      case 'macos':
        final f = File(plistPath(userId));
        if (f.existsSync()) {
          await run('launchctl', ['unload', '-w', f.path]);
          f.deleteSync();
        }
      case 'linux':
        final current = await _crontab();
        await _writeCrontab(cronWithout(current, userId));
    }
    logger.info('운영체제 예약 지움');
  }

  /// 지금 등록돼 있는지 운영체제에 물어본다.
  Future<bool> isEnabled(int userId) async {
    if (!supported) return false;
    switch (os) {
      case 'windows':
        return (await run('schtasks', ['/Query', '/TN', taskName(userId)])).exitCode == 0;
      case 'macos':
        return File(plistPath(userId)).existsSync();
      default:
        return (await _crontab()).contains('$cronTag$userId');
    }
  }

  String macPlist(int userId, int hour, int minute) {
    String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${plistLabel(userId)}</string>
  <key>ProgramArguments</key>
  <array><string>${esc(exePath)}</string><string>$argPrefix$userId</string></array>
  <key>EnvironmentVariables</key>
  <dict><key>$envName</key><string>$userId</string></dict>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$minute</integer></dict>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
''';
  }

  /// crontab 글에서 이 사용자의 줄을 빼고 새 줄을 넣는다. 다른 줄은 그대로.
  String cronWith(String current, int userId, int hour, int minute) {
    final kept = cronWithout(current, userId).trimRight();
    final exe = exePath.replaceAll("'", "'\\''");
    final line = "$minute $hour * * * '$exe' $argPrefix$userId $cronTag$userId";
    return '${kept.isEmpty ? '' : '$kept\n'}$line\n';
  }

  String cronWithout(String current, int userId) {
    final lines = current.split('\n').where((l) => !l.contains('$cronTag$userId')).toList();
    final text = lines.join('\n').trimRight();
    return text.isEmpty ? '' : '$text\n';
  }

  Future<String> _crontab() async {
    final r = await run('crontab', ['-l']);
    return r.exitCode == 0 ? r.stdout.toString() : ''; // 아직 crontab 이 없으면 빈 글
  }

  Future<void> _writeCrontab(String text) async {
    final f = File(p.join(tempDir, 'channel-biseo-crontab.txt'))..writeAsStringSync(text);
    try {
      await _ok(run('crontab', [f.path]), 'crontab 등록');
    } finally {
      if (f.existsSync()) f.deleteSync();
    }
  }
}
