import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/connectivity_provider.dart';

class ShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const ShellScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Offline banner
          if (!connectivity.online)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.orange.shade700,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Çevrimdışı mod',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          // Sync pending banner
          if (connectivity.online && connectivity.bekleyenSync > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.blue.shade600,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${connectivity.bekleyenSync} bekleyen senkronizasyon',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: (index) {
              widget.navigationShell.goBranch(
                index,
                initialLocation: index == widget.navigationShell.currentIndex,
              );
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 65,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Ana Sayfa',
              ),
              const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Stoklar',
              ),
              const NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: 'Sayımlar',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Ayarlar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
