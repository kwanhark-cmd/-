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
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  UserContext get u => widget.user;

  @override
  Widget build(BuildContext context) {
    final chans = u.youtube.channels();
    final broken = u.youtube.brokenAccounts();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        BigButton(
          key: const Key('add-channel'),
          label: S.channelAdd,
          icon: Icons.add,
          onPressed: () async {
            await connectGoogleFlow(context, u);
            if (mounted) setState(() {});
          },
        ),
        for (final a in broken)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.link_off),
              title: Text('${a.label}: ${S.failureMessage(FailureKind.permissionRevoked)}'),
              trailing: TextButton(
                onPressed: () async {
                  await connectGoogleFlow(context, u);
                  if (mounted) setState(() {});
                },
                child: const Text(S.reconnect),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (chans.isEmpty) const EmptyHint(S.channelNone),
        for (final c in chans)
          Card(
            child: ListTile(
              key: Key('channel-${c.channelId}'),
              leading: const CircleAvatar(child: Icon(Icons.smart_display)),
              title: Text(c.title, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                '${S.subscribers(c.subscriberCount)} · ${S.videoCount(c.videoCount)} · ${S.views(c.viewCount)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChannelDetailScreen(user: u, channelId: c.channelId),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
      ],
    );
  }
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
    if (c == null) return const Scaffold(body: EmptyHint(S.empty));
    final style = StyleCard.decode(c.styleJson);
    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${S.subscribers(c.subscriberCount)} · ${S.videoCount(c.videoCount)} · ${S.views(c.viewCount)}'),
            const SizedBox(height: 12),
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
              icon: Icons.palette,
              trailing: style == null
                  ? null
                  : IconButton(tooltip: S.edit, icon: const Icon(Icons.edit), onPressed: () => _editStyle(c, style)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (style == null) const Text(S.styleEmpty) else _styleView(style),
                  const SizedBox(height: 12),
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
            SectionCard(
              title: '${S.channelVideos} ($_total)',
              icon: Icons.list,
              child: Column(
                children: [
                  if (_videos.isEmpty) const Text(S.empty),
                  for (final v in _videos)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: v.thumbnailUrl.isEmpty
                          ? const Icon(Icons.smart_display)
                          : SizedBox(
                              width: 96,
                              child: Image.network(
                                v.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(Icons.smart_display),
                              ),
                            ),
                      title: Text(v.title),
                      subtitle: Text(S.videoLine(v.viewCount, v.privacy, v.tags.length)),
                      onTap: () => _showVideo(v),
                    ),
                  if (_videos.length < _total) BigButton(label: S.loadMore, primary: false, onPressed: _more),
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
    if (!await confirm(context, S.channelDisconnectConfirm(c.title), yes: S.channelDisconnect, danger: true)) return;
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
