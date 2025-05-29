import 'package:flutter/material.dart';

import '../../config.dart';

// Notification utility class for app-wide consistent notifications
class NotificationUtil {
  static void showTopOverlay(
      BuildContext context,
      String message, {
        Color backgroundColor = Colors.green,
        Duration duration = const Duration(seconds: 3),
      }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).viewPadding.top + kToolbarHeight + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  // Convenience wrappers
  static void showSuccess(BuildContext context, String message) {
    showTopOverlay(context, message, backgroundColor: Colors.green);
  }

  static void showError(BuildContext context, String message) {
    showTopOverlay(context, message, backgroundColor: Colors.red);
  }

  static void showWarning(BuildContext context, String message) {
    showTopOverlay(context, message, backgroundColor: Colors.orange);
  }

  static void showInfo(BuildContext context, String message) {
    showTopOverlay(context, message, backgroundColor: Colors.blue);
  }
}

class AppColors {
  // Light Theme Colors
  static const Color primaryLight = Color(0xFF2196F3);
  static const Color secondaryLight = Color(0xFF03A9F4);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surfaceLight = Colors.white;
  static const Color errorLight = Color(0xFFD32F2F);
  static const Color successLight = Color(0xFF4CAF50);
  static const Color warningLight = Color(0xFFFFA000);
  static const Color infoLight = Color(0xFF2196F3);

  // Dark Theme Colors
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color secondaryDark = Color(0xFF0288D1);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color errorDark = Color(0xFFEF5350);
  static const Color successDark = Color(0xFF66BB6A);
  static const Color warningDark = Color(0xFFFFB74D);
  static const Color infoDark = Color(0xFF42A5F5);

  // Action Colors
  static const Color clockIn = Color(0xFF4CAF50);
  static const Color clockOut = Color(0xFFD32F2F);
  static const Color offDay = Color(0xFF2196F3);
  static const Color export = Color(0xFF009688);
  static const Color import = Color(0xFFFF5722);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primaryLight,
    colorScheme: ColorScheme.light(
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      surface: AppColors.surfaceLight,
      background: AppColors.backgroundLight,
      error: AppColors.errorLight,
    ),
    cardTheme: CardTheme(
      color: AppColors.surfaceLight,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    extensions: [
      const CustomColors(
        // Light Theme Colors
        primaryLight: AppColors.primaryLight,
        secondaryLight: AppColors.secondaryLight,
        backgroundLight: AppColors.backgroundLight,
        surfaceLight: AppColors.surfaceLight,
        errorLight: AppColors.errorLight,
        successLight: AppColors.successLight,
        warningLight: AppColors.warningLight,
        infoLight: AppColors.infoLight,

        // Dark Theme Colors
        primaryDark: AppColors.primaryDark,
        secondaryDark: AppColors.secondaryDark,
        backgroundDark: AppColors.backgroundDark,
        surfaceDark: AppColors.surfaceDark,
        errorDark: AppColors.errorDark,
        successDark: AppColors.successDark,
        warningDark: AppColors.warningDark,
        infoDark: AppColors.infoDark,

        // Action Colors
        clockIn: AppColors.clockIn,
        clockOut: AppColors.clockOut,
        offDay: AppColors.offDay,
        export: AppColors.export,
        import: AppColors.import,
      ),
    ],
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primaryDark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primaryDark,
      secondary: AppColors.secondaryDark,
      surface: AppColors.surfaceDark,
      background: AppColors.backgroundDark,
      error: AppColors.errorDark,
    ),
    cardTheme: CardTheme(
      color: AppColors.surfaceDark,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    extensions: [
      const CustomColors(
        primaryLight: AppColors.primaryLight,
        secondaryLight: AppColors.secondaryLight,
        backgroundLight: AppColors.backgroundLight,
        surfaceLight: AppColors.surfaceLight,
        errorLight: AppColors.errorLight,
        successLight: AppColors.successLight,
        warningLight: AppColors.warningLight,
        infoLight: AppColors.infoLight,
        primaryDark: AppColors.primaryDark,
        secondaryDark: AppColors.secondaryDark,
        backgroundDark: AppColors.backgroundDark,
        surfaceDark: AppColors.surfaceDark,
        errorDark: AppColors.errorDark,
        successDark: AppColors.successDark,
        warningDark: AppColors.warningDark,
        infoDark: AppColors.infoDark,
        clockIn: AppColors.clockIn,
        clockOut: AppColors.clockOut,
        offDay: AppColors.offDay,
        export: AppColors.export,
        import: AppColors.import,
      ),
    ],
  );
}
