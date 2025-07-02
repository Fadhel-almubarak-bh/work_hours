import 'package:flutter/material.dart';
import 'core/app.dart';
import 'package:home_widget/home_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerBackgroundCallback(interactiveCallback);
  await App.initialize();
  runApp(const App());
}
