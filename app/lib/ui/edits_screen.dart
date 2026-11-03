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
                Text('${S.editBefore}: ${p.video.title}', style: TextStyle(color: context.tokens.textSoft)),
                Text('${S.editAfter}: ${p.after.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
    if (r.applied > 0) {
      celebrate(context, msg);
    } else {
      toast(context, msg);
    }
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
      appBar: pageBar(context, S.editsTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.pagePad,
            AppTokens.gapS,
            AppTokens.pagePad,
            AppTokens.bottomSpace,
          ),
          children: [
            TipBanner(
              text: S.editsTip,
              seen: u.settings.tipSeen('edits'),
              onSeen: () => u.settings.markTipSeen('edits'),
            ),
            SectionCard(
              title: S.dailyReportTitle,
              icon3d: 'undo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Mascot(todayApplied > 0 ? MascotMood.done : MascotMood.hello, size: 64),
                      const SizedBox(width: AppTokens.gapM),
                      Expanded(child: Text(u.edits.dailySummary(today), key: const Key('daily-summary'))),
                    ],
                  ),
                  const SizedBox(height: AppTokens.gapM),
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
            if (list.isEmpty) const EmptyState(icon: 'undo', message: S.editsEmptyHow),
            for (var i = 0; i < list.length; i++) Appear(index: i, child: _tile(list[i])),
          ],
        ),
      ),
    );
  }

  Widget _tile(EditRecord e) {
    final t = context.tokens;
    final (Status? st, String label) = switch (e.status) {
      EditStatus.applied => (Status.done, S.editStatusApplied),
      EditStatus.reverted => (null, S.editStatusReverted),
      EditStatus.failed => (Status.problem, S.editStatusFailed),
    };
    return StripeCard(
      status: st,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppTokens.gapS,
            runSpacing: AppTokens.gapS,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (st == null) InfoChip(Icons.undo, label) else StatusBadge(st, label),
              InfoChip(Icons.calendar_today, e.day),
              InfoChip(Icons.visibility, S.editViews(e.viewsBefore, e.viewsAfter)),
            ],
          ),
          const SizedBox(height: AppTokens.gapS),
          Text('${S.editBefore}: ${e.before.title}', style: TextStyle(color: t.textSoft)),
          Row(
            children: [
              Icon(Icons.arrow_downward, size: 18, color: t.primary),
              const SizedBox(width: AppTokens.gapXs),
              Expanded(
                child: Text('${S.editAfter}: ${e.after.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          if (e.status == EditStatus.failed && e.reason.isNotEmpty) Text(e.reason),
          if (e.status == EditStatus.applied) ...[
            const SizedBox(height: AppTokens.gapS),
            BigButton(
              key: Key('revert-${e.id}'),
              label: S.editRevert,
              icon: Icons.undo,
              onPressed: () => busy.run(() => _revert(e)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _revert(EditRecord e, {bool force = false}) async {
    final r = await u.edits.revert(e.id, force: force);
    if (!mounted) return;
    switch (r.outcome) {
      case RevertOutcome.reverted:
      case RevertOutcome.alreadyReverted:
        celebrate(context, S.editReverted);
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
    if (!await confirmDanger(context, S.editsRevertAllAsk, yes: S.editRevertAll)) return;
    final r = await u.edits.revertDay(day);
    if (!mounted) return;
    toast(context, S.edits5(r.reverted, r.conflicts > 0 ? ' 유튜브에서 직접 바뀐 ${r.conflicts}개는 하나씩 확인해 주세요.' : ''));
    setState(() {});
  }
}
