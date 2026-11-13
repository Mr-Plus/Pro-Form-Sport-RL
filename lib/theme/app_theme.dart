import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static bool isDark = true;

  // Couleur du fond de l'icône de l'application & du Splashscreen (#FCB4B8)
  static const Color splashBackground = Color(0xFFFCB4B8);

  // Couleur identitaire de l'application (Rose Corail issu du logo #FCB4B8 / #FB7185)
  static const Color brandRose = Color(0xFFFCB4B8);
  static const Color brandRoseAccent = Color(0xFFFB7185);
  static const Color brandRoseGlow = Color(0x40FB7185);

  static Color get rose => const Color(0xFFFB7185);
  static Color get rosePastel => const Color(0xFFFCB4B8);

  // Hiérarchie principale : Fond bleu nuit profond athlétique & Niveaux de cartes (conformes aux maquettes)
  static Color get level0 => const Color(0xFF0F1722);
  static Color get level1 => const Color(0xFF162032);
  static Color get level2 => const Color(0xFF1F2D44);
  static Color get level3 => const Color(0xFF2A3D5B);

  // Touches de pastel désaturées adaptées au mode sombre
  static Color get pastelSlateBlue => const Color(0xFF1E3A5F);
  static Color get pastelSage => const Color(0xFF1B3D2F);
  static Color get pastelSand => const Color(0xFF3D2E1E);
  static Color get pastelStoneViolet => const Color(0xFF332042);
  static Color get pastelClay => const Color(0xFF422222);

  // Typographie haute lisibilité adaptative
  static Color get textPrimary => const Color(0xFFF8FAFC);
  static Color get textSecondary => const Color(0xFF94A3B8);
  static Color get textMuted => const Color(0xFF64748B);

  // Couleurs d'accentuation vibrantes et adaptatives
  static Color get primary =>
      isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1); // Sky 400 en sombre, Bleu ardoise en clair
  static Color get orange =>
      isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C); // Ambre chaud
  static Color get green =>
      isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D); // Vert émeraude
  static Color get red =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C); // Rouge corail
  static Color get purple =>
      isDark ? const Color(0xFFA78BFA) : const Color(0xFF5B21B6); // Violet lavande
  static Color get amber =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309); // Ocre doré lumineux

  static Color readableProfileColor(int colorValue) {
    final c = Color(colorValue);
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * 0.75).clamp(0.35, 0.70))
        .withLightness(isDark ? 0.65 : 0.34)
        .toColor();
  }

  static Color pastelTouchFromColor(int colorValue) {
    final c = Color(colorValue);
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * 0.45).clamp(0.20, 0.45))
        .withLightness(isDark ? 0.22 : 0.92)
        .toColor();
  }
}

/// Système d'espacement unifié pour toute l'application (aéré et respirant)
class AppSpacing {
  static const double pageHorizontal = 18.0;
  static const double pageTop = 16.0;
  static const double pageBottom = 95.0; // Espace pour la barre de navigation flottante Liquid Glass

  static const EdgeInsets page = EdgeInsets.fromLTRB(
    pageHorizontal,
    pageTop,
    pageHorizontal,
    pageBottom,
  );

  static const double sectionGap = 24.0;
  static const double cardGap = 18.0;
  static const double itemGap = 14.0;
  static const double headerGap = 18.0;

  static const double cardPadding = 18.0;
  static const double cardRadius = 22.0;
  static const double innerRadius = 16.0;
  static const double smallRadius = 12.0;
}

/// Styles de cartes et conteneurs unifiés basés sur l'écran d'accueil
class AppCards {
  /// Décoration signature d'une carte principale (fond level1, bordure subtile, ombre douce)
  static BoxDecoration cardDecoration({
    Color? color,
    double radius = 22.0,
    Border? border,
    bool showShadow = true,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.level1,
        borderRadius: BorderRadius.circular(radius),
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      );

  /// Décoration d'une sous-carte ou d'un élément interne
  static BoxDecoration subCardDecoration({
    Color? color,
    double radius = 16.0,
    Border? border,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.level2,
        borderRadius: BorderRadius.circular(radius),
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1.0,
            ),
      );

  /// Pastille d'accent rose/corail pour tags et statuts
  static BoxDecoration tagDecoration({
    Color? color,
    double radius = 12.0,
  }) {
    final c = color ?? AppColors.rose;
    return BoxDecoration(
      color: c.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: c.withValues(alpha: 0.45),
        width: 1.0,
      ),
    );
  }
}

