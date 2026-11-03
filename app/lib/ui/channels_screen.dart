import 'package:flutter/material.dart';

import '../app/services.dart';
import '../core/failure.dart';
import '../core/strings.dart';
import '../features/ai/brain.dart';
import '../features/youtube/models.dart';
import '../features/youtube/youtube_service.dart';
import 'common.dart';
import 'edits_screen.dart';

/// 채널 등록: 주소 입력 + "구글로 연결". 연습 모드에서는 가짜 로그인 창.
Future<void> connectGoogleFlow(BuildContext context, UserContext u) async {
  final url = TextEditingController();
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text(S.channelAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('channel-url'),
              controller: url,
              decoration: const InputDecoration(labelText: S.channelUrl),
            ),
            const SizedBox(height: 12),
            const Text(S.channelConnectHint),
            if (u.youtube.isPracticeMode) ...[
              const SizedBox(height: 12),
              const Text(S.mockLoginBody, style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
        FilledButton.icon(
          key: const Key('connect-google'),
          onPressed: () => Navigator.pop(c, true),
          icon: const Icon(Icons.login),
          label: Text(u.youtube.isPracticeMode ? S.mockLoginButton : S.channelConnectGoogle),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  try {
    final rows = await runWithProgress(context, S.channelConnectGoogle, (cancel, p) async {
      final r = await u.youtube.connectGoogle(channelUrl: url.text);
      for (var i = 0; i < r.length; i++) {
        p(i / r.length, S.chan1(r[i].title));
        try {
          await u.youtube.syncChannel(r[i].channelId, cancel: cancel);
        } catch (e) {
          u.env.logger.warn(S.chan2(e));
        }
      }
      return r;
    });
    if (context.mounted && rows != null) toast(context, S.channelAdded(rows.length));
  } catch (e) {
    if (context.mounted) await showFailure(context, e, onRetry: () => connectGoogleFlow(context, u));
  }
}

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key, required this.user});
  final UserContext user;

  /// 채널별 확인 대기 개수 (2단계에서 연결).
  static int Function(UserContext u, String channelId)? waitingCount;
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  UserContext get u => widget.user;

  Future<void> _add() async {
    await connectGoogleFlow(context, u);
    if (mounted) setState(() {});
  }

  Future<void> _open(String channelId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChannelDetailScreen(user: u, channelId: channelId),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chans = u.youtube.channels();
    final broken = u.youtube.brokenAccounts();
    final brokenIds = broken.map((a) => a.id).toSet();
    final waiting = ChannelsScreen.waitingCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppTokens.pagePad, AppTokens.gapS, AppTokens.pagePad, AppTokens.bottomSpace),
      children: [
        TipBanner(
          text: S.chanTip,
          seen: u.settings.tipSeen('channels'),
          onSeen: () => u.settings.markTipSeen('channels'),
        ),
        BigButton(key: const Key('add-channel'), label: S.channelAdd, icon: Icons.add, onPressed: _add),
        for (final a in broken)
          StripeCard(
            status: Status.problem,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusBadge(Status.problem, S.dashBroken, shake: true),
                const SizedBox(height: AppTokens.gapS),
                Text('${a.label}: ${S.failureMessage(FailureKind.permissionRevoked)}'),
                const SizedBox(height: AppTokens.gapS),
                BigButton(label: S.reconnect, icon: Icons.link, onPressed: _add),
              ],
            ),
          ),
        const SizedBox(height: AppTokens.gapM),
        if (chans.isEmpty)
          EmptyState(icon: 'video', message: S.chanEmptyHow, actionLabel: S.channelAdd, onAction: _add),
        for (var i = 0; i < chans.length; i++)
          Appear(
            index: i,
            child: _channelCard(
              t,
              chans[i],
              brokenIds.contains(chans[i].accountId),
              waiting?.call(u, chans[i].channelId) ?? 0,
            ),
          ),
      ],
    );
  }

  Widget _channelCard(AppTokens t, ChannelRow c, bool broken, int waiting) {
    final status = broken ? Status.problem : Status.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.gapS - 2),
      child: StripeCard(
        key: Key('channel-${c.channelId}'),
        status: status,
        thick: true,
        onTap: () => _open(c.channelId),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              child: SizedBox(
                width: 76,
                height: 76,
                child: thumbFor(u, c.channelId).isNotEmpty
                    ? Image.network(
                        thumbFor(u, c.channelId),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon3D('video', size: 76),
                      )
                    : const Icon3D('video', size: 76),
              ),
            ),
            const SizedBox(width: AppTokens.gapM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppTokens.gapXs),
                  Text(
                    '${S.subscribers(c.subscriberCount)} · ${S.videoCount(c.videoCount)} · ${S.views(c.viewCount)}',
                    style: TextStyle(color: t.textSoft),
                  ),
                  const SizedBox(height: AppTokens.gapS),
                  Wrap(
                    spacing: AppTokens.gapS,
                    runSpacing: AppTokens.gapS,
                    children: [
                      StatusBadge(status, broken ? S.dashBroken : S.chanConnected),
                      if (waiting > 0) StatusBadge(Status.check, S.dash5(waiting), shake: true),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.textSoft, size: AppTokens.iconM),
          ],
        ),
      ),
    );
  }
}

