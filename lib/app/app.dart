import 'package:flutter/material.dart';

import '../features/map/map_screen.dart';

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
      home: const MapScreen(),
    );
  }
}
