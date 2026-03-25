import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stoklar_screen.dart';
import 'screens/sayimlar_screen.dart';
import 'screens/depolar_screen.dart';
import 'screens/ayarlar_screen.dart';
import 'screens/yeni_sayim_screen.dart';
import 'screens/sayim_detay_screen.dart';
import 'screens/urun_ekle_screen.dart';
import 'screens/toplanmis_sayimlar_screen.dart';
import 'services/storage_service.dart';

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final loggedIn = StorageService.hasToken;
    final isLoginRoute = state.matchedLocation == '/login';

    // Token yoksa ve login sayfasında değilse → login'e yönlendir
    if (!loggedIn && !isLoginRoute) return '/login';
    // Token varsa ve login sayfasındaysa → ana sayfaya yönlendir
    if (loggedIn && isLoginRoute) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/stoklar', builder: (context, state) => const StoklarScreen()),
    GoRoute(path: '/sayimlar', builder: (context, state) => const SayimlarScreen()),
    GoRoute(path: '/depolar', builder: (context, state) => const DepolarScreen()),
    GoRoute(path: '/ayarlar', builder: (context, state) => const AyarlarScreen()),
    GoRoute(path: '/yeni-sayim', builder: (context, state) => const YeniSayimScreen()),
    GoRoute(path: '/sayim/:sayimId', builder: (context, state) => SayimDetayScreen(sayimId: state.pathParameters['sayimId']!)),
    GoRoute(path: '/sayim/:sayimId/urun-ekle', builder: (context, state) => UrunEkleScreen(sayimId: state.pathParameters['sayimId']!)),
    GoRoute(path: '/toplanmis-sayimlar', builder: (context, state) => const ToplanmisSayimlarScreen()),
  ],
);

class StokSayApp extends ConsumerWidget {
  const StokSayApp({super.key});

  static const Color primaryColor = Color(0xFF6C53F5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'StokSay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: primaryColor,
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      routerConfig: _router,
    );
  }
}
