import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/services.dart';
import '../core/strings.dart';
import '../features/ai/ai_service.dart';
import '../features/settings/maintenance.dart';
import '../features/youtube/youtube_service.dart';
import 'common.dart';
import 'memos_screen.dart';
import 'onboarding.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state, required this.user});
  final AppState state;
  final UserContext user;

  /// 2~4단계 설정 묶음 (도구 연결, 제작 한도 등).
  static final List<Widget Function(BuildContext, UserContext, VoidCallback refresh)> extraSections = [];

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserContext get u => widget.user;
  final busy = Busy();
  final aiKey = TextEditingController();
  late final googleId = TextEditingController(text: u.settings.googleClientId);
  final googleSecret = TextEditingController();

  @override
  void dispose() {
    aiKey.dispose();
    googleId.dispose();
    googleSecret.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = u.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        SectionCard(
          title: S.settingsFontSize,
          icon: Icons.format_size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FontScalePicker(state: widget.state),
              const SizedBox(height: 8),
              const Text('${S.settingsLanguage}: ${S.wizardLanguageKo}'),
            ],
          ),
        ),
        SectionCard(
          title: S.settingsVoice,
          icon: Icons.record_voice_over,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(S.settingsVoice),
                value: s.ttsEnabled,
                onChanged: (v) => setState(() => s.ttsEnabled = v),
              ),
              ListTile(
                title: const Text(S.settingsVoiceRate),
                subtitle: Slider(
                  value: s.ttsRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: s.ttsRate.toStringAsFixed(1),
                  onChanged: (v) => setState(() => s.ttsRate = v),
                  onChangeEnd: (v) => u.env.speaker.setRate(v),
                ),
              ),
              SwitchListTile(
                title: const Text(S.settingsBriefingOn),
                value: s.briefingEnabled,
                onChanged: (v) => setState(() => s.briefingEnabled = v),
              ),
              ListTile(
                title: const Text(S.settingsBriefingTime),
                subtitle: Text('${s.briefingHour}시 ${s.briefingMinute.toString().padLeft(2, '0')}분'),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: s.briefingHour, minute: s.briefingMinute),
                  );
                  if (t != null) {
                    setState(() {
                      s.briefingHour = t.hour;
                      s.briefingMinute = t.minute;
                    });
                  }
                },
              ),
              ListTile(
                title: const Text(S.voiceMemoTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MemosScreen(user: u))),
              ),
            ],
          ),
        ),
        _aiSection(),
        _googleSection(),
        SectionCard(
          title: '유튜브',
          icon: Icons.smart_display,
          child: Column(
            children: [
              NumberField(
                label: S.settingsQuotaLimit,
                value: s.quotaDailyLimit,
                onChanged: (v) => s.quotaDailyLimit = v.toInt(),
              ),
              const SizedBox(height: 12),
              NumberField(
                label: '${S.settingsEditsPerDay} (${s.isFirstMonth(u.env.now()) ? S.editsFirstMonth : '0이면 수정 안 함'})',
                value: s.editsPerChannelPerDay,
                onChanged: (v) => s.editsPerChannelPerDay = v.toInt(),
              ),
            ],
          ),
        ),
        _runnerSection(),
        for (final sec in SettingsScreen.extraSections) sec(context, u, _refresh),
        SectionCard(
          title: '자료 관리',
          icon: Icons.storage,
          child: ButtonWrap(
            children: [
              BigButton(
                label: S.settingsBackup,
                icon: Icons.save_alt,
                primary: false,
                onPressed: () => busy.run(_backup),
              ),
              BigButton(
                label: S.settingsRestore,
                icon: Icons.restore,
                primary: false,
                onPressed: () => busy.run(_restore),
              ),
              BigButton(
                key: const Key('report'),
                label: S.settingsReport,
                icon: Icons.bug_report,
                primary: false,
                onPressed: () => busy.run(_report),
              ),
              BigButton(
                key: const Key('reset'),
                label: S.settingsReset,
                icon: Icons.delete_forever,
                danger: true,
                onPressed: () => busy.run(_reset),
              ),
            ],
          ),
        ),
        SectionCard(
          title: S.settingsVersion,
          icon: Icons.info_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${S.appName} ${u.env.appVersion}', key: const Key('version')),
              const SizedBox(height: 8),
              BigButton(label: S.settingsChangelog, icon: Icons.history, primary: false, onPressed: _changelog),
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.phone_iphone),
                title: Text(S.settingsIphone),
                subtitle: Text(S.settingsIphoneHint),
                enabled: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ButtonWrap(
          children: [BigButton(label: S.logout, icon: Icons.logout, primary: false, onPressed: widget.state.logout)],
        ),
      ],
    );
  }

  Widget _aiSection() {
    final s = u.settings;
    return SectionCard(
      title: S.settingsAi,
      icon: Icons.psychology,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (u.ai.isPracticeMode) const Text('지금은 ${S.practiceMode}예요. 아래에 키를 넣으면 실제 AI가 켜져요.'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: s.aiProvider,
            decoration: const InputDecoration(labelText: S.settingsAiProvider),
            items: const [
              DropdownMenuItem(value: 'claude', child: Text('Claude (Anthropic)')),
              DropdownMenuItem(value: 'other', enabled: false, child: Text('다른 제공자 (준비 중)')),
            ],
            onChanged: (v) => setState(() => s.aiProvider = v ?? 'claude'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: aiModelChoices.containsKey(s.aiModel) ? s.aiModel : 'claude-opus-5-5',
            isExpanded: true,
            decoration: const InputDecoration(labelText: S.settingsAiModel),
            items: [for (final e in aiModelChoices.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => s.aiModel = v ?? 'claude-opus-5-5'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('ai-key'),
            controller: aiKey,
            obscureText: true,
            decoration: InputDecoration(
              labelText: S.settingsAiKey,
              helperText: u.ai.hasKey ? '저장된 키가 있어요 (보안을 위해 내용은 보여 주지 않아요)' : '키가 없어요',
            ),
          ),
          const SizedBox(height: 8),
          ButtonWrap(
            children: [
              BigButton(
                label: S.save,
                onPressed: () async {
                  await u.ai.setKey(aiKey.text);
                  aiKey.clear();
                  if (mounted) {
                    toast(context, S.settingsAiKeySaved);
                    setState(() {});
                  }
                },
              ),
              if (u.ai.hasKey)
                BigButton(
                  label: S.settingsAiKeyRemove,
                  primary: false,
                  onPressed: () async {
                    await u.ai.setKey('');
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          NumberField(
            label: S.settingsAiLimit,
            value: s.monthlyCostLimitUsd,
            decimal: true,
            onChanged: (v) => s.monthlyCostLimitUsd = v.toDouble(),
          ),
          const SizedBox(height: 8),
          Text('${S.settingsAiUsed}: \$${u.ai.monthCostUsd.toStringAsFixed(3)}'),
          Text(
            '예: 영상 제목 다듬기 1번 ≈ \$${u.ai.estimateCost('x' * 1500, 'x' * 1500, expectedOutput: 800).toStringAsFixed(3)}',
          ),
        ],
      ),
    );
  }

  Widget _googleSection() {
    final s = u.settings;
    return SectionCard(
      title: S.settingsGoogle,
      icon: Icons.key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(S.settingsGoogleHint),
          const SizedBox(height: 12),
          TextField(
            controller: googleId,
            decoration: const InputDecoration(labelText: S.settingsGoogleClientId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: googleSecret,
            obscureText: true,
            decoration: const InputDecoration(labelText: S.settingsGoogleClientSecret),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('구글 앱이 아직 "테스트" 상태예요'),
            subtitle: const Text('테스트 상태에서는 연결이 7일마다 만료돼요. 만료 전에 알려 드려요.'),
            value: s.googleAppInTesting,
            onChanged: (v) => setState(() => s.googleAppInTesting = v),
          ),
          BigButton(
            label: S.save,
            onPressed: () async {
              s.googleClientId = googleId.text;
              if (googleSecret.text.isNotEmpty) {
                await u.secrets.write(YouTubeService.googleSecretKey, googleSecret.text.trim());
              }
              googleSecret.clear();
              widget.state.refresh();
              if (mounted) toast(context, '저장했어요.');
            },
          ),
        ],
      ),
    );
  }

  Widget _runnerSection() {
    final s = u.settings;
    return SectionCard(
      title: S.settingsRunner,
      icon: Icons.schedule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!u.env.isDesktop) const Text(S.settingsRunnerDesktopOnly),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(S.settingsRunnerOn),
            subtitle: const Text('켜면 정한 시간대에 하루 한 번: 채널 새로 불러오기 → 영상 다듬기. 시작과 끝에 알려 드려요. 업로드·삭제·공개는 하지 않아요.'),
            value: s.runnerEnabled,
            onChanged: u.env.isDesktop ? (v) => setState(() => s.runnerEnabled = v) : null,
          ),
          _hourPicker(S.settingsRunnerFrom, s.runnerFromHour, (v) => s.runnerFromHour = v),
          const SizedBox(height: 12),
          _hourPicker(S.settingsRunnerTo, s.runnerToHour, (v) => s.runnerToHour = v),
          const SizedBox(height: 12),
          ButtonWrap(
            children: [
              if (u.env.isDesktop)
                BigButton(
                  label: '지금 한 번 실행',
                  icon: Icons.play_arrow,
                  primary: false,
                  onPressed: u.runner.running
                      ? null
                      : () => busy.run(() async {
                          final r = await u.runner.runNow();
                          if (mounted) toast(context, S.runnerDone(r.edits, r.deferred));
                        }),
                ),
              BigButton(label: '작업 기록 보기', icon: Icons.receipt_long, primary: false, onPressed: _jobLog),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hourPicker(String label, int value, void Function(int) set) => DropdownButtonFormField<int>(
    isExpanded: true,
    initialValue: value.clamp(0, 23),
    decoration: InputDecoration(labelText: label),
    items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('$h시'))],
    onChanged: (v) => setState(() => set(v ?? value)),
  );

  Future<void> _jobLog() => showDialog<void>(
    context: context,
    builder: (c) {
      final log = u.jobs.recentLog();
      return AlertDialog(
        title: const Text('작업 기록'),
        content: SizedBox(
          width: 600,
          child: log.isEmpty
              ? const Text(S.empty)
              : ListView(shrinkWrap: true, children: [for (final l in log) Text(l)]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.close))],
      );
    },
  );

  Future<String> _exportDir() async {
    final picked = await u.env.pickDirectory?.call();
    return picked ?? u.env.documentsDir;
  }

  Future<void> _backup() async {
    try {
      final path = u.maintenance.backupTo(await _exportDir());
      if (mounted) await _info(S.settingsBackupDone, path);
    } catch (e) {
      if (mounted) await showFailure(context, e, onRetry: _backup);
    }
  }

  Future<void> _restore() async {
    final path = await u.env.pickFile?.call(['sqlite']);
    if (path == null || !mounted) return;
    if (!Maintenance.isValidBackup(path)) {
      toast(context, S.settingsRestoreBad);
      return;
    }
    if (!await confirm(context, '지금 자료를 이 백업으로 바꿀까요? (지금 자료도 자동으로 따로 보관해 둬요)', yes: S.settingsRestore)) return;
    final user = u.user;
    final accounts = u.env.accounts;
    widget.state.logout();
    Maintenance.restoreFile(
      backupPath: path,
      targetDbPath: accounts.userDbPath(user.id),
      safetyDir: '${accounts.userDir(user.id)}${Platform.pathSeparator}backups',
    );
    await widget.state.login(user);
  }

  Future<void> _report() async {
    try {
      final text = u.maintenance.reportText();
      final path = u.maintenance.writeReport(await _exportDir());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text(S.settingsReport),
          content: Text('${S.settingsReportDone}\n\n$path'),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('내용 복사'),
            ),
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text(S.ok)),
          ],
        ),
      );
    } catch (e) {
      if (mounted) await showFailure(context, e, onRetry: _report);
    }
  }

  Future<void> _reset() async {
    if (!await confirm(context, S.settingsReset1, yes: S.next, danger: true)) return;
    if (!mounted || !await confirm(context, S.settingsReset2, yes: S.settingsReset, danger: true)) return;
    final user = u.user;
    final accounts = u.env.accounts;
    widget.state.logout();
    await accounts.wipeUserData(user.id, null);
    await widget.state.login(user);
  }

  Future<void> _info(String title, String body) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SelectableText(body),
      actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text(S.ok))],
    ),
  );

  Future<void> _changelog() async {
    String text;
    try {
      text = await rootBundle.loadString('CHANGELOG.md');
    } catch (_) {
      text = S.empty;
    }
    if (mounted) await _info(S.settingsChangelog, text);
  }
}
