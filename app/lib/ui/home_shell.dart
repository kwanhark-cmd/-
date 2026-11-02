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
  int _refresh = 0;

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
      await u.runner.tick();
      if (mounted) setState(() => _refresh++);
    } catch (e, st) {
      u.env.logger.error('주기 확인 오류', e, st);
    }
  }

  List<AppTab> get tabs => [
    AppTab(S.navHome, Icons.dashboard, (k) => DashboardScreen(key: k, user: u, shell: this)),
    AppTab(S.navChannels, Icons.video_library, (k) => ChannelsScreen(key: k, user: u)),
    ...TabsRegistry.extraTabs(u, this),
    AppTab(S.navSettings, Icons.settings, (k) => SettingsScreen(key: k, state: widget.state, user: u)),
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

  void refreshAll() => setState(() => _refresh++);

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
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = Column(
      children: [
        if (u.isPracticeMode) const PracticeBanner(),
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
        Expanded(child: list[index].builder(ValueKey('${list[index].id}-$_refresh'))),
      ],
    );
    final mic = FloatingActionButton.large(
      key: const Key('mic'),
      tooltip: S.voiceListen,
      onPressed: openVoice,
      child: const Icon(Icons.mic, size: 40),
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
