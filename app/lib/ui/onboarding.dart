import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/services.dart';
import '../core/strings.dart';
import 'channels_screen.dart';
import 'common.dart';

/// 첫 실행 안내: 언어·글씨 → 권한 → 계정 연결(건너뛰기 가능) → 연습 모드 안내.
class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({super.key, required this.state, required this.user});
  final AppState state;
  final UserContext user;

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  int step = 0;
  bool? mic;
  bool? notify;
  bool? storage;

  UserContext get u => widget.user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.wizardTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.all(24), children: [_body(context)]),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (step > 0)
                Expanded(
                  child: BigButton(label: S.back, primary: false, onPressed: () => setState(() => step--)),
                ),
              if (step > 0) const SizedBox(width: 12),
              Expanded(
                child: BigButton(
                  key: const Key('wizard-next'),
                  label: step == 3 ? S.wizardFinish : S.next,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    if (step < 3) {
      setState(() => step++);
      return;
    }
    u.settings.onboardingDone = true;
    widget.state.refresh();
  }

  Widget _body(BuildContext context) {
    final t = Theme.of(context).textTheme;
    switch (step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.wizardStep1, style: t.headlineSmall),
            const SizedBox(height: 16),
            Text(S.wizardLanguage, style: t.titleMedium),
            RadioGroup<String>(
              groupValue: 'ko',
              onChanged: (_) {},
              child: const Column(
                children: [
                  RadioListTile<String>(value: 'ko', title: Text(S.wizardLanguageKo)),
                  RadioListTile<String>(value: 'other', title: Text(S.wizardLanguageOther), enabled: false),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(S.settingsFontSize, style: t.titleMedium),
            const SizedBox(height: 8),
            FontScalePicker(state: widget.state),
            const SizedBox(height: 16),
            const Text('가나다라 ABC 123 — 이 글씨 크기로 보여요.'),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.wizardStep2, style: t.headlineSmall),
            const SizedBox(height: 8),
            const Text(S.wizardPermIntro),
            const SizedBox(height: 12),
            _perm(Icons.mic, S.permMic, S.permMicWhy, mic, () async {
              final ok = await u.env.speech.initialize();
              setState(() => mic = ok);
            }),
            _perm(Icons.notifications, S.permNotify, S.permNotifyWhy, notify, () async {
              final ok = await u.env.notifier.requestPermission();
              setState(() => notify = ok);
            }),
            // 파일은 고를 때마다 기기가 직접 물어보므로 여기서는 안내만 한다.
            _perm(Icons.folder, S.permStorage, S.permStorageWhy, storage, () async => setState(() => storage = true)),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.wizardStep3, style: t.headlineSmall),
            const SizedBox(height: 8),
            const Text(S.wizardAccountIntro),
            const SizedBox(height: 16),
            BigButton(
              key: const Key('wizard-connect'),
              label: S.wizardConnectNow,
              icon: Icons.link,
              onPressed: () async {
                await connectGoogleFlow(context, u);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Text('지금 연결된 채널: ${u.youtube.channels().length}개'),
            const SizedBox(height: 12),
            BigButton(label: S.skip, primary: false, onPressed: () => setState(() => step++)),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.wizardStep4, style: t.headlineSmall),
            const SizedBox(height: 12),
            const PracticeBanner(),
            const SizedBox(height: 12),
            const Text(S.wizardPracticeIntro, style: TextStyle(fontSize: 17)),
          ],
        );
    }
  }

  Widget _perm(IconData icon, String name, String why, bool? state, Future<void> Function() ask) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Text(why),
            const SizedBox(height: 8),
            if (state == null)
              BigButton(label: S.permAllow, primary: false, onPressed: ask)
            else
              Text(state ? S.permAllowed : S.permDenied, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class FontScalePicker extends StatelessWidget {
  const FontScalePicker({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final v = state.textScale;
    return SegmentedButton<double>(
      segments: const [
        ButtonSegment(value: 1.0, label: Text(S.settingsFontSmall)),
        ButtonSegment(value: 1.3, label: Text(S.settingsFontLarge)),
        ButtonSegment(value: 1.6, label: Text(S.settingsFontHuge)),
      ],
      selected: {v >= 1.6 ? 1.6 : (v >= 1.3 ? 1.3 : 1.0)},
      onSelectionChanged: (s) => state.setTextScale(s.first),
    );
  }
}
