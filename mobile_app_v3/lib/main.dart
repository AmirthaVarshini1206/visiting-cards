import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'providers/config_provider.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);

    return MaterialApp(
      title: 'SNAPCARD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: config.isDark ? Brightness.dark : Brightness.light,
        colorSchemeSeed: Colors.blueAccent,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: config.isDark ? Brightness.dark : Brightness.light).textTheme,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
