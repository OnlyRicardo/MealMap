import 'package:material_ui/material_ui.dart';

import '../features/shell/home_shell.dart';

class MealMapApp extends StatelessWidget {
  const MealMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MealMap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8590C)),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
