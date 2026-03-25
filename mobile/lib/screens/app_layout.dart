import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';

class AppLayout extends ConsumerWidget {
  final Widget child;
  final String? pageTitle;
  final bool showSettings;
  final bool showBack;
  final Widget? floatingActionButton;
  final VoidCallback? onHeaderAction;
  final IconData? headerActionIcon;
  final Color? pageTitleColor;

  const AppLayout({
    super.key,
    required this.child,
    this.pageTitle,
    this.showSettings = false,
    this.showBack = false,
    this.floatingActionButton,
    this.onHeaderAction,
    this.headerActionIcon,
    this.pageTitleColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final kullanici = auth.kullanici;
    final ad = kullanici?.adSoyad ?? 'Kullanici';
    final rol = kullanici?.rol == 'admin' ? 'Yonetici' : 'Depo Kullanicisi';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          // Purple gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6C53F5), Color(0xFF8B5CF6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x406C53F5),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Row(
                  children: [
                    // Back button or user avatar
                    if (showBack)
                      GestureDetector(
                        onTap: () => context.canPop() ? context.pop() : context.go('/'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => context.go('/'),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    // User name (home) or page title (sub pages)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.go('/'),
                        child: showBack
                            ? Text(
                                pageTitle ?? '',
                                style: TextStyle(
                                  color: pageTitleColor ?? Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ad,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    rol,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    // Home button (alt sayfalarda)
                    if (showBack)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => context.go('/'),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.home, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    // Header action button (add, settings, etc.)
                    if (onHeaderAction != null)
                      Padding(
                        padding: EdgeInsets.only(right: showSettings ? 8 : 0),
                        child: GestureDetector(
                          onTap: onHeaderAction,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(headerActionIcon ?? Icons.add, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    // Settings button (only on home)
                    if (showSettings)
                      GestureDetector(
                        onTap: () => context.push('/ayarlar'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.settings, color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Offline mod badge
          if (ref.watch(connectivityProvider).offlineMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.orange.withValues(alpha: 0.15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'ÇEVRİMDIŞI MOD',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (ref.watch(connectivityProvider).bekleyenSync > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${ref.watch(connectivityProvider).bekleyenSync}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // Page content
          Expanded(child: child),
        ],
      ),
    );
  }
}
