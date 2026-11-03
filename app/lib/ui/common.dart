import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/failure.dart';
import '../core/retry.dart';
import '../app/services.dart';
import '../core/strings.dart';

/// 크고 단순한 버튼. 글씨가 커져도 잘리지 않게 여러 줄로 감싼다.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 26), const SizedBox(width: 10)],
          Flexible(child: Text(label, textAlign: TextAlign.center, softWrap: true)),
        ],
      ),
    );
    final style = danger ? FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError) : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56, minWidth: 120),
      child: primary || danger
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}

/// 화면 위 "연습 모드" 띠.
class PracticeBanner extends StatelessWidget {
  const PracticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: S.practiceMode,
      child: Container(
        width: double.infinity,
        color: cs.tertiaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.school, color: cs.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${S.practiceMode} — ${S.practiceModeHint}',
                style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.icon, this.trailing});
  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 버튼들을 화면 폭에 맞게 줄바꿈해서 배치.
class ButtonWrap extends StatelessWidget {
  const ButtonWrap({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 12, children: children);
}

Future<bool> confirm(
  BuildContext context,
  String message, {
  String yes = S.yes,
  String no = S.no,
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: SingleChildScrollView(child: Text(message, style: const TextStyle(fontSize: 18))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        duration: const Duration(seconds: 4),
      ),
    );
}

/// 오류를 쉬운 말로 보여 주고, 다음 행동 버튼(다시 시도 / 다시 연결 / 설정 열기)을 준다.
Future<void> showFailure(
  BuildContext context,
  Object error, {
  VoidCallback? onRetry,
  VoidCallback? onReconnect,
  VoidCallback? onSettings,
}) async {
  final f = toFailure(error);
  if (f.kind == FailureKind.cancelled) {
    toast(context, S.progressCancelled);
    return;
  }
  VoidCallback? action;
  switch (f.nextAction) {
    case NextAction.retry:
      action = onRetry;
    case NextAction.reconnect:
      action = onReconnect;
    case NextAction.checkSettings:
      action = onSettings;
    case NextAction.tryTomorrow:
    case NextAction.none:
      action = null;
  }
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.info_outline, size: 36),
      content: Text(f.userMessage, style: const TextStyle(fontSize: 18)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.close)),
        if (action != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              action!();
            },
            child: Text(S.nextActionLabel(f.nextAction)),
          ),
      ],
    ),
  );
}

/// 긴 작업을 진행률 + 취소 버튼과 함께 실행. 화면은 멈추지 않는다.
Future<T?> runWithProgress<T>(
  BuildContext context,
  String title,
  Future<T> Function(CancelToken cancel, void Function(double, String) progress) task,
) async {
  final cancel = CancelToken();
  final p = ValueNotifier<(double, String)>((0, S.working));
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: ValueListenableBuilder<(double, String)>(
        valueListenable: p,
        builder: (_, v, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: v.$1 <= 0 ? null : v.$1, minHeight: 10),
            const SizedBox(height: 12),
            Text(v.$2, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            cancel.cancel();
            p.value = (p.value.$1, S.progressCancelled);
          },
          child: const Text(S.progressCancel),
        ),
      ],
    ),
  );
  try {
    return await task(cancel, (f, m) => p.value = (f, m));
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await dialog;
    p.dispose();
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, S.copied);
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
  );
}

/// 화면 하나가 그리다 오류가 나도 앱 전체가 죽지 않게.
Widget friendlyErrorWidget(FlutterErrorDetails d) => const Material(
  child: Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(S.errorScreen, textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
    ),
  ),
);

/// 여러 번 눌러도 한 번만 실행되게.
class Busy {
  bool _busy = false;
  Future<void> run(Future<void> Function() f) async {
    if (_busy) return;
    _busy = true;
    try {
      await f();
    } finally {
      _busy = false;
    }
  }
}

/// 숫자 입력 칸.
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.decimal = false,
  });
  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final bool decimal;
  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController c = TextEditingController(text: '${widget.value}');
  Timer? _t;
  @override
  void dispose() {
    _t?.cancel();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
    decoration: InputDecoration(labelText: widget.label, border: const OutlineInputBorder()),
    onChanged: (v) {
      final n = widget.decimal ? double.tryParse(v) : int.tryParse(v);
      if (n != null) widget.onChanged(n);
    },
  );
}

/// AI 를 쓰는 작업 전에 예상 비용을 보여 주고 확인한다. 연습 모드(비용 0)면 묻지 않는다.
Future<bool> confirmAiCost(
  BuildContext context,
  UserContext u, {
  int calls = 1,
  int input = 3000,
  int output = 1200,
}) async {
  if (u.ai.isPracticeMode || calls <= 0) return true;
  final one = u.ai.estimateCost('x' * (input ~/ 2), 'x' * (input ~/ 2), expectedOutput: output);
  final est = one * calls;
  return confirm(
    context,
    S.aiCostConfirm(
      est.toStringAsFixed(3),
      u.ai.monthCostUsd.toStringAsFixed(2),
      u.settings.monthlyCostLimitUsd.toStringAsFixed(0),
    ),
    yes: S.next,
    no: S.cancel,
  );
}
