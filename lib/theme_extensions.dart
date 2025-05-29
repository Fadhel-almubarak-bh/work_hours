import 'package:flutter/material.dart';
import 'core/theme/theme_extensions.dart';

extension CustomColorsExtension on BuildContext {
  CustomColors get customColors {
    final extension = Theme.of(this).extension<CustomColors>();
    if (extension == null) {
      throw FlutterError('CustomColors extension not found. Make sure it is registered in the theme.');
    }
    return extension;
  }
}
