import 'package:flutter/material.dart';
import 'core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await App.initialize();
  runApp(const App());
}
