import 'package:flutter/material.dart';
import 'package:tiba_pay/screens/auth/login_screen.dart';
import 'package:tiba_pay/screens/auth/splash_screen.dart';
import 'package:tiba_pay/screens/home/home_screen.dart';
import 'package:tiba_pay/utils/database_helper.dart';

import 'models/user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database; // Initialize database
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TibaPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => HomeScreen(
              user: ModalRoute.of(context)!.settings.arguments as User,
            ),
      },
    );
  }
}