import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'app/app.dart';
import 'core/strings.dart';
import 'features/ai/brain.dart';
import 'features/production/production_service.dart';
import 'features/tools/tools_service.dart';
import 'ui/common.dart';
import 'ui/dashboard.dart';
import 'ui/produce_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/tabs_registry.dart';
import 'ui/tools_screen.dart';

/// 2~4단계 기능을 앱에 붙이는 곳. 단계가 추가될 때마다 여기에 늘어난다.
bool _registered = false;

void registerStages() {
  if (_registered) return;
  _registered = true;
  _stage2();
}

// ---------------- 2단계: 콘텐츠 제작과 업로드 ----------------
void _stage2() {
  AppState.plugins.add((u) async {
    final tools = ToolsService(
      db: u.db,
      secrets: u.secrets,
      json: u.env.jsonHttp,
      raw: u.env.httpClient,
      oauth: u.oauth,
      now: u.env.now,
      logger: u.env.logger,
    );
    final ps = ProductionService(
      db: u.db,
      youtube: u.youtube,
      brain: u.brain,
      settings: u.settings,
      memos: u.memos,
      tools: tools,
      quota: u.quota,
      now: u.env.now,
      mediaDir: p.join(u.env.accounts.userDir(u.user.id), 'media'),
      logger: u.env.logger,
    );
    u.extensions['tools'] = tools;
    u.extensions['production'] = ps;
    u.voice.privateList = () =>
        ps.list(statuses: [ProductionStatus.uploadedPrivate], limit: 500).map((e) => e.title).toList();
    u.voice.makeContent = (channelTitle, format, topic) async {
      final ch = u.youtube.channels().firstWhere(
        (c) => c.title == channelTitle,
        orElse: () => u.youtube.channels().first,
      );
      try {
        final pr = await ps.create(channelId: ch.channelId, format: format, topic: topic);
        return '${ch.title}에 ${formatLabel(format)} "${pr.title}"을(를) 만들었어요. 제작 화면에서 확인해 주세요.';
      } on ProductionBlocked catch (e) {
        return e.message;
      }
    };
    u.briefing.todaySources.add(ps.briefingItems);
    var toolNotices = <String>[];
    u.briefing.expiringSources.add(() => toolNotices);
    toolNotices = await tools.expiringNotices();
  });

  TabsRegistry.addTab(
    (u, shell) => AppTab(
      S.navProduce,
      Icons.movie_creation,
      (k) => ProduceScreen(key: k, user: u),
      id: 'produce',
    ),
  );
  TabsRegistry.addRoute('review', (context, u) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReviewScreen(user: u)));
  });

  DashboardScreen.extraCards.add((u, shell) {
    final n = productionOf(u).reviewList().length;
    return SectionCard(
      title: S.homeReviewWaiting,
      icon: Icons.fact_check,
      child: ButtonWrap(
        children: [
          BigButton(
            label: '${S.produceReviewList} ($n)',
            icon: Icons.list,
            primary: false,
            onPressed: () => shell.goTo('review'),
          ),
          BigButton(
            label: S.produceNew,
            icon: Icons.add,
            primary: false,
            onPressed: () async {
              await newProductionFlow(shell.context, u);
              shell.refreshAll();
            },
          ),
        ],
      ),
    );
  });

  SettingsScreen.extraSections.add((context, u, refresh) {
    final s = u.settings;
    return SectionCard(
      title: '콘텐츠 제작',
      icon: Icons.movie_creation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NumberField(
            label: S.settingsProduceLimit,
            value: s.produceDailyLimit,
            onChanged: (v) => s.produceDailyLimit = v.toInt(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: s.aiLabelMethod,
            isExpanded: true,
            decoration: const InputDecoration(labelText: S.settingsAiLabel),
            items: const [
              DropdownMenuItem(value: 'description', child: Text(S.produceAiLabelDesc)),
              DropdownMenuItem(value: 'channel', child: Text(S.produceAiLabelChannel)),
              DropdownMenuItem(value: 'setting', child: Text(S.produceAiLabelSetting)),
            ],
            onChanged: (v) {
              s.aiLabelMethod = v ?? 'setting';
              refresh();
            },
          ),
          const SizedBox(height: 12),
          BigButton(
            key: const Key('open-tools'),
            label: S.settingsTools,
            icon: Icons.build,
            primary: false,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ToolsScreen(user: u))),
          ),
        ],
      ),
    );
  });
}

/// 테스트 등에서 형식 이름이 필요할 때.
String formatName(ContentFormat f) => formatLabel(f);
