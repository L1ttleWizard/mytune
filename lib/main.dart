import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/player_service.dart';
import 'services/tab_switcher.dart';

void main() {
  runApp(const MyTuneApp());
}

class MyTuneApp extends StatelessWidget {
  const MyTuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..load()),
        ChangeNotifierProvider(create: (_) => PlayerService()),
        ChangeNotifierProvider(create: (_) => TabSwitcher()),
      ],
      child: MaterialApp(
        title: 'MyTune',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1DB954),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
