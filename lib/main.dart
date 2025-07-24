import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/simple_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ChippinApp());
}

class ChippinApp extends StatelessWidget {
  const ChippinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SimpleProvider(),
      child: MaterialApp(
        title: 'Chippin - Share Bills. Stay Chill.',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
