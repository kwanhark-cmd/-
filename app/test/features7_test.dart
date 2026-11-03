import 'package:channel_biseo/app/app.dart';
import 'package:channel_biseo/app/services.dart';
import 'package:channel_biseo/features/ai/brain.dart';
import 'package:channel_biseo/features/production/desc_template.dart';
import 'package:channel_biseo/stages.dart';
import 'package:channel_biseo/ui/channels_screen.dart';
import 'package:channel_biseo/ui/produce_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 화면 개선 뒤 추가 기능 (TubeBuddy·vidIQ·Metricool 비교에서 가져온 것)
Future<(TestKit, AppState, UserContext)> setup() async {
  registerStages();
  final k = TestKit();
  final s = AppState(k.env);
  await s.login(k.env.accounts.create('기능', '1234'));
  final u = s.user!;
  u.settings.onboardingDone = true;
  u.settings.produceDailyLimit = 20;
  await u.youtube.connectGoogle();
  for (final c in u.youtube.channels()) {
    await u.youtube.syncChannel(c.channelId);
  }
  return (k, s, u);
}

void main() {
  group('채널별 설명 템플릿', () {
    test('고정 문구·링크·해시태그를 새 영상 설명에 자동으로 붙이고, 두 번 붙지 않는다', () async {
      final (_, _, u) = await setup();
      final store = DescTemplateStore(u.db);
      expect(store.get('UC_mock_cook').isEmpty, isTrue);
      store.save(
        'UC_mock_cook',
        DescTemplate(
          fixed: '구독과 좋아요 부탁드려요',
          links: ['https://blog.example.com'],
          hashtags: DescTemplate.cleanTags(['#집밥 #요리, 집밥']),
        ),
      );
      final t = store.get('UC_mock_cook');
      expect(t.hashtags, ['집밥', '요리']);
      final p = await productionOf(u).create(channelId: 'UC_mock_cook', format: ContentFormat.shorts, topic: '계란말이');
      expect(p.description, contains('구독과 좋아요 부탁드려요'));
      expect(p.description, contains('https://blog.example.com'));
      expect(p.description, endsWith('#집밥 #요리'));
      expect(t.applyTo(p.description), p.description); // 두 번 붙지 않음
      // 다른 채널에는 붙지 않음
      final q = await productionOf(u).create(channelId: 'UC_mock_trip', format: ContentFormat.shorts, topic: '바다');
      expect(q.description, isNot(contains('구독과 좋아요 부탁드려요')));
    });

    testWidgets('채널 화면에서 템플릿 만들기', (t) async {
      final (_, s, u) = await setup();
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(ChannelBiseoApp(state: s));
      await t.pumpAndSettle();
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      // ignore: unawaited_futures
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ChannelDetailScreen(user: u, channelId: 'UC_mock_trip'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('tpl-edit')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('tpl-fixed')), '여행 이야기는 매주 금요일!');
      await t.enterText(find.byKey(const Key('tpl-tags')), '#여행 #국내여행');
      await t.tap(find.byKey(const Key('tpl-save')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('tpl-edit'))); // 다시 열면 "자동으로 붙어요" 표시
      await t.pumpAndSettle();
      expect(find.byKey(const Key('tpl-preview')), findsOneWidget);
      await t.tap(find.text('취소'));
      await t.pumpAndSettle();
      expect(DescTemplateStore(u.db).get('UC_mock_trip').hashtags, ['여행', '국내여행']);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  });
}
