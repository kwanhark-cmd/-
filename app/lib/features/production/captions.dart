import 'dart:io';
import 'dart:typed_data';

/// 자막 한 줄 (시작·끝 시각과 글).
class Cue {
  const Cue(this.start, this.end, this.text);
  final Duration start;
  final Duration end;
  final String text;
}

/// 대본으로 자막 만들기 (돈이 드는 받아쓰기 없이).
/// - 무대 지시(괄호·대괄호로 된 줄, "장면 1:" 같은 머리)는 뺀다.
/// - 한 자막은 한 줄 최대 [lineMax] 자, 두 줄까지. 띄어쓰기에서 자른다.
/// - 시간은 글자 수에 비례해 영상 길이에 나눈다 (한 자막 최소 1초).
class CaptionMaker {
  static const lineMax = 18;

  /// 한국어 나레이션 평균 속도 (초당 글자). 영상 길이를 모를 때 쓴다.
  static const charsPerSecond = 6.5;

  static final _direction = RegExp(r'^\s*[\[(（【].*[\])）】]\s*$');
  static final _sceneHead = RegExp(r'^\s*(장면|씬|scene|#)\s*\d*\s*[:：.]?\s*', caseSensitive: false);
  static final _speaker = RegExp(r'^\s*(나레이션|내레이션|NA|N)\s*[:：]\s*', caseSensitive: false);

