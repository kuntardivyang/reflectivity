import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/survey/survey_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ReflectScanApp()));
}

class ReflectScanApp extends StatelessWidget {
  const ReflectScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReflectScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SurveyScreen(),
    );
  }
}
