import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 상태 4가지. 같은 뜻은 앱 어디서나 같은 색·아이콘을 쓴다.
enum Status {
  /// 초록: 완료·연결됨
  done,

  /// 파랑: 진행 중
  progress,

  /// 노랑: 확인 필요
  check,

  /// 빨강: 문제·주의
  problem,
}

/// 기능 영역별 색 (홈 타일·설정 묶음). 같은 영역은 앱 어디서나 같은 색.
enum Hue {
  /// 채널
  blue,

  /// 제작
  purple,

  /// 확인 대기
  yellow,

  /// 블로그
  orange,

  /// 내 코너
  green,

  /// 위험·문제
  red,

  /// 그 밖 (설정·자료 관리)
  slate,
}

/// 앱 꾸미기 → 색 묶음. 주요색·강조색·보조 버튼 색만 바뀌고 상태 색(초록·파랑·노랑·빨강)은 그대로.
enum ColorTheme { basic, ocean, forest, sunset }

/// 앱의 모든 색·크기·간격·둥글기·그림자·움직임 시간. 화면은 이 값만 쓴다.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.tonal,
    required this.onTonal,
    required this.success,
    required this.progress,
    required this.warning,
    required this.danger,
    required this.onStatusDark,
    required this.background,
    required this.card,
    required this.text,
    required this.textSoft,
    required this.border,
    required this.shadowColor,
    required this.reduceMotion,
    required this.highContrast,
  });

  // ---- 색 ----
  final Color primary; // 주요색
  final Color onPrimary;
  final Color accent; // 강조색 (주요 동작 버튼)
  final Color onAccent;
  final Color tonal; // 보조 버튼 바탕 (회색 대신 옅은 주요색)
  final Color onTonal;
  final Color success; // 초록
  final Color progress; // 파랑
  final Color warning; // 노랑
  final Color danger; // 빨강
  final Color onStatusDark; // 노랑 위 글자
  final Color background;
  final Color card;
  final Color text;
  final Color textSoft;
  final Color border;
  final Color shadowColor;

  // ---- 사용자 설정 ----
  final bool reduceMotion;
  final bool highContrast;

  // ---- 크기·간격·둥글기 ----
  static const double buttonHeight = 56;
  static const double touch = 48;
  static const double radius = 16;
  static const double radiusSmall = 12;
  static const double gapXs = 4;
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 16;
  static const double gapXl = 24;

  /// 카드와 카드 사이 (예전 16의 1.5배)
  static const double cardGap = 24;
  static const double radiusCard = 22;
  static const double pagePad = 16;
  static const double bottomSpace = 120; // 마이크 버튼에 가리지 않게
  static const double iconS = 24;
  static const double iconM = 32;
  static const double icon3dS = 40;
  static const double icon3dM = 56;
  static const double icon3dL = 72;
  static const double depth = 5; // 버튼·타일의 두께 (눌리면 줄어듦)
  static const double tileMaxWidth = 320;
  static const double micSize = 84;
  static const double contentMaxWidth = 720;

  /// 큰 숫자 (게이지·통계). 글씨 단계: hero 34 > title 26 > section 21 > body 17 > small 16
  static const fontHero = 34.0;
  static const fontTitle = 26.0;
  static const fontSection = 21.0;
  static const fontBody = 17.0;
  static const fontButton = 18.0;
  static const fontSmall = 16.0;

  /// 버튼 글자 최소 크기·버튼 최소 높이·테두리 두께 (잘 보이게 다시 정한 기준, 테스트로 확인)
  static const fontButtonMin = 17.0;
  static const buttonMinHeight = 52.0;
  static const outlineWidth = 2.0;
  static const focusWidth = 3.0;

  // ---- 움직임 시간 (움직임 줄이기면 0) ----
  Duration get fast => reduceMotion ? Duration.zero : const Duration(milliseconds: 150);
  Duration get normal => reduceMotion ? Duration.zero : const Duration(milliseconds: 250);
  Duration get slow => reduceMotion ? Duration.zero : const Duration(milliseconds: 450);
  Duration get stagger => reduceMotion ? Duration.zero : const Duration(milliseconds: 40);

  // ---- 그림자 (입체감) ----
  List<BoxShadow> raised([Color? base]) => [
    BoxShadow(color: shadowColor.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6)),
    BoxShadow(color: shadowColor.withValues(alpha: 0.12), blurRadius: 3, offset: const Offset(0, 1)),
  ];

  List<BoxShadow> pressedShadow() => [
    BoxShadow(color: shadowColor.withValues(alpha: 0.22), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  /// 채운 카드의 부드러운 그림자 (테두리 대신). 어두운 모드에서도 보이게 조금 진하게.
  List<BoxShadow> soft() => highContrast
      ? const []
      : [
          BoxShadow(
            color: shadowColor.withValues(alpha: background.computeLuminance() < 0.2 ? 0.45 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];

  /// 영역 색 타일 바탕. 밝은 모드는 파스텔, 어두운 모드는 중간 채도 (어두운 바탕 위 어두운 상자 금지).
  Color tileBg(Hue h) {
    if (highContrast) return card;
    final dark = background.computeLuminance() < 0.2;
    return switch (h) {
      Hue.blue => dark ? const Color(0xFF2B559E) : const Color(0xFFDCEAFF),
      Hue.purple => dark ? const Color(0xFF6441AE) : const Color(0xFFEDE3FF),
      Hue.yellow => dark ? const Color(0xFFD9A514) : const Color(0xFFFFF1BF),
      Hue.orange => dark ? const Color(0xFF8F4010) : const Color(0xFFFFE4D1),
      Hue.green => dark ? const Color(0xFF1E633D) : const Color(0xFFD9F4E3),
      Hue.red => dark ? const Color(0xFFA7241C) : const Color(0xFFFFE0DE),
      Hue.slate => dark ? const Color(0xFF4A5280) : const Color(0xFFE6E9F4),
    };
  }

  /// 영역 색 타일 위 글자색 (대비 4.5:1 이상, 테스트로 확인).
  Color onTile(Hue h) {
    if (highContrast) return text;
    final dark = background.computeLuminance() < 0.2;
    if (dark) return h == Hue.yellow ? const Color(0xFF1F1600) : const Color(0xFFFFFFFF);
    return switch (h) {
      Hue.blue => const Color(0xFF0B3577),
      Hue.purple => const Color(0xFF41197F),
      Hue.yellow => const Color(0xFF574000),
      Hue.orange => const Color(0xFF7A2E00),
      Hue.green => const Color(0xFF0D4A2C),
      Hue.red => const Color(0xFF7F1010),
      Hue.slate => const Color(0xFF262B45),
    };
  }

  /// 영역 색 아이콘 칩 (설정 묶음 머리 등): 진한 바탕 + 흰 아이콘.
  Color hueStrong(Hue h) {
    if (highContrast) return text;
    return switch (h) {
      Hue.blue => const Color(0xFF2563EB),
      Hue.purple => const Color(0xFF7C3AED),
      Hue.yellow => const Color(0xFF946200),
      Hue.orange => const Color(0xFFC2410C),
      Hue.green => const Color(0xFF15803D),
      Hue.red => const Color(0xFFB91C1C),
      Hue.slate => const Color(0xFF475070),
    };
  }

  Color onHueStrong(Hue h) => highContrast ? background : const Color(0xFFFFFFFF);

  static Hue hueOfStatus(Status s) => switch (s) {
    Status.done => Hue.green,
    Status.progress => Hue.blue,
    Status.check => Hue.yellow,
    Status.problem => Hue.red,
  };

  List<BoxShadow> flat() => [
    BoxShadow(color: shadowColor.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  // ---- 상태 ----
  Color statusColor(Status s) => switch (s) {
    Status.done => success,
    Status.progress => progress,
    Status.check => warning,
    Status.problem => danger,
  };

  Color onStatus(Status s) => s == Status.check ? onStatusDark : const Color(0xFFFFFFFF);

  static IconData statusIcon(Status s) => switch (s) {
    Status.done => Icons.check_circle,
    Status.progress => Icons.autorenew,
    Status.check => Icons.error_outline,
    Status.problem => Icons.report,
  };

  /// 버튼 아래쪽 두께 색 (바탕보다 어둡게).
  static Color darker(Color c, [double amount = 0.22]) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  static AppTokens light({bool reduceMotion = false}) => AppTokens(
    primary: const Color(0xFF3949AB),
    onPrimary: const Color(0xFFFFFFFF),
    accent: const Color(0xFF9A3412),
    onAccent: const Color(0xFFFFFFFF),
    tonal: const Color(0xFFE3E7FA),
    onTonal: const Color(0xFF26338A),
    success: const Color(0xFF166534),
    progress: const Color(0xFF1E40AF),
    warning: const Color(0xFFFACC15),
    danger: const Color(0xFF991B1B),
    onStatusDark: const Color(0xFF1F2328),
    background: const Color(0xFFF6F7FB),
    card: const Color(0xFFFFFFFF),
    text: const Color(0xFF1A1C2E),
    textSoft: const Color(0xFF4A4F66),
    border: const Color(0xFFD5D9E8),
    shadowColor: const Color(0xFF1A1C2E),
    reduceMotion: reduceMotion,
    highContrast: false,
  );

  static AppTokens dark({bool reduceMotion = false}) => AppTokens(
    primary: const Color(0xFF8C9EFF),
    onPrimary: const Color(0xFF0A0E2E),
    accent: const Color(0xFF9A3412),
    onAccent: const Color(0xFFFFFFFF),
    tonal: const Color(0xFF2A3157),
    onTonal: const Color(0xFFDDE2FF),
    success: const Color(0xFF166534),
    progress: const Color(0xFF1E40AF),
    warning: const Color(0xFFFACC15),
    danger: const Color(0xFF991B1B),
    onStatusDark: const Color(0xFF1F2328),
    background: const Color(0xFF12131C),
    card: const Color(0xFF242739),
    text: const Color(0xFFECEDF5),
    textSoft: const Color(0xFFB9BCCF),
    border: const Color(0xFF3A3E57),
    shadowColor: const Color(0xFF000000),
    reduceMotion: reduceMotion,
    highContrast: false,
  );

  /// 고대비: 글자와 바탕 차이를 최대로.
  static AppTokens contrast({required bool darkMode, bool reduceMotion = false}) => darkMode
      ? AppTokens(
          primary: const Color(0xFFB4C1FF),
          onPrimary: const Color(0xFF000000),
          accent: const Color(0xFFFFB37A),
          onAccent: const Color(0xFF000000),
          tonal: const Color(0xFF000000),
          onTonal: const Color(0xFFFFFFFF),
          success: const Color(0xFF7CF2A4),
          progress: const Color(0xFF9CC2FF),
          warning: const Color(0xFFFFE066),
          danger: const Color(0xFFFF9A9A),
          onStatusDark: const Color(0xFF000000),
          background: const Color(0xFF000000),
          card: const Color(0xFF0B0B0B),
          text: const Color(0xFFFFFFFF),
          textSoft: const Color(0xFFF0F0F0),
          border: const Color(0xFFFFFFFF),
          shadowColor: const Color(0xFF000000),
          reduceMotion: reduceMotion,
          highContrast: true,
        )
      : AppTokens(
          primary: const Color(0xFF1A237E),
          onPrimary: const Color(0xFFFFFFFF),
          accent: const Color(0xFF8A2C08),
          onAccent: const Color(0xFFFFFFFF),
          tonal: const Color(0xFFFFFFFF),
          onTonal: const Color(0xFF000000),
          success: const Color(0xFF0B5A2A),
          progress: const Color(0xFF0B3A9E),
          warning: const Color(0xFFFFD500),
          danger: const Color(0xFF8B0000),
          onStatusDark: const Color(0xFF000000),
          background: const Color(0xFFFFFFFF),
          card: const Color(0xFFFFFFFF),
          text: const Color(0xFF000000),
          textSoft: const Color(0xFF1A1A1A),
          border: const Color(0xFF000000),
          shadowColor: const Color(0xFF000000),
          reduceMotion: reduceMotion,
          highContrast: true,
        );

  /// 색 묶음 적용 (고대비 모드에서는 쓰지 않음: 대비가 우선)
  AppTokens withPalette(ColorTheme p) {
    if (p == ColorTheme.basic || highContrast) return this;
    final dark = background.computeLuminance() < 0.2;
    // (주요색, 주요색 위 글자, 강조색, 강조색 위 글자, 보조 바탕, 보조 글자) — 대비는 테스트로 확인
    final c = switch ((p, dark)) {
      (ColorTheme.ocean, false) => (0xFF0B5C8C, 0xFFFFFFFF, 0xFF0C615B, 0xFFFFFFFF, 0xFFDCEFF7, 0xFF0B4566),
      (ColorTheme.ocean, true) => (0xFF7CC4F0, 0xFF062033, 0xFF0C615B, 0xFFFFFFFF, 0xFF1E3A4C, 0xFFD6EEFA),
      (ColorTheme.forest, false) => (0xFF2A6135, 0xFFFFFFFF, 0xFF8C4107, 0xFFFFFFFF, 0xFFE1F0E3, 0xFF1F4D29),
      (ColorTheme.forest, true) => (0xFF8FD19E, 0xFF0E2A15, 0xFF8C4107, 0xFFFFFFFF, 0xFF22392A, 0xFFDDF2E2),
      (ColorTheme.sunset, false) => (0xFF7B2D8E, 0xFFFFFFFF, 0xFFA71552, 0xFFFFFFFF, 0xFFF3E2F7, 0xFF5A1F68),
      (ColorTheme.sunset, true) => (0xFFD7A6E6, 0xFF2E0F38, 0xFFA71552, 0xFFFFFFFF, 0xFF3A2445, 0xFFF3DDF8),
      _ => (
        primary.toARGB32(),
        onPrimary.toARGB32(),
        accent.toARGB32(),
        onAccent.toARGB32(),
        tonal.toARGB32(),
        onTonal.toARGB32(),
      ),
    };
    return AppTokens(
      primary: Color(c.$1),
      onPrimary: Color(c.$2),
      accent: Color(c.$3),
      onAccent: Color(c.$4),
      tonal: Color(c.$5),
      onTonal: Color(c.$6),
      success: success,
      progress: progress,
      warning: warning,
      danger: danger,
      onStatusDark: onStatusDark,
      background: background,
      card: card,
      text: text,
      textSoft: textSoft,
      border: border,
      shadowColor: shadowColor,
      reduceMotion: reduceMotion,
      highContrast: highContrast,
    );
  }

  /// 눌렀을 때 바탕 위에 덮는 색: 어두운 바탕(밝은 글자)은 더 어둡게, 밝은 바탕(어두운 글자)은 더 밝게.
  /// 그래서 눌러도 글자 대비가 줄지 않고 오히려 커진다.
  /// 이미 검정·흰색에 가까운 바탕은 더 갈 곳이 없어 반대쪽으로 조금 (대비는 12:1 이상 그대로).
  static Color pressOverlay(Color bg) {
    final l = bg.computeLuminance();
    if (l < 0.01) return const Color(0x33FFFFFF);
    if (l > 0.9) return const Color(0x22000000);
    return l < 0.2 ? const Color(0x33000000) : const Color(0x66FFFFFF);
  }

  /// 눌린 상태의 바탕색 (테스트에서 대비를 확인).
  static Color pressedBg(Color bg) => Color.alphaBlend(pressOverlay(bg), bg);

  /// 키보드로 고른(초점) 버튼 둘레 선: 본문 글자색이라 바탕과 대비가 크다.
  Color get focusRing => text;

  /// 테두리 버튼의 선 색: 고대비는 글자색, 그 밖에는 주요색 (바탕·카드와 3:1 이상, 테스트로 확인).
  Color get outline => highContrast ? border : primary;

  /// 빨강(위험) 버튼 위 글자색: 보통 흰색, 고대비 어두운 모드(밝은 빨강)에서는 검정.
  Color get onDanger => danger.computeLuminance() > 0.35 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  /// 상태 색 위에 올라가는 글자색 (흰색 또는 짙은색) — 고대비 모드에서는 밝은 상태색에 검정.
  Color onStatusFor(Status s) {
    if (highContrast && background.computeLuminance() < 0.5) return const Color(0xFF000000);
    return onStatus(s);
  }

  @override
  AppTokens copyWith({bool? reduceMotion}) => AppTokens(
    primary: primary,
    onPrimary: onPrimary,
    accent: accent,
    onAccent: onAccent,
    tonal: tonal,
    onTonal: onTonal,
    success: success,
    progress: progress,
    warning: warning,
    danger: danger,
    onStatusDark: onStatusDark,
    background: background,
    card: card,
    text: text,
    textSoft: textSoft,
    border: border,
    shadowColor: shadowColor,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    highContrast: highContrast,
  );

  @override
  AppTokens lerp(AppTokens? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension TokensOf on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.light();
}

/// WCAG 대비 비율.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const _buttonText = TextStyle(fontFamily: 'NotoSansKR', fontSize: AppTokens.fontButton, fontWeight: FontWeight.w700);
const _buttonPad = EdgeInsets.symmetric(horizontal: AppTokens.gapL, vertical: AppTokens.gapM);

/// 색을 채운 버튼 모양 (주요 동작·위험 동작·안내 띠 버튼이 함께 씀).
/// 눌림은 바탕색을 바꿔 보이고(글자 대비는 오히려 커짐), 초점은 굵은 둘레 선으로 보인다.
ButtonStyle solidButtonStyle(AppTokens t, Color bg, Color fg) => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((s) {
    if (s.contains(WidgetState.disabled)) return Color.alphaBlend(t.background.withValues(alpha: 0.55), bg);
    if (s.contains(WidgetState.pressed)) return AppTokens.pressedBg(bg);
    if (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)) {
      return Color.alphaBlend(AppTokens.pressOverlay(bg).withValues(alpha: 0.12), bg);
    }
    return bg;
  }),
  foregroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled) ? Color.alphaBlend(t.background.withValues(alpha: 0.4), fg) : fg,
  ),
  iconColor: WidgetStateProperty.all(fg),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  minimumSize: const WidgetStatePropertyAll(Size(AppTokens.touch, AppTokens.buttonHeight)),
  padding: const WidgetStatePropertyAll(_buttonPad),
  textStyle: const WidgetStatePropertyAll(_buttonText),
  elevation: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.pressed) ? 0 : 2),
  shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius))),
  side: WidgetStateProperty.resolveWith((s) {
    if (s.contains(WidgetState.focused)) return BorderSide(color: t.focusRing, width: AppTokens.focusWidth);
    return t.highContrast ? BorderSide(color: t.border, width: AppTokens.outlineWidth) : BorderSide.none;
  }),
  tapTargetSize: MaterialTapTargetSize.padded,
);

