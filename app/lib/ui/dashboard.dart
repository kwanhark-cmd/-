import 'package:flutter/material.dart';

import '../app/services.dart';
import '../core/db.dart';
import '../core/strings.dart';
import 'common.dart';
import 'edits_screen.dart';
import 'home_shell.dart';

/// 홈 화면 "오늘 할 일" 카드에 들어갈 한 가지.
class TodayTask {
  TodayTask({
    required this.status,
    required this.icon3d,
    required this.title,
    required this.action,
    required this.onTap,
  });
  final Status status;
  final String icon3d;
  final String title;
  final String action;
  final VoidCallback onTap;
}

/// 홈: 마스코트 인사 → 오늘 할 일 → 큰 타일 → 원형 게이지 → 브리핑·수정 요약.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user, required this.shell});
  final UserContext user;
  final HomeShellState shell;

  /// 2~4단계에서 홈 카드를 더한다 (타일 아래).
  static final List<Widget Function(UserContext u, HomeShellState shell)> extraCards = [];

  /// "오늘 할 일" 후보. 앞에 있는 것이 먼저 (확인 대기가 1순위).
  static final List<TodayTask? Function(UserContext u, HomeShellState shell)> todaySources = [];

  /// 타일 옆 숫자 배지 (예: 확인 대기 개수).
  static final Map<String, int Function(UserContext u)> tileCounts = {};

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final busy = Busy();
  UserContext get u => widget.user;
  HomeShellState get shell => widget.shell;

  Future<void> _speak(String text) async {
    if (!u.settings.ttsEnabled) return;
    await u.env.speaker.setRate(u.settings.ttsRate);
    await u.env.speaker.speak(text);
  }

  TodayTask? _today() {
    for (final src in DashboardScreen.todaySources) {
      final t = src(u, shell);
      if (t != null) return t;
    }
    final broken = u.youtube.brokenAccounts();
    if (broken.isNotEmpty) {
      return TodayTask(
        status: Status.problem,
        icon3d: 'broken',
        title: S.dash2(broken.first.label),
        action: S.reconnect,
        onTap: () => shell.goTo('channels'),
      );
    }
    final exp = u.youtube.expiringAccounts();
    if (exp.isNotEmpty) {
      return TodayTask(
        status: Status.check,
        icon3d: 'bell',
        title: S.dash3(exp.first.label),
        action: S.reconnect,
        onTap: () => shell.goTo('channels'),
      );
    }
    if (u.youtube.channels().isEmpty) {
      return TodayTask(
        status: Status.check,
        icon3d: 'link',
        title: S.channelNone,
        action: S.channelAdd,
        onTap: () => shell.goTo('channels'),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = dayKey(u.env.now());
    final quotaLeft = u.quota.remaining;
    final quotaLimit = u.settings.quotaDailyLimit;
    final cost = u.ai.monthCostUsd;
    final limit = u.settings.monthlyCostLimitUsd;
    final edits = u.editLog.countOn(today);
    final s = u.settings;
    final todo = _today();
    final quotaRatio = quotaLimit == 0 ? 0.0 : quotaLeft / quotaLimit;
    final costLeft = limit <= 0 ? 0.0 : (1 - cost / limit).clamp(0.0, 1.0);
    Status gaugeStatus(double left) => left <= 0 ? Status.problem : (left < 0.2 ? Status.check : Status.done);
    final broken = u.youtube.brokenAccounts().isNotEmpty;
    final chans = u.youtube.channels().length;
    var i = 0;
    Widget ap(Widget w) => i < 3 ? Appear(index: i++, child: w) : w;

    final tiles = <Widget>[
      if (shell.hasTab('channels'))
        Tile3D(
          key: const Key('tile-channels'),
          icon: 'chart',
          fallback: Icons.video_library,
          title: S.dashTileChannels,
          subtitle: S.dashTileChannelsSub,
          onTap: () => shell.goTo('channels'),
          badge: broken
              ? const StatusBadge(Status.problem, S.dashBroken, shake: true)
              : StatusBadge(chans == 0 ? Status.check : Status.done, chans == 0 ? S.dashNoChannel : S.dash4(chans)),
        ),
      if (shell.hasTab('produce'))
        Tile3D(
          key: const Key('tile-produce'),
          icon: 'create',
          fallback: Icons.movie_creation,
          title: S.dashTileProduce,
          subtitle: S.dashTileProduceSub,
          onTap: () => shell.goTo('produce'),
        ),
      if (DashboardScreen.tileCounts.containsKey('review'))
        Tile3D(
          key: const Key('tile-review'),
          icon: 'review',
          fallback: Icons.fact_check,
          title: S.dashTileReview,
          subtitle: S.dashTileReviewSub,
          onTap: () async {
            shell.goTo('review');
          },
          badge: () {
            final n = DashboardScreen.tileCounts['review']!(u);
            return n > 0
                ? StatusBadge(Status.check, S.dash5(n), shake: true)
                : const StatusBadge(Status.done, S.dashNothingWaiting);
          }(),
        ),
      if (shell.hasTab('blog'))
        Tile3D(
          key: const Key('tile-blog'),
          icon: 'blog',
          fallback: Icons.rss_feed,
          title: S.dashTileBlog,
          subtitle: S.dashTileBlogSub,
          onTap: () => shell.goTo('blog'),
        ),
      if (shell.hasTab('corner'))
        Tile3D(
          key: const Key('tile-corner'),
          icon: 'corner',
          fallback: Icons.auto_stories,
          title: S.dashTileCorner,
          subtitle: S.dashTileCornerSub,
          onTap: () => shell.goTo('corner'),
        ),
      Tile3D(
        key: const Key('tile-settings'),
        icon: 'settings',
        fallback: Icons.settings,
        title: S.dashTileSettings,
        subtitle: S.dashTileSettingsSub,
        onTap: () => shell.goTo('settings'),
      ),
    ];

    // 화면에 보이는 것만 그리는 목록 (빠르게 열리도록).
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppTokens.pagePad, AppTokens.gapS, AppTokens.pagePad, AppTokens.bottomSpace),
      children: [
        ap(
          Row(
            children: [
              const Mascot(MascotMood.hello, size: 88),
              const SizedBox(width: AppTokens.gapM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.dash6(u.user.name), style: Theme.of(context).textTheme.headlineSmall),
                    Text(
                      S.dashHelloSub,
                      style: TextStyle(color: t.textSoft, fontSize: AppTokens.fontBody),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.gapM),
        ap(_todayCard(todo)),
        const SizedBox(height: AppTokens.gapL),
        ap(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.gapL),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: AppTokens.gapXl,
                runSpacing: AppTokens.gapL,
                children: [
                  RingGauge(
                    value: quotaRatio,
                    label: S.homeQuota,
                    center: '${S.num(quotaLeft)}\n/ ${S.num(quotaLimit)}',
                    status: gaugeStatus(quotaRatio),
                  ),
                  RingGauge(
                    value: costLeft,
                    label: S.homeCost,
                    center: '${S.dollars(cost)}\n/ ${S.dollars(limit, 0)}',
                    status: gaugeStatus(costLeft),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.gapS),
        ap(
          Wrap(
            spacing: AppTokens.gapS,
            runSpacing: AppTokens.gapS,
            children: [
              StatusBadge(edits > 0 ? Status.done : Status.progress, '${S.homeTodayEdits} ${S.home1(edits)}'),
              StatusBadge(
                s.runnerEnabled ? Status.progress : Status.check,
                s.runnerEnabled ? S.homeRunnerOn(s.runnerFromHour, s.runnerToHour) : S.homeRunnerOff,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.gapL),
        if (wide)
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - AppTokens.gapM) / 2;
              return Wrap(
                spacing: AppTokens.gapM,
                runSpacing: AppTokens.gapM,
                children: [for (final tile in tiles) SizedBox(width: w, child: tile)],
              );
            },
          )
        else
          for (final tile in tiles)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.gapM),
              child: tile,
            ),
        const SizedBox(height: AppTokens.gapS),
        for (final card in DashboardScreen.extraCards) ap(card(u, shell)),
        ap(
          SectionCard(
            title: S.briefingTitle,
            icon3d: 'hello',
            child: ButtonWrap(
              children: [
                BigButton(
                  key: const Key('briefing'),
                  label: S.homeBriefing,
                  icon: Icons.record_voice_over,
                  onPressed: () => busy.run(() async {
                    final b = u.briefing.compose();
                    u.briefing.markDone();
                    await _showText(S.briefingTitle, b.spoken, mascot: MascotMood.hello);
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
        ),
        ap(
          SectionCard(
            title: S.dailyReportTitle,
            icon3d: 'undo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.edits.dailySummary(today)),
                const SizedBox(height: AppTokens.gapM),
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
        ),
      ],
    );
  }

  Widget _todayCard(TodayTask? todo) {
    final t = context.tokens;
    final st = todo?.status ?? Status.done;
    return Container(
      key: const Key('today-card'),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: t.statusColor(st), width: 3),
        boxShadow: t.raised(),
      ),
      padding: const EdgeInsets.all(AppTokens.gapL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon3D(todo?.icon3d ?? 'party', size: AppTokens.icon3dM),
              const SizedBox(width: AppTokens.gapM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.dashTodayTitle, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppTokens.gapXs),
                    StatusBadge(st, todo == null ? S.dashAllDone : S.dashTodo, shake: todo != null),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.gapM),
          Text(todo?.title ?? S.dashAllDoneSub, style: const TextStyle(fontSize: AppTokens.fontBody + 1)),
          if (todo != null) ...[
            const SizedBox(height: AppTokens.gapM),
            BigButton(
              key: const Key('today-action'),
              label: todo.action,
              icon: Icons.arrow_forward,
              onPressed: todo.onTap,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showText(String title, String text, {MascotMood? mascot}) async {
    final speak = _speak(text);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: mascot == null ? null : Mascot(mascot, size: 96),
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            text,
            key: const Key('spoken-text'),
            style: const TextStyle(fontSize: AppTokens.fontBody + 1),
          ),
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
}
