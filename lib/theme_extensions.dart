import 'package:flutter/material.dart';
import '../config.dart'; // or wherever your CustomColors is

extension CustomColorsExtension on BuildContext {
  CustomColors get customColors => Theme.of(this).extension<CustomColors>()!;
}
