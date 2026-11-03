import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/services.dart';
import '../core/strings.dart';
import 'channels_screen.dart';
import 'common.dart';
import 'dashboard.dart';
import 'edits_screen.dart';
import 'memos_screen.dart';
import 'settings_screen.dart';
import 'tabs_registry.dart';
import 'voice_sheet.dart';

/// 로그인 뒤 기본 화면: 아래(또는 옆) 메뉴 + 어디서나 마이크 버튼.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state, required this.user});
  final AppState state;
  final UserContext user;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int index = 0;
  Timer? _ticker;

  /// 한 번이라도 연 탭 (열어 둔 탭은 화면과 스크롤 위치를 그대로 유지).
  final Set<String> _opened = {};

  UserContext get u => widget.user;

  @override
  void initState() {
    super.initState();
    u.runner.onChange = () {
      if (mounted) setState(() {});
    };
    // 1분마다: 아침 브리핑 시간인지, 자동 작업 시간인지 확인
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    u.runner.onChange = null;
    super.dispose();
  }

  Future<void> tick() async {
    try {
      if (u.briefing.isDue()) {
        final b = u.briefing.compose();
        u.briefing.markDone();
        await u.env.notifier.show(S.briefingTitle, b.spoken);
        if (u.settings.ttsEnabled) {
          await u.env.speaker.setRate(u.settings.ttsRate);
          await u.env.speaker.speak(b.spoken);
        }
      }
      final ran = await u.runner.tick();
      // 화면을 새로 만들지 않고 내용만 다시 그린다 (스크롤 위치 유지)
      if (mounted && ran) setState(() {});
    } catch (e, st) {
      u.env.logger.error(S.shell1, e, st);
    }
  }

  List<AppTab> get tabs => [
    AppTab(
      S.navHome,
      Icons.dashboard,
      (k) => DashboardScreen(key: k, user: u, shell: this),
      id: 'home',
    ),
    AppTab(
      S.navChannels,
      Icons.video_library,
      (k) => ChannelsScreen(key: k, user: u),
      id: 'channels',
    ),
    ...TabsRegistry.extraTabs(u, this),
    AppTab(
      S.navSettings,
      Icons.settings,
      (k) => SettingsScreen(key: k, state: widget.state, user: u),
      id: 'settings',
    ),
  ];

  void goTo(String target) {
    final names = tabs.map((t) => t.id).toList();
    switch (target) {
      case 'home':
        setState(() => index = 0);
      case 'channels':
        setState(() => index = 1);
      case 'edits':
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EditsScreen(user: u)));
      case 'memos':
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MemosScreen(user: u)));
      default:
        final i = names.indexOf(target);
        if (i >= 0) {
          setState(() => index = i);
        } else {
          TabsRegistry.openRoute(context, u, target);
        }
    }
  }

  /// 내용만 다시 그린다. 화면을 새로 만들지 않으므로 보던 위치가 그대로 남는다.
  void refreshAll() {
    if (mounted) setState(() {});
  }

  bool hasTab(String id) => tabs.any((t) => t.id == id);

  Future<void> openVoice() async {
    final r = await showVoiceSheet(context, u);
    if (!mounted) return;
    if (r?.navigateTo != null) goTo(r!.navigateTo!);
    refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final list = tabs;
    if (index >= list.length) index = 0;
    _opened.add(list[index].id);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = Column(
      children: [
        if (u.runner.running)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.autorenew),
              title: Text(u.runner.progressText),
              subtitle: LinearProgressIndicator(value: u.runner.progress),
              trailing: TextButton(onPressed: u.runner.cancel, child: const Text(S.progressCancel)),
            ),
          ),
        Expanded(
          // 연 적 있는 탭은 계속 살려 두어 메뉴를 오가도 보던 위치가 남는다.
          child: IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < list.length; i++)
                (i == index || _opened.contains(list[i].id))
                    ? KeyedSubtree(
                        key: PageStorageKey('tab-${list[i].id}'),
                        child: list[i].builder(ValueKey('tab-${list[i].id}')),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
    final tk = context.tokens;
    final mic = Tooltip(
      message: S.voiceListen,
      child: Press3D(
        key: const Key('mic'),
        color: tk.accent,
        radius: 44,
        depth: 6,
        semanticLabel: S.voiceListen,
        onTap: openVoice,
        child: SizedBox(
          width: AppTokens.micSize,
          height: AppTokens.micSize,
          child: Icon(Icons.mic, size: AppTokens.micSize / 2, color: tk.onAccent),
        ),
      ),
    );
    if (wide) {
      return Scaffold(
        appBar: AppBar(title: Text('${S.appName} — ${u.user.name}')),
        floatingActionButton: mic,
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) => setState(() => index = i),
                destinations: [
                  for (final t in list) NavigationRailDestination(icon: Icon(t.icon), label: Text(t.label)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(list[index].label)),
      floatingActionButton: mic,
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [for (final t in list) NavigationDestination(icon: Icon(t.icon), label: t.label)],
      ),
    );
  }
}
