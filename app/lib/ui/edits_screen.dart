import 'package:flutter/material.dart';

import '../app/services.dart';
import '../core/db.dart';
import '../core/strings.dart';
import '../features/edits/edit_service.dart';
import 'common.dart';

/// "지금 수정 실행": 제안을 먼저 보여 주고, 확인하면 적용.
Future<void> runEditsFlow(BuildContext context, UserContext u) async {
  if (u.youtube.channels().isEmpty) {
    toast(context, S.channelNone);
    return;
  }
  final calls = u.youtube.channels().fold<int>(0, (s, c) => s + u.edits.remainingToday(c.channelId));
  if (!await confirmAiCost(context, u, calls: calls, output: 800)) return;
  if (!context.mounted) return;
  try {
    final proposals = await runWithProgress(context, S.editsPreviewTitle, (cancel, p) async {
      final all = <EditProposal>[];
      final chans = u.youtube.channels();
      for (var i = 0; i < chans.length; i++) {
        p(i / chans.length, S.edits1(chans[i].title));
        all.addAll(await u.edits.plan(chans[i].channelId, cancel: cancel));
      }
      return all;
    });
    if (proposals == null || !context.mounted) return;
    if (proposals.isEmpty) {
      toast(context, S.editsNone);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(S.editsPreviewTitle),
        content: SizedBox(
          width: 600,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                u.settings.isFirstMonth(u.env.now())
                    ? S.editsFirstMonth
                    : S.editsLimit(u.settings.editsPerChannelPerDay),
              ),
              const Divider(),
              for (final p in proposals) ...[
                Text('${S.editBefore}: ${p.video.title}', style: const TextStyle(color: Colors.grey)),
                Text('${S.editAfter}: ${p.after.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (p.after.tags.join() != p.video.tags.join()) Text(S.edits2(p.after.tags.join(', '))),
                if (p.after.description != p.video.description) const Text(S.edits3),
                const Divider(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
          FilledButton(
            key: const Key('apply-edits'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text(S.editsApply),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await runWithProgress(
      context,
      S.editsApply,
      (cancel, p) => u.edits.apply(proposals, cancel: cancel, progress: p),
    );
    if (r == null || !context.mounted) return;
    final msg = S.edits4(
      S.editsDone(r.applied),
      r.failed > 0 ? ' 실패 ${r.failed}개.' : '',
      r.deferred > 0 ? ' ${S.runnerQuotaDefer}' : '',
    );
    toast(context, msg);
    if (u.settings.ttsEnabled) await u.env.speaker.speak(msg);
  } catch (e) {
    if (context.mounted) await showFailure(context, e, onRetry: () => runEditsFlow(context, u));
  }
}

class EditsScreen extends StatefulWidget {
  const EditsScreen({super.key, required this.user, this.channelId});
  final UserContext user;
  final String? channelId;
  @override
  State<EditsScreen> createState() => _EditsScreenState();
}

class _EditsScreenState extends State<EditsScreen> {
  UserContext get u => widget.user;
  final busy = Busy();

  @override
  Widget build(BuildContext context) {
    final today = dayKey(u.env.now());
    final list = u.editLog.list(targetType: 'video', parentId: widget.channelId);
    final todayApplied = list.where((e) => e.day == today && e.status == EditStatus.applied).length;
    return Scaffold(
      appBar: AppBar(title: const Text(S.editsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: S.dailyReportTitle,
              icon: Icons.summarize,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.edits.dailySummary(today), key: const Key('daily-summary')),
                  const SizedBox(height: 12),
                  ButtonWrap(
                    children: [
                      BigButton(
                        label: S.homeVoiceSummary,
                        icon: Icons.volume_up,
                        primary: false,
                        onPressed: () => u.env.speaker.speak(u.edits.dailySummary(today)),
                      ),
                      if (todayApplied > 0)
                        BigButton(
                          key: const Key('revert-all'),
                          label: S.editRevertAll,
                          icon: Icons.undo,
                          danger: true,
                          onPressed: () => busy.run(() => _revertDay(today)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (list.isEmpty) const EmptyHint(S.editsNone),
            for (final e in list) _tile(e),
          ],
        ),
      ),
    );
  }

  Widget _tile(EditRecord e) {
    final status = switch (e.status) {
      EditStatus.applied => S.editStatusApplied,
      EditStatus.reverted => S.editStatusReverted,
      EditStatus.failed => S.editStatusFailed,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${e.day} · $status · ${S.editViews(e.viewsBefore, e.viewsAfter)}'),
            const SizedBox(height: 4),
            Text('${S.editBefore}: ${e.before.title}', style: const TextStyle(color: Colors.grey)),
            Text('${S.editAfter}: ${e.after.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (e.status == EditStatus.failed && e.reason.isNotEmpty) Text(e.reason),
            if (e.status == EditStatus.applied) ...[
              const SizedBox(height: 8),
              BigButton(
                key: Key('revert-${e.id}'),
                label: S.editRevert,
                icon: Icons.undo,
                primary: false,
                onPressed: () => busy.run(() => _revert(e)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _revert(EditRecord e, {bool force = false}) async {
    final r = await u.edits.revert(e.id, force: force);
    if (!mounted) return;
    switch (r.outcome) {
      case RevertOutcome.reverted:
      case RevertOutcome.alreadyReverted:
        toast(context, S.editReverted);
      case RevertOutcome.newerEditExists:
        toast(context, S.editRevertNewerFirst);
      case RevertOutcome.conflict:
        if (await confirm(context, S.editRevertConflict, yes: S.editRevertAnyway)) {
          await _revert(e, force: true);
          return;
        }
      case RevertOutcome.failed:
        await showFailure(context, r.failure ?? Exception(), onRetry: () => _revert(e, force: force));
    }
    if (mounted) setState(() {});
  }

  Future<void> _revertDay(String day) async {
    if (!await confirm(context, '${S.editRevertAll}?', yes: S.editRevert)) return;
    final r = await u.edits.revertDay(day);
    if (!mounted) return;
    toast(context, S.edits5(r.reverted, r.conflicts > 0 ? ' 유튜브에서 직접 바뀐 ${r.conflicts}개는 하나씩 확인해 주세요.' : ''));
    setState(() {});
  }
}
