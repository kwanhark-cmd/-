import 'package:flutter/material.dart';

import '../app/services.dart';
import '../core/strings.dart';
import '../features/voice/voice_controller.dart';
import 'common.dart';

/// 마이크 버튼을 누르면 열리는 창. 음성 인식이 안 되면 글자로 입력할 수 있다.
/// 중요한 명령은 화면과 음성으로 한 번 더 확인한다.
Future<VoiceResult?> showVoiceSheet(BuildContext context, UserContext u) {
  return showModalBottomSheet<VoiceResult>(
    context: context,
    isScrollControlled: true,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: _VoiceSheet(u: u),
    ),
  );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet({required this.u});
  final UserContext u;
  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  final text = TextEditingController();
  String status = S.voiceCommandHint;
  String heard = '';
  String answer = '';
  bool listening = false;
  VoiceResult? last;
  final busy = Busy();

  UserContext get u => widget.u;

  Future<void> _say(String t) async {
    if (!u.settings.ttsEnabled) return;
    await u.env.speaker.setRate(u.settings.ttsRate);
    await u.env.speaker.speak(t);
  }

  Future<void> _listen() async {
    setState(() {
      listening = true;
      status = S.voiceListening;
    });
    final words = await u.env.speech.listenOnce();
    if (!mounted) return;
    setState(() => listening = false);
    if (words == null || words.trim().isEmpty) {
      setState(() => status = u.env.speech.available ? '잘 듣지 못했어요. 다시 눌러 말씀해 주세요.' : S.voiceNotAvailable);
      return;
    }
    await _run(words);
  }

  Future<void> _run(String words, {bool confirmed = false}) async {
    setState(() {
      heard = words;
      status = S.working;
    });
    try {
      final r = await u.voice.handle(words, confirmed: confirmed);
      if (!mounted) return;
      setState(() {
        answer = r.spoken;
        status = '';
        last = r;
      });
      await _say(r.spoken);
      if (r.needsConfirmation && mounted) {
        final ok = await confirm(context, r.spoken, yes: S.yes, no: S.no);
        if (ok) {
          await _run(words, confirmed: true);
        } else {
          setState(() => answer = '취소했어요.');
        }
      }
    } catch (e) {
      if (mounted) await showFailure(context, e, onRetry: () => _run(words, confirmed: confirmed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(S.voiceListen, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (status.isNotEmpty) Text(status),
            if (heard.isNotEmpty) Text('들은 말: "$heard"', style: const TextStyle(color: Colors.grey)),
            if (answer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                answer,
                key: const Key('voice-answer'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            BigButton(
              key: const Key('voice-listen'),
              label: listening ? S.voiceListening : S.voiceListen,
              icon: Icons.mic,
              onPressed: listening ? null : () => busy.run(_listen),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('voice-text'),
                    controller: text,
                    decoration: const InputDecoration(labelText: S.voiceTypeInstead),
                    onSubmitted: (v) => busy.run(() => _run(v)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('voice-send'),
                  iconSize: 32,
                  onPressed: () => busy.run(() => _run(text.text)),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('voice-close'),
                onPressed: () {
                  u.env.speaker.stop();
                  Navigator.pop(context, last);
                },
                child: const Text(S.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
