import 'package:flutter/material.dart';
import 'colors.dart';

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

  static const light = CustomColors(
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
    infoDark: AppColors.infoLight,
    clockIn: AppColors.clockIn,
    clockOut: AppColors.clockOut,
    offDay: AppColors.offDay,
    export: AppColors.export,
    import: AppColors.import,
  );

  static const dark = CustomColors(
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
  );
}

extension CustomColorsExtension on BuildContext {
  CustomColors get customColors => Theme.of(this).extension<CustomColors>()!;
}
