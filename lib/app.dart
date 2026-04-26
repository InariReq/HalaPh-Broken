import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'db/local_db.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await LocalDb.instance.init();
  runApp(const HalaPhApp());
}

class HalaPhApp extends StatelessWidget {
  const HalaPhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HalaPH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0066FF),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}