import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:provider/provider.dart';
import 'utils/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Firebase DULU
  await Firebase.initializeApp();
  
  // 2. Baru set auth settings (setelah Firebase init)
  await FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
  
  // 3. Init locale
  await initializeDateFormatting('id_ID', null);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Keuangan Harian',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
        },
      ),
      // routes: {
      //   '/': (context) => const DashboardScreen(),
      //   '/login': (context) => const LoginScreen(),
      //   '/budget-settings': (context) => const BudgetSettingsScreen(),
      //   '/wallets': (context) => const WalletScreen(),
      //   '/recurring': (context) => const RecurringScreen(),
      // },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) return const DashboardScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}