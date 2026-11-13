// 이 파일의 context 는 모두 alive() 로 다시 확인한 것만 쓴다 (사라진 화면이면 앱 전체 화면).
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../app/services.dart';
import '../core/strings.dart';
import '../features/update/update_service.dart';
import 'backup_flow.dart';
import 'common.dart';

/// 설정 → "업데이트 확인". 사용자가 누를 때만 확인하고, "설치"를 눌러야만 내려받는다.
Future<void> checkUpdateFlow(BuildContext callerContext, UserContext u) async {
  final env = u.env;
  ReleaseInfo? info;
  try {
    info = await runWithProgress<ReleaseInfo?>(callerContext, S.updChecking, (_, _) => env.updates.check());
  } catch (e) {
    final c = alive(callerContext);
    if (c != null) await showFailure(c, e, where: '업데이트 확인', onRetry: () => checkUpdateFlow(c, u));
    return;
  }
  final c = alive(callerContext);
  if (c == null) return;
  if (info == null) {
    toast(c, S.updLatest(UpdateService.parse(env.appVersion).join('.')));
    return;
  }
  final release = info;
  final asset = UpdateService.assetFor(release, env.osName);
  final canInstall = asset != null && env.installUpdate != null;
  final isAndroid = env.osName == 'android';
  while (true) {
    final c1 = alive(callerContext);
    if (c1 == null) return;
    final choice = await showDialog<_Choice>(
      context: c1,
      builder: (d) => _UpdateDialog(release: release, user: u, canInstall: canInstall, isAndroid: isAndroid),
    );
    if (choice == null || choice == _Choice.later) return;
    if (choice == _Choice.backup) {
      final c = alive(callerContext);
      if (c == null) return;
      await backupFlow(c, u);
      continue; // 안내를 다시 보여 준다 (백업했다는 표시와 함께)
    }
    if (canInstall) break;
    if (isAndroid && u.lastSavedBackup == null) {
      // 예전 앱을 지우기 전에 백업이 꼭 있어야 한다. 창을 그냥 닫으면 받지 않는다.
      final c = alive(callerContext);
      if (c == null) return;
      final backupFirst = await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(
          key: const Key('update-no-backup'),
          icon: const Icon3D('warning', size: AppTokens.icon3dM),
          content: const Text(S.updAndroidNoBackup, style: TextStyle(fontSize: AppTokens.fontBody + 1)),
          actions: [
            TextButton(
              key: const Key('update-skip-backup'),
              onPressed: () => Navigator.pop(d, false),
              child: const Text(S.updAndroidBackedUpAlready),
            ),
            FilledButton(
              key: const Key('update-backup-first'),
              onPressed: () => Navigator.pop(d, true),
              child: const Text(S.settingsBackup),
            ),
          ],
        ),
      );
      if (backupFirst == null) continue;
      if (backupFirst) {
        final c3 = alive(callerContext);
        if (c3 == null) return;
        await backupFlow(c3, u);
        continue;
      }
    }
    // 앱 안에서 설치하지 않는다: 안드로이드는 설치 파일을, 그 밖에는 다운로드 페이지를 브라우저로 연다.
    final url = isAndroid && asset != null ? asset.url : release.pageUrl;
    await env.launchUrl(Uri.parse(url));
    return;
  }
  final c2 = alive(callerContext);
  if (c2 == null) return;
  try {
    final file = await runWithProgress(c2, S.updInstalling, (cancel, progress) async {
      progress(0, S.updBackingUp);
      final dir = backupAllForUpdate(
        baseDir: env.baseDir,
        documentsDir: env.documentsDir,
        fromVersion: env.appVersion.split('+').first,
        now: env.now(),
        openDbCopy: {env.accounts.userDbPath(u.user.id): u.db.copyTo, env.accounts.usersDbPath: env.accounts.db.copyTo},
      );
      env.logger.info('업데이트 전 백업 완료');
      u.lastUpdateBackup = dir;
      progress(0.01, S.updDownloading);
      return env.updates.download(
        asset,
        '${env.documentsDir}/updates',
        onProgress: (f) => progress(f, '${S.updDownloading} ${(f * 100).round()}%'),
      );
    });
    if (file == null) return;
    await env.installUpdate!(file);
    final c3 = alive(callerContext);
    if (c3 != null) toast(c3, S.updStarted);
  } catch (e) {
    final c3 = alive(callerContext);
    if (c3 != null) await showFailure(c3, e, where: '업데이트 설치', onRetry: () => checkUpdateFlow(c3, u));
  }
}

enum _Choice { later, backup, go }

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.release, required this.user, required this.canInstall, required this.isAndroid});
  final ReleaseInfo release;
  final UserContext user;
  final bool canInstall;
  final bool isAndroid;

  @override
  Widget build(BuildContext context) {
    const strong = TextStyle(fontSize: AppTokens.fontBody, fontWeight: FontWeight.w600);
    final saved = user.lastSavedBackup;
    final os = user.env.osName;
    return AlertDialog(
      key: const Key('update-dialog'),
      title: Text(S.updNew(release.version)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Mascot(MascotMood.celebrate, size: 64),
            const SizedBox(height: AppTokens.gapS),
            if (canInstall)
              const Text(S.updKeepsData, style: strong)
            else if (isAndroid) ...[
              Text(
                S.updAndroidWarn,
                key: const Key('update-android-warn'),
                style: strong.copyWith(color: context.tokens.danger),
              ),
              const SizedBox(height: AppTokens.gapS),
              const Text(
                S.updAndroidSteps,
                key: Key('update-android-steps'),
                style: TextStyle(fontSize: AppTokens.fontBody),
              ),
              if (saved != null) ...[
                const SizedBox(height: AppTokens.gapS),
                Text(S.updAndroidBackupDone(saved), key: const Key('update-backup-saved'), style: strong),
              ],
            ] else
              Text(
                os == 'macos'
                    ? S.updMacSteps
                    : os == 'linux'
                    ? S.updLinuxSteps
                    : S.updManual,
                style: strong,
              ),
            const SizedBox(height: AppTokens.gapS),
            if (release.notes.trim().isNotEmpty) Text(release.notes.trim()),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, _Choice.later), child: const Text(S.updLater)),
        if (isAndroid && !canInstall)
          OutlinedButton(
            key: const Key('update-backup'),
            onPressed: () => Navigator.pop(context, _Choice.backup),
            child: const Text(S.settingsBackup),
          ),
        FilledButton(
          key: const Key('update-install'),
          onPressed: () => Navigator.pop(context, _Choice.go),
          child: Text(
            canInstall
                ? S.updInstall
                : isAndroid
                ? S.updDownloadFile
                : S.updOpenPage,
          ),
        ),
      ],
    );
  }
}