/// 채널 썸네일 주소 (없으면 빈 문자열).
String thumbFor(UserContext u, String channelId) {
  final r = u.db.select('SELECT thumbnail FROM channels WHERE channel_id = ?', [channelId]);
  return r.isEmpty ? '' : (r.first['thumbnail'] as String);
}

class ChannelDetailScreen extends StatefulWidget {
  const ChannelDetailScreen({super.key, required this.user, required this.channelId});
  final UserContext user;
  final String channelId;
  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> {
  UserContext get u => widget.user;
  final List<YtVideo> _videos = [];
  int _total = 0;
  final busy = Busy();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _videos
      ..clear()
      ..addAll(u.youtube.videos(widget.channelId, limit: 30));
    _total = u.youtube.videoTotal(widget.channelId);
  }

  void _more() => setState(() => _videos.addAll(u.youtube.videos(widget.channelId, offset: _videos.length, limit: 30)));

  Future<void> _sync() async {
    try {
      await runWithProgress(
        context,
        S.channelSync,
        (cancel, p) => u.youtube.syncChannel(widget.channelId, cancel: cancel, progress: p),
      );
    } catch (e) {
      if (mounted) await showFailure(context, e, onRetry: _sync, onReconnect: () => connectGoogleFlow(context, u));
    }
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final c = u.youtube.channel(widget.channelId);
    if (c == null) return Scaffold(appBar: pageBar(context, S.navChannels), body: const EmptyHint(S.empty));
    final style = StyleCard.decode(c.styleJson);
    return Scaffold(
      appBar: pageBar(context, c.title),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.pagePad,
            AppTokens.gapS,
            AppTokens.pagePad,
            AppTokens.bottomSpace,
          ),
          children: [
            Wrap(
              spacing: AppTokens.gapS,
              runSpacing: AppTokens.gapS,
              children: [
                InfoChip(Icons.people, S.subscribers(c.subscriberCount)),
                InfoChip(Icons.video_library, S.videoCount(c.videoCount)),
                InfoChip(Icons.visibility, S.views(c.viewCount)),
              ],
            ),
            const SizedBox(height: AppTokens.gapM),
            ButtonWrap(
              children: [
                BigButton(
                  key: const Key('sync'),
                  label: S.channelSync,
                  icon: Icons.refresh,
                  onPressed: () => busy.run(_sync),
                ),
                BigButton(
                  label: S.channelEdits,
                  icon: Icons.history,
                  primary: false,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditsScreen(user: u, channelId: c.channelId),
                    ),
                  ),
                ),
                BigButton(
                  label: S.channelDisconnect,
                  icon: Icons.link_off,
                  danger: true,
                  onPressed: () => _disconnect(c),
                ),
              ],
            ),
            SectionCard(
              title: S.channelStyle,
              icon3d: 'sparkles',
              trailing: style == null
                  ? null
                  : IconButton(tooltip: S.edit, icon: const Icon(Icons.edit), onPressed: () => _editStyle(c, style)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (style == null) const Text(S.styleEmpty) else _styleView(style),
                  const SizedBox(height: AppTokens.gapM),
                  BigButton(
                    key: const Key('analyze-style'),
                    label: S.styleAnalyze,
                    icon: Icons.auto_awesome,
                    primary: style == null,
                    onPressed: () => busy.run(() => _analyze(c)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.gapS),
            Row(
              children: [
                const Icon3D('video', size: AppTokens.icon3dS),
                const SizedBox(width: AppTokens.gapS),
                Expanded(child: Text('${S.channelVideos} ($_total)', style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            if (_videos.isEmpty) const EmptyHint(S.chanNoVideos),
            for (var i = 0; i < _videos.length; i++) _videoTile(_videos[i], i),
            if (_videos.length < _total) BigButton(label: S.loadMore, primary: false, onPressed: _more),
          ],
        ),
      ),
    );
  }

  Widget _videoTile(YtVideo v, int i) {
    final t = context.tokens;
    final hidden = v.privacy != 'public';
    return Appear(
      index: i,
      child: StripeCard(
        status: hidden ? Status.check : null,
        onTap: () => _showVideo(v),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              child: SizedBox(
                width: 112,
                height: 63,
                child: v.thumbnailUrl.isEmpty
                    ? ColoredBox(
                        color: t.tonal,
                        child: Icon(Icons.smart_display, color: t.onTonal, size: AppTokens.iconM),
                      )
                    : Image.network(
                        v.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: t.tonal,
                          child: Icon(Icons.smart_display, color: t.onTonal, size: AppTokens.iconM),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppTokens.gapM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppTokens.fontBody),
                  ),
                  Text(S.videoLine(v.viewCount, v.privacy, v.tags.length), style: TextStyle(color: t.textSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _styleView(StyleCard s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${S.styleMood}: ${s.mood}'),
      Text('${S.styleTone}: ${s.tone}'),
      Text('${S.styleTopics}: ${s.topics.join(', ')}'),
      Text('${S.styleTitlePattern}: ${s.titlePattern}'),
      Text('${S.styleAudience}: ${s.audience}'),
      if (s.notes.isNotEmpty) Text('${S.styleNotes}: ${s.notes}'),
    ],
  );

  Future<void> _analyze(ChannelRow c) async {
    if (!await confirmAiCost(context, u, calls: 1, input: 4000, output: 800)) return;
    if (!mounted) return;
    try {
      final card = await runWithProgress(context, S.styleAnalyze, (cancel, p) async {
        if (u.youtube.videoTotal(c.channelId) == 0) {
          await u.youtube.syncChannel(c.channelId, cancel: cancel, progress: p);
        }
        return u.brain.analyzeStyle(c.title, u.youtube.videos(c.channelId, limit: 50));
      });
      if (card == null) return;
      saveStyle(u, c.channelId, card);
      if (mounted) {
        toast(context, S.styleSaved);
        setState(() {});
      }
    } catch (e) {
      if (mounted) await showFailure(context, e, onRetry: () => _analyze(c));
    }
  }

  Future<void> _editStyle(ChannelRow c, StyleCard s) async {
    final r = await editStyleDialog(context, s);
    if (r == null) return;
    saveStyle(u, c.channelId, r);
    if (mounted) setState(() {});
  }

  Future<void> _disconnect(ChannelRow c) async {
    if (!await confirmDanger(context, S.channelDisconnectConfirm(c.title), yes: S.channelDisconnect)) return;
    await u.youtube.disconnectChannel(c.channelId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showVideo(YtVideo v) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(v.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.views(v.viewCount)),
            const SizedBox(height: 8),
            const Text(S.chan5, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(v.description.isEmpty ? S.chan6 : v.description),
            const SizedBox(height: 8),
            const Text(S.chan7, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(v.tags.isEmpty ? S.chan6 : v.tags.join(', ')),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.close))],
    ),
  );
}

void saveStyle(UserContext u, String channelId, StyleCard card) =>
    u.db.execute('UPDATE channels SET style_json = ? WHERE channel_id = ?', [card.encode(), channelId]);

/// 스타일 카드 직접 고치기 (채널·블로그 공통).
Future<StyleCard?> editStyleDialog(BuildContext context, StyleCard s) {
  final mood = TextEditingController(text: s.mood);
  final tone = TextEditingController(text: s.tone);
  final topics = TextEditingController(text: s.topics.join(', '));
  final pattern = TextEditingController(text: s.titlePattern);
  final audience = TextEditingController(text: s.audience);
  final notes = TextEditingController(text: s.notes);
  Widget f(String l, TextEditingController c, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: lines,
      decoration: InputDecoration(labelText: l),
    ),
  );
  return showDialog<StyleCard>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text(S.channelStyle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            f(S.styleMood, mood),
            f(S.styleTone, tone),
            f(S.chan8(S.styleTopics), topics),
            f(S.styleTitlePattern, pattern),
            f(S.styleAudience, audience),
            f(S.styleNotes, notes, lines: 3),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            c,
            StyleCard(
              mood: mood.text,
              tone: tone.text,
              topics: topics.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
              titlePattern: pattern.text,
              audience: audience.text,
              notes: notes.text,
              editedByUser: true,
            ),
          ),
          child: const Text(S.save),
        ),
      ],
    ),
  );
}
