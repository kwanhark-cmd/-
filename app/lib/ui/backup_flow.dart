// 이 파일의 context 는 모두 alive() 로 다시 확인한 것만 쓴다 (사라진 화면이면 앱 전체 화면).
// ignore_for_file: use_build_context_synchronously
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app/app.dart';
import '../app/services.dart';
import '../core/strings.dart';
import '../features/settings/maintenance.dart';
import 'common.dart';

/// 백업 파일을 만들어 저장한다. 저장한 곳을 돌려주고, 저장할 곳을 고르지 않으면 null.
/// - 안드로이드([AppEnv.saveFile] 있음): 운영체제의 "다른 이름으로 저장" 창으로 앱 밖(다운로드 폴더 등)에 저장.
///   앱을 지우면 앱 안의 파일은 모두 지워지므로, 앱 안에 몰래 저장하지 않는다.
/// - 컴퓨터: 고른 폴더(고르지 않으면 사용자의 문서 폴더)에 저장. 앱을 지워도 남는다.
Future<String?> saveBackup(UserContext u) async {
  final env = u.env;
  final save = env.saveFile;
  if (save != null) {
    final tmp = Directory(p.join(env.baseDir, 'tmp'))..createSync(recursive: true);
    final made = u.maintenance.backupTo(tmp.path);
    try {
      final where = await save(p.basename(made), File(made).readAsBytesSync());
      if (where == null) {
        env.logger.info('백업 저장 취소');
        return null;
      }
      env.logger.info('백업을 앱 밖에 저장함');
      u.lastSavedBackup = where;
      return where;
    } finally {
      final f = File(made);
      if (f.existsSync()) f.deleteSync();
    }
  }
  final dir = await env.pickDirectory?.call() ?? env.documentsDir;
  final path = u.maintenance.backupTo(dir);
  u.lastSavedBackup = path;
  return path;
}

/// "백업 만들기" 버튼: 저장하고 결과를 알려 준다. 저장했으면 저장한 곳, 아니면 null.
Future<String?> backupFlow(BuildContext callerContext, UserContext u) async {
  try {
    final where = await saveBackup(u);
    final c = alive(callerContext);
    if (c == null) return where;
    if (where == null) {
      toast(c, S.backupNotSaved);
      return null;
    }
    await showDialog<void>(
      context: c,
      builder: (d) => AlertDialog(
        key: const Key('backup-done'),
        title: const Text(S.settingsBackupDone),
        content: SelectableText(where),
        actions: [FilledButton(onPressed: () => Navigator.pop(d), child: const Text(S.ok))],
      ),
    );
    return where;
  } catch (e) {
    final c = alive(callerContext);
    if (c != null) await showFailure(c, e, where: '백업 만들기', onRetry: () => backupFlow(c, u));
    return null;
  }
}

/// "백업에서 복원" 버튼: 백업 파일을 골라 지금 사용자의 자료를 바꾼다.
/// 지금 자료는 복원 전에 따로 보관하고, 복원한 뒤 다시 로그인해 자료를 새로 연다.
Future<void> restoreFlow(BuildContext callerContext, AppState state, UserContext u) async {
  final env = u.env;
  // 안드로이드의 파일 고르기 창은 .sqlite 를 알아보지 못할 수 있어 모든 파일을 보여 주고, 고른 뒤 확인한다.
  final path = await env.pickFile?.call(env.osName == 'android' ? const [] : const ['sqlite']);
  final c = alive(callerContext);
  if (path == null || c == null) return;
  if (!Maintenance.isValidBackup(path)) {
    toast(c, S.settingsRestoreBad);
    return;
  }
  if (!await confirm(c, S.set18, yes: S.settingsRestore)) return;
  final user = u.user;
  final accounts = env.accounts;
  state.logout();
  try {
    Maintenance.restoreFile(
      backupPath: path,
      targetDbPath: accounts.userDbPath(user.id),
      safetyDir: '${accounts.userDir(user.id)}${Platform.pathSeparator}backups',
    );
    env.logger.info('백업에서 복원함');
  } finally {
    await state.login(user);
  }
  final c2 = alive(callerContext);
  if (c2 != null) toast(c2, S.settingsRestoreDone);
}