  /// 대본 → 자막 덩어리들
  static List<String> chunks(String script) {
    final sentences = <String>[];
    for (var line in script.split(RegExp(r'\r?\n'))) {
      if (_direction.hasMatch(line)) continue;
      line = line.replaceAll(RegExp(r'[\[(（【][^\])）】]*[\])）】]'), ' '); // 줄 안의 지시문
      line = line.replaceFirst(_sceneHead, '').replaceFirst(_speaker, '').trim();
      if (line.isEmpty) continue;
      // 문장 끝(. ! ? … 。)에서 나눔
      sentences.addAll(line.split(RegExp(r'(?<=[.!?…。])\s+')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final out = <String>[];
    for (final s in sentences) {
      out.addAll(_wrap(s));
    }
    return out;
  }

  /// 한 문장을 두 줄짜리 자막들로
  static List<String> _wrap(String sentence) {
    final words = sentence.split(RegExp(r'\s+'));
    final lines = <String>[];
    var cur = '';
    for (final w in words) {
      if (w.length > lineMax) {
        // 띄어쓰기 없이 긴 낱말은 강제로 자름
        if (cur.isNotEmpty) lines.add(cur);
        for (var i = 0; i < w.length; i += lineMax) {
          lines.add(w.substring(i, i + lineMax > w.length ? w.length : i + lineMax));
        }
        cur = '';
        continue;
      }
      final next = cur.isEmpty ? w : '$cur $w';
      if (next.length > lineMax) {
        lines.add(cur);
        cur = w;
      } else {
        cur = next;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    final out = <String>[];
    for (var i = 0; i < lines.length; i += 2) {
      out.add(i + 1 < lines.length ? '${lines[i]}\n${lines[i + 1]}' : lines[i]);
    }
    return out;
  }

  /// 덩어리들에 시간 붙이기. [total] 이 없으면 읽는 속도로 정함.
  static List<Cue> timed(List<String> parts, Duration? total) {
    if (parts.isEmpty) return const [];
    int len(String s) => s.replaceAll(RegExp(r'\s'), '').length.clamp(1, 1 << 20);
    final chars = parts.fold<int>(0, (a, s) => a + len(s));
    final totalMs = total?.inMilliseconds ?? (chars / charsPerSecond * 1000).round();
    // 한 자막 최소 1초. 영상이 너무 짧으면 끝까지 같은 비율로
    final minMs = (totalMs / parts.length < 1000) ? (totalMs / parts.length).floor() : 1000;
    final cues = <Cue>[];
    var t = 0;
    for (var i = 0; i < parts.length; i++) {
      var d = (totalMs * len(parts[i]) / chars).round();
      if (d < minMs) d = minMs;
      final end = i == parts.length - 1 ? totalMs : (t + d).clamp(0, totalMs);
      cues.add(Cue(Duration(milliseconds: t), Duration(milliseconds: end), parts[i]));
      t = end;
    }
    return cues;
  }

  static String _ts(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final ms = d.inMilliseconds;
    return '${two(ms ~/ 3600000)}:${two(ms ~/ 60000 % 60)}:${two(ms ~/ 1000 % 60)},${(ms % 1000).toString().padLeft(3, '0')}';
  }

  static String toSrt(List<Cue> cues) {
    final b = StringBuffer();
    for (var i = 0; i < cues.length; i++) {
      b
        ..writeln(i + 1)
        ..writeln('${_ts(cues[i].start)} --> ${_ts(cues[i].end)}')
        ..writeln(cues[i].text)
        ..writeln();
    }
    return b.toString();
  }

  /// 사용자가 고친 SRT 읽기. 형식이 틀리면 [FormatException].
  static List<Cue> parseSrt(String text) {
    final re = RegExp(r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})');
    Duration at(Match m) => Duration(
      hours: int.parse(m[1]!),
      minutes: int.parse(m[2]!),
      seconds: int.parse(m[3]!),
      milliseconds: int.parse(m[4]!),
    );
    final cues = <Cue>[];
    for (final block in text.replaceAll('\r', '').split(RegExp(r'\n\s*\n'))) {
      final lines = block.trim().split('\n');
      if (lines.isEmpty || lines.first.trim().isEmpty) continue;
      final timeIdx = lines.indexWhere((l) => l.contains('-->'));
      if (timeIdx < 0) throw FormatException('시간 줄이 없음', block);
      final ms = re.allMatches(lines[timeIdx]).toList();
      if (ms.length != 2) throw FormatException('시간 형식', lines[timeIdx]);
      final start = at(ms[0]), end = at(ms[1]);
      if (end <= start) throw FormatException('끝이 시작보다 빠름', lines[timeIdx]);
      final body = lines.sublist(timeIdx + 1).join('\n').trim();
      if (body.isEmpty) throw FormatException('글이 비어 있음', block);
      cues.add(Cue(start, end, body));
    }
    if (cues.isEmpty) throw const FormatException('자막이 없음');
    return cues;
  }

  /// MP4 영상 길이 (moov/mvhd 를 읽음). 읽을 수 없으면 null.
  static Duration? mp4Duration(File f) {
    try {
      final raf = f.openSync();
      try {
        final size = raf.lengthSync();
        Duration? scan(int from, int to) {
          var pos = from;
          while (pos + 8 <= to) {
            raf.setPositionSync(pos);
            final h = ByteData.sublistView(Uint8List.fromList(raf.readSync(16)));
            if (h.lengthInBytes < 8) return null;
            var boxSize = h.getUint32(0);
            final type = String.fromCharCodes([h.getUint8(4), h.getUint8(5), h.getUint8(6), h.getUint8(7)]);
            var header = 8;
            if (boxSize == 1 && h.lengthInBytes >= 16) {
              boxSize = h.getUint64(8);
              header = 16;
            } else if (boxSize == 0) {
              boxSize = to - pos;
            }
            if (boxSize < header) return null;
            if (type == 'moov') return scan(pos + header, pos + boxSize);
            if (type == 'mvhd') {
              raf.setPositionSync(pos + header);
              final b = ByteData.sublistView(Uint8List.fromList(raf.readSync(32)));
              final version = b.getUint8(0);
              final int timescale, duration;
              if (version == 1) {
                timescale = b.getUint32(20);
                duration = b.getUint64(24);
              } else {
                timescale = b.getUint32(12);
                duration = b.getUint32(16);
              }
              if (timescale == 0) return null;
              return Duration(milliseconds: (duration * 1000 / timescale).round());
            }
            pos += boxSize;
          }
          return null;
        }

        return scan(0, size);
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return null;
    }
  }
}