/// 테두리 버튼 (보조 동작): 옅은 바탕 + 2px 선. 누르면 선이 더 굵어지고 바탕이 바뀐다.
ButtonStyle outlineButtonStyle(AppTokens t) => solidButtonStyle(t, t.tonal, t.onTonal).copyWith(
  elevation: const WidgetStatePropertyAll(0),
  side: WidgetStateProperty.resolveWith((s) {
    if (s.contains(WidgetState.disabled)) {
      return BorderSide(color: Color.alphaBlend(t.background.withValues(alpha: 0.55), t.outline), width: 2);
    }
    if (s.contains(WidgetState.focused)) return BorderSide(color: t.focusRing, width: AppTokens.focusWidth);
    if (s.contains(WidgetState.pressed)) return BorderSide(color: t.outline, width: AppTokens.focusWidth);
    return BorderSide(color: t.outline, width: AppTokens.outlineWidth);
  }),
);

/// 위험 동작(삭제·초기화) 버튼: 빨강 바탕.
ButtonStyle dangerButtonStyle(AppTokens t) => solidButtonStyle(t, t.danger, t.onDanger);

/// 토큰으로 Flutter 테마를 만든다. 버튼은 모두 색이 있는 버튼(회색 글자 버튼 없음).
ThemeData buildAppTheme(AppTokens t, Brightness b) {
  final base = ColorScheme.fromSeed(seedColor: t.primary, brightness: b);
  final cs = base.copyWith(
    primary: t.primary,
    onPrimary: t.onPrimary,
    secondary: t.accent,
    onSecondary: t.onAccent,
    error: t.danger,
    onError: t.onDanger,
    surface: t.card,
    onSurface: t.text,
    onSurfaceVariant: t.textSoft,
    outline: t.border,
    primaryContainer: t.tonal,
    onPrimaryContainer: t.onTonal,
    secondaryContainer: t.tonal,
    onSecondaryContainer: t.onTonal,
    tertiaryContainer: t.warning,
    onTertiaryContainer: t.onStatusDark,
    errorContainer: t.danger,
    onErrorContainer: t.onDanger,
  );
  const minSize = Size(AppTokens.touch, AppTokens.buttonHeight);
  const textStyle = _buttonText;
  final transitions = t.reduceMotion
      ? const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _NoTransition(),
            TargetPlatform.iOS: _NoTransition(),
            TargetPlatform.linux: _NoTransition(),
            TargetPlatform.macOS: _NoTransition(),
            TargetPlatform.windows: _NoTransition(),
          },
        )
      : const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          },
        );
  return ThemeData(
    colorScheme: cs,
    brightness: b,
    fontFamily: 'NotoSansKR',
    useMaterial3: true,
    scaffoldBackgroundColor: t.background,
    extensions: [t],
    pageTransitionsTheme: transitions,
    visualDensity: VisualDensity.comfortable,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: TextTheme(
      headlineSmall: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: AppTokens.fontTitle,
        fontWeight: FontWeight.w800,
        color: t.text,
      ),
      titleLarge: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: AppTokens.fontSection,
        fontWeight: FontWeight.w700,
        color: t.text,
      ),
      titleMedium: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: AppTokens.fontBody + 1,
        fontWeight: FontWeight.w700,
        color: t.text,
      ),
      bodyLarge: TextStyle(fontFamily: 'NotoSansKR', fontSize: AppTokens.fontBody + 1, color: t.text),
      bodyMedium: TextStyle(fontFamily: 'NotoSansKR', fontSize: AppTokens.fontBody, color: t.text),
      bodySmall: TextStyle(fontFamily: 'NotoSansKR', fontSize: AppTokens.fontSmall, color: t.textSoft),
      labelLarge: textStyle,
      labelMedium: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: AppTokens.fontSmall,
        fontWeight: FontWeight.w700,
        color: t.text,
      ),
      labelSmall: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: AppTokens.fontSmall,
        fontWeight: FontWeight.w700,
        color: t.text,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.background,
      foregroundColor: t.text,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: AppTokens.fontTitle - 2,
        fontWeight: FontWeight.w800,
        color: t.text,
      ),
      iconTheme: IconThemeData(color: t.text, size: AppTokens.iconM),
    ),
    cardTheme: CardThemeData(
      color: t.card,
      elevation: t.highContrast ? 0 : 3,
      shadowColor: t.shadowColor.withValues(alpha: b == Brightness.dark ? 0.6 : 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        side: t.highContrast ? BorderSide(color: t.border, width: 2) : BorderSide.none,
      ),
      margin: const EdgeInsets.symmetric(vertical: AppTokens.cardGap / 2),
    ),
    filledButtonTheme: FilledButtonThemeData(style: solidButtonStyle(t, t.accent, t.onAccent)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: solidButtonStyle(t, t.accent, t.onAccent)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlineButtonStyle(t)),
    textButtonTheme: TextButtonThemeData(style: outlineButtonStyle(t)),
    iconButtonTheme: IconButtonThemeData(
      style:
          IconButton.styleFrom(
            backgroundColor: t.tonal,
            foregroundColor: t.onTonal,
            minimumSize: const Size(AppTokens.touch, AppTokens.touch),
            iconSize: AppTokens.iconS + 2,
            tapTargetSize: MaterialTapTargetSize.padded,
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.pressed) ? AppTokens.pressedBg(t.tonal) : t.tonal,
            ),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            side: WidgetStateProperty.resolveWith((s) {
              if (s.contains(WidgetState.focused)) return BorderSide(color: t.focusRing, width: AppTokens.focusWidth);
              if (s.contains(WidgetState.pressed)) return BorderSide(color: t.outline, width: AppTokens.outlineWidth);
              return t.highContrast ? BorderSide(color: t.border, width: AppTokens.outlineWidth) : BorderSide.none;
            }),
          ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: t.tonal,
        foregroundColor: t.onTonal,
        selectedBackgroundColor: t.primary,
        selectedForegroundColor: t.onPrimary,
        minimumSize: minSize,
        textStyle: textStyle,
        side: BorderSide(color: t.outline, width: AppTokens.outlineWidth),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.tonal,
      selectedColor: t.primary,
      labelStyle: TextStyle(
        fontFamily: 'NotoSansKR',
        color: t.onTonal,
        fontSize: AppTokens.fontBody,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: 'NotoSansKR',
        color: t.onPrimary,
        fontSize: AppTokens.fontBody,
        fontWeight: FontWeight.w700,
      ),
      checkmarkColor: t.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.gapM, vertical: AppTokens.gapS),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSmall)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.accent,
      foregroundColor: t.onAccent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius + 8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.card,
      indicatorColor: t.tonal,
      height: 76,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: 'NotoSansKR', fontSize: AppTokens.fontSmall, fontWeight: FontWeight.w700, color: t.text),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(size: 28, color: s.contains(WidgetState.selected) ? t.onTonal : t.textSoft),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t.card,
      indicatorColor: t.tonal,
      selectedIconTheme: IconThemeData(color: t.onTonal, size: 30),
      unselectedIconTheme: IconThemeData(color: t.textSoft, size: 28),
      selectedLabelTextStyle: TextStyle(
        fontFamily: 'NotoSansKR',
        color: t.text,
        fontWeight: FontWeight.w800,
        fontSize: AppTokens.fontSmall,
      ),
      unselectedLabelTextStyle: TextStyle(fontFamily: 'NotoSansKR', color: t.textSoft, fontSize: AppTokens.fontSmall),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSmall)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        borderSide: BorderSide(color: t.border, width: t.highContrast ? 2 : 1),
      ),
      labelStyle: TextStyle(fontFamily: 'NotoSansKR', color: t.textSoft, fontSize: AppTokens.fontBody),
      filled: true,
      fillColor: t.card,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius + 4)),
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: AppTokens.fontSection,
        fontWeight: FontWeight.w800,
        color: t.text,
      ),
      contentTextStyle: TextStyle(fontFamily: 'NotoSansKR', fontSize: AppTokens.fontBody + 1, color: t.text),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.fixed,
      backgroundColor: t.text,
      contentTextStyle: TextStyle(fontFamily: 'NotoSansKR', fontSize: AppTokens.fontBody, color: t.background),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius)),
      actionTextColor: t.warning,
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: AppTokens.gapM,
      minTileHeight: AppTokens.touch + 8,
      textColor: t.text,
      iconColor: t.primary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.onPrimary : t.textSoft),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : t.tonal),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.progress, linearTrackColor: t.tonal),
    dividerTheme: DividerThemeData(color: t.border, thickness: t.highContrast ? 2 : 1),
  );
}

class _NoTransition extends PageTransitionsBuilder {
  const _NoTransition();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
