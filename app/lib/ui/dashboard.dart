import 'package:flutter/material.dart';

import '../app/services.dart';
import '../core/db.dart';
import '../core/strings.dart';
import 'common.dart';
import 'edits_screen.dart';
import 'home_shell.dart';

/// 현황: 남은 한도, AI 비용, 오늘 수정, 확인 대기, 브리핑.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user, required this.shell});
  final UserContext user;
  final HomeShellState shell;

  /// 2~4단계에서 현황 카드를 더한다.
  static final List<Widget Function(UserContext u, HomeShellState shell)> extraCards = [];

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final busy = Busy();
  UserContext get u => widget.user;

  Future<void> _speak(String text) async {
    if (!u.settings.ttsEnabled) return;
    await u.env.speaker.setRate(u.settings.ttsRate);
    await u.env.speaker.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final today = dayKey(u.env.now());
    final quotaLeft = u.quota.remaining;
    final quotaLimit = u.settings.quotaDailyLimit;
    final cost = u.ai.monthCostUsd;
    final limit = u.settings.monthlyCostLimitUsd;
    final edits = u.editLog.countOn(today);
    final s = u.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat(
              S.homeQuota,
              '${S.num(quotaLeft)} / ${S.num(quotaLimit)}',
              Icons.speed,
              quotaLimit == 0 ? 0 : quotaLeft / quotaLimit,
            ),
            _stat(
              S.homeCost,
              '\$${cost.toStringAsFixed(2)} / \$${limit.toStringAsFixed(0)}',
              Icons.payments,
              limit == 0 ? 1 : (1 - cost / limit).clamp(0, 1).toDouble(),
            ),
            _stat(S.homeTodayEdits, '$edits개', Icons.edit_note, null),
            _stat(S.navChannels, '${u.youtube.channels().length}개', Icons.video_library, null),
          ],
        ),
        const SizedBox(height: 8),
        Text(s.runnerEnabled ? S.homeRunnerOn(s.runnerFromHour, s.runnerToHour) : S.homeRunnerOff),
        for (final card in DashboardScreen.extraCards) card(u, widget.shell),
        SectionCard(
          title: S.briefingTitle,
          icon: Icons.wb_sunny,
          child: ButtonWrap(
            children: [
              BigButton(
                key: const Key('briefing'),
                label: S.homeBriefing,
                icon: Icons.record_voice_over,
                onPressed: () => busy.run(() async {
                  final b = u.briefing.compose();
                  u.briefing.markDone();
                  await _showText(S.briefingTitle, b.spoken);
                }),
              ),
              BigButton(
                label: S.homeVoiceSummary,
                icon: Icons.volume_up,
                primary: false,
                onPressed: () => busy.run(() async {
                  final t = u.voice.channelSummary();
                  await _showText(S.homeVoiceSummary, t);
                }),
              ),
            ],
          ),
        ),
        SectionCard(
          title: S.dailyReportTitle,
          icon: Icons.summarize,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.edits.dailySummary(today)),
              const SizedBox(height: 12),
              ButtonWrap(
                children: [
                  BigButton(
                    key: const Key('open-edits'),
                    label: S.homeDailyReport,
                    icon: Icons.list,
                    primary: false,
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EditsScreen(user: u)));
                      if (mounted) setState(() {});
                    },
                  ),
                  BigButton(
                    key: const Key('run-edits'),
                    label: S.homeRunEdits,
                    icon: Icons.auto_fix_high,
                    onPressed: () async {
                      await runEditsFlow(context, u);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showText(String title, String text) async {
    final speak = _speak(text);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(text, key: const Key('spoken-text'), style: const TextStyle(fontSize: 18)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              u.env.speaker.stop();
              Navigator.pop(c);
            },
            child: const Text(S.close),
          ),
        ],
      ),
    );
    await speak;
  }

  Widget _stat(String label, String value, IconData icon, double? fraction) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 360),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Flexible(child: Text(label)),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              if (fraction != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: fraction, minHeight: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
