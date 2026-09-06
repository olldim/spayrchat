import 'package:flutter/material.dart';

const ink = Color(0xFF1E2336);
const mutedInk = Color(0xFF818598);
const violet = Color(0xFF7462E8);
const canvas = Color(0xFFF6F7FB);
const line = Color(0xFFEBEDF3);
const mint = Color(0xFF42BEA2);
const night = Color(0xFF1B1E31);

final spayrTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: violet, surface: Colors.white),
  scaffoldBackgroundColor: canvas,
  fontFamily: 'Manrope',
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 38,
      fontWeight: FontWeight.w700,
      color: ink,
      letterSpacing: -1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: ink,
      letterSpacing: -.8,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: ink,
      letterSpacing: -.4,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 15, color: ink, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, color: ink, height: 1.4),
    bodySmall: TextStyle(fontSize: 12, color: mutedInk),
  ),
  dividerColor: line,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: canvas,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: violet, width: 1.5),
    ),
    hintStyle: const TextStyle(color: mutedInk, fontSize: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: violet,
      foregroundColor: Colors.white,
      minimumSize: const Size(44, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(foregroundColor: mutedInk),
  ),
  tooltipTheme: const TooltipThemeData(
    waitDuration: Duration(milliseconds: 400),
  ),
);

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF9A8AF7), violet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * .31),
    ),
    child: Icon(
      Icons.graphic_eq_rounded,
      color: Colors.white,
      size: size * .65,
    ),
  );
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final bool online, group;
  const Avatar({
    super.key,
    required this.name,
    this.size = 46,
    this.online = false,
    this.group = false,
  });
  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFEAE5FF),
      Color(0xFFDDF3EB),
      Color(0xFFFBEAD9),
      Color(0xFFDFE9FC),
      Color(0xFFF6DFE9),
    ];
    const textColors = [
      Color(0xFF7962C6),
      Color(0xFF3F997D),
      Color(0xFFB18B5B),
      Color(0xFF5F85C0),
      Color(0xFFBC7293),
    ];
    final hash = name.runes.fold(0, (a, b) => a + b) % colors.length;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((s) => s.isEmpty ? '?' : s.characters.first.toUpperCase())
        .join();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors[hash],
              borderRadius: BorderRadius.circular(size * .35),
            ),
            child: group
                ? Icon(
                    Icons.group_rounded,
                    color: textColors[hash],
                    size: size * .48,
                  )
                : Text(
                    initials,
                    style: TextStyle(
                      color: textColors[hash],
                      fontSize: size * .32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: mint,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ErrorStrip extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const ErrorStrip({super.key, required this.message, required this.onDismiss});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6, right: 4),
    color: const Color(0xFFFFF1ED),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: Color(0xFFB56B53),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF96573F)),
          ),
        ),
        IconButton(
          onPressed: onDismiss,
          tooltip: 'Закрити',
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ],
    ),
  );
}