/// Typographie unifiée pour les titres (H1, H2, H3), métriques et textes
class AppTypography {
  /// H1 : Grand titre principal d'écran (ex: "SÉANCES", "PROGRAMMES", "HISTORIQUE")
  static TextStyle h1({
    Color? color,
    double fontSize = 26,
    double letterSpacing = 1.2,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.bebasNeue(
        color: color ?? AppColors.textPrimary,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        fontWeight: fontWeight,
      );

  /// H2 : Titre de section majeure (ex: "PROGRAMME EN COURS", "PLANNING", "BIBLIOTHÈQUE")
  static TextStyle h2({
    Color? color,
    double fontSize = 20,
    double letterSpacing = 1.0,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.bebasNeue(
        color: color ?? AppColors.textPrimary,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        fontWeight: fontWeight,
      );

  /// H3 : Sous-titre de section, label de groupe ou en-tête de carte
  static TextStyle h3({
    Color? color,
    double fontSize = 16,
    double letterSpacing = 0.9,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.bebasNeue(
        color: color ?? AppColors.textSecondary,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        fontWeight: fontWeight,
      );

  /// Métrique clé : Affichage dynamique de valeur (ex: "85%", "12.4 km", "1:58", "SEMAINE 2")
  static TextStyle metric({
    Color? color,
    double fontSize = 28,
    double letterSpacing = 0.8,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      GoogleFonts.bebasNeue(
        color: color ?? AppColors.textPrimary,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        fontWeight: fontWeight,
      );

  // Alias rétrocompatibles
  static TextStyle bebasTitle({
    Color? color,
    double fontSize = 26,
    double letterSpacing = 1.2,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      h1(color: color, fontSize: fontSize, letterSpacing: letterSpacing, fontWeight: fontWeight);

  static TextStyle bebasSection({
    Color? color,
    double fontSize = 16,
    double letterSpacing = 1.1,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      h3(color: color, fontSize: fontSize, letterSpacing: letterSpacing, fontWeight: fontWeight);

  static TextStyle bebasCardTitle({
    Color? color,
    double fontSize = 20,
    double letterSpacing = 0.8,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      h2(color: color, fontSize: fontSize, letterSpacing: letterSpacing, fontWeight: fontWeight);

  static TextStyle bebasMetric({
    Color? color,
    double fontSize = 28,
    double letterSpacing = 0.8,
    FontWeight fontWeight = FontWeight.w400,
  }) =>
      metric(color: color, fontSize: fontSize, letterSpacing: letterSpacing, fontWeight: fontWeight);
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.dark);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme([Brightness brightness = Brightness.dark]) {
    const l0 = Color(0xFF0F1722);
    const l1 = Color(0xFF162032);
    const l2 = Color(0xFF1F2D44);
    const l3 = Color(0xFF2A3D5B);
    const txtPrimary = Color(0xFFF8FAFC);
    const txtSecondary = Color(0xFF94A3B8);
    const txtMuted = Color(0xFF64748B);

    final colorScheme = ColorScheme.dark(
      primary: const Color(0xFFFB7185),
      onPrimary: Colors.white,
      secondary: const Color(0xFFFB7185),
      onSecondary: Colors.white,
      surface: l0,
      onSurface: txtPrimary,
      surfaceContainerLowest: l0,
      surfaceContainerLow: l1,
      surfaceContainer: l1,
      surfaceContainerHigh: l2,
      surfaceContainerHighest: l3,
      error: const Color(0xFFF87171),
    );

    final borderlessInput = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

    final baseTextTheme = ThemeData.dark().textTheme;

    TextStyle bebas(double size, double spacing, [FontWeight weight = FontWeight.w400]) =>
        GoogleFonts.bebasNeue(
          color: txtPrimary,
          fontSize: size,
          letterSpacing: spacing,
          fontWeight: weight,
        );

    final appTextTheme = baseTextTheme.copyWith(
      displayLarge: bebas(57, 1.2),
      displayMedium: bebas(45, 1.1),
      displaySmall: bebas(36, 1.0),
      headlineLarge: bebas(32, 1.0),
      headlineMedium: bebas(28, 0.9),
      headlineSmall: bebas(24, 0.8),
      titleLarge: bebas(22, 0.8),
      titleMedium: bebas(18, 0.6),
      titleSmall: bebas(15, 0.6),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: txtPrimary),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: txtPrimary),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: txtSecondary),
      labelLarge: baseTextTheme.labelLarge?.copyWith(color: txtPrimary),
      labelMedium: baseTextTheme.labelMedium?.copyWith(color: txtSecondary),
      labelSmall: baseTextTheme.labelSmall?.copyWith(color: txtMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: appTextTheme,
      primaryTextTheme: appTextTheme,
      scaffoldBackgroundColor: l0,
      colorScheme: colorScheme,
      splashColor: l3.withValues(alpha: 0.4),
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: l0,
        foregroundColor: txtPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.bebasNeue(
          color: txtPrimary,
          fontSize: 26,
          letterSpacing: 1.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: l1,
        indicatorColor: const Color(0x33FB7185),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.bebasNeue(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.8,
            color: selected ? const Color(0xFFFB7185) : txtSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? const Color(0xFFFB7185) : txtSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: l1,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: l0,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.bebasNeue(
          color: txtPrimary,
          fontSize: 22,
          letterSpacing: 1.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: l0,
        modalBackgroundColor: l0,
        elevation: 0,
        modalElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: l2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: borderlessInput,
        enabledBorder: borderlessInput,
        focusedBorder: borderlessInput,
        errorBorder: borderlessInput,
        disabledBorder: borderlessInput,
        labelStyle: TextStyle(
          color: txtSecondary,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: txtMuted,
          fontSize: 13,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: l2,
        selectedColor: l3,
        disabledColor: l1,
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelStyle: TextStyle(
          color: txtPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: l2,
          foregroundColor: txtPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide.none,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: l1,
          selectedBackgroundColor: l3,
          foregroundColor: txtSecondary,
          selectedForegroundColor: txtPrimary,
          side: BorderSide.none,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: l2,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

/// Styles unifiés pour tous les boutons principaux (fond rose) de l'application.
class AppButtons {
  static const double radius = 14;

  static ButtonStyle primary({Color? backgroundColor}) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.rose,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static ButtonStyle compact({Color? backgroundColor}) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.rose,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      textStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
