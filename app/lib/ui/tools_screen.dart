import 'package:flutter/material.dart';

import '../app/services.dart';
import '../core/strings.dart';
import '../features/tools/tools_service.dart';
import 'common.dart';

extension ToolsOf on UserContext {
  ToolsService get tools => extensions['tools']! as ToolsService;
}

/// 도구 연결 화면: 연결됨(초록)/안 됨(빨강), 연결 테스트, 연결 해제, 만료 시 다시 연결.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key, required this.user});
  final UserContext user;
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  UserContext get u => widget.user;
  final busy = Busy();
  List<ToolInfo> tools = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await u.tools.all();
    if (mounted) setState(() => tools = t);
  }

  Color _color(ToolState s, ColorScheme cs) => switch (s) {
    ToolState.connected => Colors.green.shade700,
    ToolState.preparing => cs.outline,
    _ => cs.error,
  };

  String _label(ToolState s) => switch (s) {
    ToolState.connected => S.toolConnected,
    ToolState.notConnected => S.toolNotConnected,
    ToolState.expired => S.toolExpired,
    ToolState.preparing => S.toolPreparing,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = u.settings;
    return Scaffold(
      appBar: pageBar(context, S.toolsTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final t in tools)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, color: _color(t.state, cs), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t.name, style: Theme.of(context).textTheme.titleMedium)),
                        ],
                      ),
                      Text('${t.role} · ${_label(t.state)}', key: Key('tool-state-${t.id.name}')),
                      if (t.detail.isNotEmpty) Text(t.detail),
                      const SizedBox(height: 8),
                      if (t.state != ToolState.preparing)
                        ButtonWrap(
                          children: [
                            if (t.state != ToolState.connected)
                              BigButton(
                                key: Key('tool-connect-${t.id.name}'),
                                label: t.state == ToolState.expired ? S.reconnect : S.toolConnect,
                                onPressed: () => busy.run(() => _connect(t.id)),
                              ),
                            if (t.state != ToolState.notConnected) ...[
                              BigButton(
                                label: S.toolTest,
                                primary: false,
                                onPressed: () => busy.run(() => _test(t.id)),
                              ),
                              BigButton(
                                label: S.toolDisconnect,
                                primary: false,
                                onPressed: () => busy.run(() async {
                                  await u.tools.disconnect(t.id);
                                  await _load();
                                }),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            SectionCard(
              title: S.toolPriority,
              icon: Icons.low_priority,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${S.toolVideoGen}: ${s.videoToolPriority.map(_toolName).join(' → ')}'),
                  Text('${S.toolNarration}: ${s.narrationToolPriority.map(_toolName).join(' → ')}'),
                  Text(S.tool1(S.toolMotion)),
                  const SizedBox(height: 8),
                  BigButton(
                    label: S.tool2,
                    primary: false,
                    onPressed: () => setState(() {
                      final l = [...s.videoToolPriority];
                      l.add(l.removeAt(0));
                      s.videoToolPriority = l;
                    }),
                  ),
                  const SizedBox(height: 8),
                  BigButton(
                    label: S.tool3,
                    primary: false,
                    onPressed: () => setState(() {
                      final l = [...s.narrationToolPriority];
                      l.add(l.removeAt(0));
                      s.narrationToolPriority = l;
                    }),
                  ),
                ],
              ),
            ),
            const ListTile(
              leading: Icon(Icons.lock),
              title: Text(S.toolVault),
              subtitle: Text(S.tool4),
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }

  static String _toolName(String id) => switch (id) {
    'googleVids' => S.tool5,
    'higgsfield' => S.tool6,
    'ownFile' => S.tool7,
    'vrew' => S.tool8,
    _ => id,
  };

  Future<void> _connect(ToolId id) async {
    try {
      if (id == ToolId.higgsfield) {
        final c = TextEditingController();
        final key = await showDialog<String>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(S.tool9(S.toolApiKey)),
            content: TextField(
              key: const Key('higgs-key'),
              controller: c,
              obscureText: true,
              decoration: const InputDecoration(labelText: S.toolApiKey),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: const Text(S.cancel)),
              FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text(S.save)),
            ],
          ),
        );
        if (key == null || key.trim().isEmpty) return;
        await u.tools.connectHiggsfield(key);
      } else if (id == ToolId.figma) {
        final cid = TextEditingController(text: u.tools.figmaClientId);
        final sec = TextEditingController();
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text(S.tool10),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(S.tool11),
                const SizedBox(height: 12),
                TextField(
                  controller: cid,
                  decoration: const InputDecoration(labelText: S.tool12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sec,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: S.tool13),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text(S.cancel)),
              FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text(S.toolConnect)),
            ],
          ),
        );
        if (ok != true) return;
        u.tools.figmaClientId = cid.text;
        if (sec.text.isNotEmpty) await u.secrets.write(ToolsService.figmaSecret, sec.text.trim());
        await u.tools.connectFigma();
      }
      await _load();
    } catch (e) {
      if (mounted) await showFailure(context, e, onRetry: () => _connect(id));
    }
  }

  Future<void> _test(ToolId id) async {
    try {
      await u.tools.test(id);
      if (mounted) toast(context, S.toolTestOk);
    } catch (e) {
      if (mounted) await showFailure(context, e, onReconnect: () => _connect(id), onRetry: () => _test(id));
    }
    await _load();
  }
}
