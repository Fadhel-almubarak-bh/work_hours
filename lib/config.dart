import 'package:flutter/material.dart';

// Notification utility class for app-wide consistent notifications
// class NotificationUtil {
//   // Show a notification at the top of the screen
//   static void showTopSnackBar(
//     BuildContext context,
//     String message, {
//     Color backgroundColor = AppColors.successLight,
//     Duration duration = const Duration(seconds: 3),
//     SnackBarAction? action,
//   }) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: backgroundColor,
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
//         elevation: 6.0,
//         duration: duration,
//         action: action,
//       ),
//     );
//   }
//
//   // Helper methods for common notification types
//   static void showSuccess(BuildContext context, String message) {
//     showTopSnackBar(context, message, backgroundColor: AppColors.successLight);
//   }
//
//   static void showError(BuildContext context, String message) {
//     showTopSnackBar(context, message, backgroundColor: AppColors.errorLight);
//   }
//
//   static void showWarning(BuildContext context, String message) {
//     showTopSnackBar(context, message, backgroundColor: AppColors.warningLight);
//   }
//
//   static void showInfo(BuildContext context, String message) {
//     showTopSnackBar(context, message, backgroundColor: AppColors.infoLight);
//   }
// }
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

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  // Light Theme Colors
  final Color primaryLight;
  final Color secondaryLight;
  final Color backgroundLight;
  final Color surfaceLight;
  final Color errorLight;
  final Color successLight;
  final Color warningLight;
  final Color infoLight;

  // Dark Theme Colors
  final Color primaryDark;
  final Color secondaryDark;
  final Color backgroundDark;
  final Color surfaceDark;
  final Color errorDark;
  final Color successDark;
  final Color warningDark;
  final Color infoDark;

  // Action Colors
  final Color clockIn;
  final Color clockOut;
  final Color offDay;
  final Color export;
  final Color import;

  const CustomColors({
    // Light
    required this.primaryLight,
    required this.secondaryLight,
    required this.backgroundLight,
    required this.surfaceLight,
    required this.errorLight,
    required this.successLight,
    required this.warningLight,
    required this.infoLight,
    // Dark
    required this.primaryDark,
    required this.secondaryDark,
    required this.backgroundDark,
    required this.surfaceDark,
    required this.errorDark,
    required this.successDark,
    required this.warningDark,
    required this.infoDark,
    // Actions
    required this.clockIn,
    required this.clockOut,
    required this.offDay,
    required this.export,
    required this.import,
  });

  @override
  CustomColors copyWith({
    Color? primaryLight,
    Color? secondaryLight,
    Color? backgroundLight,
    Color? surfaceLight,
    Color? errorLight,
    Color? successLight,
    Color? warningLight,
    Color? infoLight,
    Color? primaryDark,
    Color? secondaryDark,
    Color? backgroundDark,
    Color? surfaceDark,
    Color? errorDark,
    Color? successDark,
    Color? warningDark,
    Color? infoDark,
    Color? clockIn,
    Color? clockOut,
    Color? offDay,
    Color? export,
    Color? import,
  }) {
    return CustomColors(
      primaryLight: primaryLight ?? this.primaryLight,
      secondaryLight: secondaryLight ?? this.secondaryLight,
      backgroundLight: backgroundLight ?? this.backgroundLight,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      errorLight: errorLight ?? this.errorLight,
      successLight: successLight ?? this.successLight,
      warningLight: warningLight ?? this.warningLight,
      infoLight: infoLight ?? this.infoLight,
      primaryDark: primaryDark ?? this.primaryDark,
      secondaryDark: secondaryDark ?? this.secondaryDark,
      backgroundDark: backgroundDark ?? this.backgroundDark,
      surfaceDark: surfaceDark ?? this.surfaceDark,
      errorDark: errorDark ?? this.errorDark,
      successDark: successDark ?? this.successDark,
      warningDark: warningDark ?? this.warningDark,
      infoDark: infoDark ?? this.infoDark,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      offDay: offDay ?? this.offDay,
      export: export ?? this.export,
      import: import ?? this.import,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) return this;

    return CustomColors(
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      secondaryLight: Color.lerp(secondaryLight, other.secondaryLight, t)!,
      backgroundLight: Color.lerp(backgroundLight, other.backgroundLight, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      errorLight: Color.lerp(errorLight, other.errorLight, t)!,
      successLight: Color.lerp(successLight, other.successLight, t)!,
      warningLight: Color.lerp(warningLight, other.warningLight, t)!,
      infoLight: Color.lerp(infoLight, other.infoLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      secondaryDark: Color.lerp(secondaryDark, other.secondaryDark, t)!,
      backgroundDark: Color.lerp(backgroundDark, other.backgroundDark, t)!,
      surfaceDark: Color.lerp(surfaceDark, other.surfaceDark, t)!,
      errorDark: Color.lerp(errorDark, other.errorDark, t)!,
      successDark: Color.lerp(successDark, other.successDark, t)!,
      warningDark: Color.lerp(warningDark, other.warningDark, t)!,
      infoDark: Color.lerp(infoDark, other.infoDark, t)!,
      clockIn: Color.lerp(clockIn, other.clockIn, t)!,
      clockOut: Color.lerp(clockOut, other.clockOut, t)!,
      offDay: Color.lerp(offDay, other.offDay, t)!,
      export: Color.lerp(export, other.export, t)!,
      import: Color.lerp(import, other.import, t)!,
    );
  }
}
