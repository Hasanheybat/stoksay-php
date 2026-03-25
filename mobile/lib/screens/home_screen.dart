import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/isletme_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/sync_result_dialog.dart';
import '../widgets/bildirim.dart';
import 'app_layout.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  bool _syncing = false;
  bool _syncDone = false;
  bool _yetkiYok = false;
  String _syncStats = '';
  bool _cacheBildirimGosterildi = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncData());
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _syncData() async {
    if (_syncing) return;
    final connectivity = ref.read(connectivityProvider);

    if (connectivity.offlineMode) {
      // Offline moddayken verileri güncelle devre dışı
      return;
    }

    setState(() {
      _syncing = true;
      _syncDone = false;
      _yetkiYok = false;
      _syncStats = '';
    });

    try {
      await ref.read(authProvider.notifier).oturumKontrol();

      // Pasif kullanıcı kontrolü — 403 alındıysa build() pasif ekranı gösterecek
      final authCheck = ref.read(authProvider);
      if (authCheck.pasif) {
        setState(() { _syncing = false; });
        return;
      }

      await ref.read(isletmeProvider.notifier).yukle();
      final isletme = ref.read(isletmeProvider);

      // Yetki kontrolü
      final authN = ref.read(authProvider.notifier);
      final auth = ref.read(authProvider);
      final isAdm = auth.kullanici?.rol == 'admin';
      final hasPerms = isAdm ||
          authN.hasYetki('urun', 'goruntule') ||
          authN.hasYetki('sayim', 'goruntule') ||
          authN.hasYetki('depo', 'goruntule') ||
          authN.hasYetki('toplam_sayim', 'goruntule');

      if (hasPerms) {
        // Yetki atanmış — atanan yetkileri listele
        final yetkiListesi = <String>[];
        if (authN.hasYetki('urun', 'goruntule')) yetkiListesi.add(t('ui.stocks'));
        if (authN.hasYetki('sayim', 'goruntule')) yetkiListesi.add(t('ui.counts'));
        if (authN.hasYetki('depo', 'goruntule')) yetkiListesi.add(t('ui.warehouses'));
        if (authN.hasYetki('toplam_sayim', 'goruntule')) yetkiListesi.add(t('ui.collected_counts'));
        setState(() {
          _syncing = false;
          _syncDone = true;
          _syncStats = isAdm
              ? t('app.admin_all_perms')
              : '${t("app.permissions")}: ${yetkiListesi.join(", ")}';
        });
      } else {
        // Hâlâ yetki yok
        setState(() {
          _syncing = false;
          _syncDone = false;
          _yetkiYok = true;
          _syncStats = t('app.no_permission_assigned');
        });
        return;
      }

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _syncDone = false);
      });
    } catch (_) {
      setState(() {
        _syncing = false;
        _syncStats = t('app.sync_failed_short');
      });
    }
  }

  Future<void> _verileriGuncelle() async {
    final connectivity = ref.read(connectivityProvider);
    if (!connectivity.online) {
      if (mounted) {
        showBildirim(context, t('app.no_internet'), basarili: false);
      }
      return;
    }

    setState(() {
      _syncing = true;
      _syncStats = t('app.updating_data');
    });

    try {
      final isletmeler = ref.read(isletmeProvider).isletmeler;
      final result = await ref.read(connectivityProvider.notifier).verileriGuncelle(isletmeler);

      setState(() {
        _syncing = false;
        _syncDone = true;
        _syncStats = t('app.update_complete');
      });

      if (mounted) {
        await SyncResultDialog.show(context, result);
      }

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _syncDone = false);
      });
    } catch (e) {
      setState(() {
        _syncing = false;
        _syncStats = t('app.update_failed');
      });
      if (mounted) {
        showBildirim(context, 'Güncelleme hatası: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}', basarili: false);
      }
    }
  }

  Future<void> _toggleOfflineMode() async {
    final connectivity = ref.read(connectivityProvider);

    if (connectivity.offlineMode) {
      // ── Online moda dön: otomatik push + pull ──
      if (!connectivity.online) {
        if (mounted) {
          showBildirim(context, t('app.internet_needed_online'), basarili: false);
        }
        return;
      }

      final bekleyen = connectivity.bekleyenSync;
      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(t('app.switch_online'), style: TextStyle(color: Colors.white)),
          content: Text(
            bekleyen > 0
                ? t('app.pending_ops_confirm').replaceAll('{count}', '$bekleyen')
                : t('app.online_switch_confirm'),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('ui.cancel'), style: const TextStyle(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('app.continue_btn'), style: const TextStyle(color: Colors.orange))),
          ],
        ),
      );
      if (onay != true) return;

      setState(() {
        _syncing = true;
        _syncStats = bekleyen > 0 ? t('app.sending_data') : t('app.pulling_data');
      });

      try {
        final isletmeler = ref.read(isletmeProvider).isletmeler;
        final result = await ref.read(connectivityProvider.notifier).exitOfflineMode(isletmeler);

        setState(() {
          _syncing = false;
          _syncDone = true;
          _syncStats = t('app.switched_online');
        });

        if (mounted) {
          if (result.basarili > 0 || result.basarisiz > 0) {
            await SyncResultDialog.show(context, result);
          } else {
            showBildirim(context, t('app.switched_online'));
          }
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _syncDone = false);
        });
      } catch (e) {
        setState(() {
          _syncing = false;
          _syncStats = t('app.switch_failed');
        });
        if (mounted) {
          showBildirim(context, 'Geçiş hatası: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}', basarili: false);
        }
      }
    } else {
      // ── Offline moda geç: veri indir ──
      if (!connectivity.online) {
        if (mounted) {
          showBildirim(context, t('app.internet_needed_offline'), basarili: false);
        }
        return;
      }

      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(t('app.switch_offline'), style: TextStyle(color: Colors.white)),
          content: Text(
            t('app.offline_download_confirm'),
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('ui.cancel'), style: const TextStyle(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('app.continue_btn'), style: const TextStyle(color: Color(0xFF6C53F5)))),
          ],
        ),
      );
      if (onay != true) return;

      setState(() {
        _syncing = true;
        _syncStats = t('app.downloading_data');
      });

      try {
        final isletmeler = ref.read(isletmeProvider).isletmeler;
        final stats = await ref.read(connectivityProvider.notifier).enterOfflineMode(isletmeler);
        setState(() {
          _syncing = false;
          _syncDone = true;
          _syncStats = stats.toString();
        });
        if (mounted) {
          showBildirim(context, '✓ ${stats.toString()}', sure: 4);
        }
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _syncDone = false);
        });
      } catch (_) {
        setState(() {
          _syncing = false;
          _syncStats = t('app.download_failed');
        });
      }
    }
  }

  void _showIsletmeler() {
    final isletme = ref.read(isletmeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _IsletmelerSheet(
        isletmeler: isletme.isletmeler,
        seciliId: isletme.secili?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.cacheFallback && !_cacheBildirimGosterildi) {
      _cacheBildirimGosterildi = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showBildirim(context, 'Cevrimdisi veri gosteriliyor', tip: BildirimTip.bilgi);
        }
      });
    }

    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.offlineMode;
    final hasPending = connectivity.bekleyenSync > 0;

    // Offline modda "Verileri Güncelle" daima pasif
    final syncEnabled = !isOffline;

    // ── PASİF KULLANICI EKRANI ──
    if (auth.pasif) {
      return Scaffold(
        backgroundColor: const Color(0xFF121020),
        body: Column(
          children: [
            // Dark header
            Container(
              color: const Color(0xFF1A1730),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            (auth.kullanici?.adSoyad ?? '?').isNotEmpty
                                ? (auth.kullanici?.adSoyad ?? '?')[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.kullanici?.adSoyad ?? t('app.user'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              t('app.account_passive'),
                              style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // İçerik
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1730),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4), width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ünlem ikonu
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 42),
                        ),
                        const SizedBox(height: 22),
                        // Başlık
                        Text(
                          t('app.account_deactivated'),
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        // Açıklama
                        Text(
                          'Hesabınız yönetici tarafından pasife alınmıştır. Sisteme erişiminiz geçici olarak durdurulmuştur.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 15.5, height: 1.5),
                        ),
                        const SizedBox(height: 22),
                        // Admin iletişim notu
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.support_agent, color: Color(0xFFFCA5A5), size: 19),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Lütfen yöneticinizle iletişime geçin.',
                                  style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Çıkış yap butonu
                        GestureDetector(
                          onTap: () async {
                            await ref.read(authProvider.notifier).cikisYap();
                            if (context.mounted) context.go('/login');
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout, color: Colors.white60, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Çıkış Yap',
                                  style: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Kullanıcının herhangi bir yetkisi var mı?
    final authNotifier = ref.read(authProvider.notifier);
    final isAdmin = auth.kullanici?.rol == 'admin';
    final hasAnyPermission = isAdmin ||
        authNotifier.hasYetki('urun', 'goruntule') ||
        authNotifier.hasYetki('sayim', 'goruntule') ||
        authNotifier.hasYetki('depo', 'goruntule') ||
        authNotifier.hasYetki('toplam_sayim', 'goruntule');

    if (hasAnyPermission) {
      return AppLayout(
        showSettings: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Verileri Güncelle button (normal)
              GestureDetector(
                onTap: syncEnabled ? _syncData : null,
                child: Opacity(
                  opacity: syncEnabled ? 1.0 : 0.5,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _syncDone
                                ? const Color(0xFF10B981)
                                : isOffline
                                    ? Colors.orange
                                    : const Color(0xFF6C53F5),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (_syncDone
                                        ? const Color(0xFF10B981)
                                        : isOffline
                                            ? Colors.orange
                                            : const Color(0xFF6C53F5))
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _syncing
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Icon(
                                  _syncDone ? Icons.check : Icons.sync,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _syncing
                                    ? 'Güncelleniyor...'
                                    : _syncDone
                                        ? 'Tamamlandı!'
                                        : 'Verileri Güncelle',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _syncStats.isNotEmpty
                                    ? _syncStats
                                    : isOffline
                                        ? 'Çevrimiçi moda dönünce aktif olur'
                                        : 'Tüm verileri senkronize et',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOffline
                                ? Colors.orange
                                : connectivity.online
                                    ? (_syncDone ? const Color(0xFF10B981) : const Color(0xFF6C53F5))
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Offline Mod Toggle button
              GestureDetector(
                onTap: _syncing ? null : _toggleOfflineMode,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isOffline
                        ? Colors.orange.withValues(alpha: 0.1)
                        : const Color(0xFF6C53F5).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOffline
                          ? Colors.orange.withValues(alpha: 0.3)
                          : const Color(0xFF6C53F5).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOffline ? Icons.wifi : Icons.wifi_off,
                        color: isOffline ? Colors.orange : const Color(0xFF6C53F5),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isOffline ? t('app.switch_online') : t('app.switch_offline'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isOffline ? Colors.orange.shade700 : const Color(0xFF6C53F5),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: isOffline ? Colors.orange.withValues(alpha: 0.5) : const Color(0xFF6C53F5).withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Grid Cards
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _NavCard(
                      icon: Icons.business,
                      label: t('ui.businesses'),
                      onTap: _showIsletmeler,
                    ),
                    if (authNotifier.hasYetki('urun', 'goruntule'))
                      _NavCard(
                        icon: Icons.inventory_2,
                        label: t('ui.stocks'),
                        onTap: () => context.push('/stoklar'),
                      ),
                    if (authNotifier.hasYetki('sayim', 'goruntule'))
                      _NavCard(
                        icon: Icons.assignment,
                        label: t('ui.counts'),
                        onTap: () => context.push('/sayimlar'),
                      ),
                    if (authNotifier.hasYetki('depo', 'goruntule'))
                      _NavCard(
                        icon: Icons.warehouse,
                        label: t('ui.warehouses'),
                        onTap: () => context.push('/depolar'),
                      ),
                    if (authNotifier.hasYetki('toplam_sayim', 'goruntule'))
                      _NavCard(
                        icon: Icons.calculate,
                        label: 'Toplam Sayımlar',
                        onTap: () => context.push('/toplanmis-sayimlar'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── YETKİSİZ KULLANICI — DARK EKRAN ──
    return Scaffold(
      backgroundColor: const Color(0xFF121020),
      body: Column(
        children: [
          // Dark header
          Container(
            color: const Color(0xFF1A1730),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          (auth.kullanici?.adSoyad ?? '?').isNotEmpty
                              ? (auth.kullanici?.adSoyad ?? '?')[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.kullanici?.adSoyad ?? t('app.user'),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Depo Kullanıcısı',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Verileri Güncelle button (dark + glow)
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glow = _glowController.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GestureDetector(
                  onTap: _syncData,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1730),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3 + glow * 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.05 + glow * 0.15),
                          blurRadius: 8 + glow * 12,
                          spreadRadius: glow * 2,
                        ),
                      ],
                    ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _yetkiYok
                            ? const Color(0xFFDC2626)
                            : _syncDone
                                ? const Color(0xFF10B981)
                                : Colors.orange,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_yetkiYok
                                ? const Color(0xFFDC2626)
                                : _syncDone
                                    ? const Color(0xFF10B981)
                                    : Colors.orange).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _syncing
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Icon(
                              _yetkiYok ? Icons.error_outline : (_syncDone ? Icons.check : Icons.sync),
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _syncing
                                ? 'Güncelleniyor...'
                                : _yetkiYok
                                    ? 'Yetki Atanmadı'
                                    : _syncDone
                                        ? 'Tamamlandı!'
                                        : 'Verileri Güncelle',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _yetkiYok ? const Color(0xFFFCA5A5) : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _syncStats.isNotEmpty ? _syncStats : 'Yetki atandıktan sonra buraya basın',
                            style: TextStyle(fontSize: 12, color: _yetkiYok ? const Color(0xFFFCA5A5).withValues(alpha: 0.6) : Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _yetkiYok
                            ? const Color(0xFFDC2626)
                            : connectivity.online
                                ? (_syncDone ? const Color(0xFF10B981) : Colors.orange)
                                : Colors.red,
                      ),
                    ),
                  ],
                ), // Row
              ), // Container
            ), // GestureDetector
              ); // Padding — return
              }, // builder
            ), // AnimatedBuilder
            const SizedBox(height: 32),

            // Yetki yok — uyarı ekranı
            Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1730),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // İkon
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.lock_outline, color: Colors.orange, size: 38),
                        ),
                        const SizedBox(height: 22),
                        // Başlık
                        Text(
                          'Yetki Atanmamış',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        // Açıklama
                        Text(
                          'Hesabınıza henüz herhangi bir işletme yetkisi atanmamış. Yöneticinizle iletişime geçin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 15.5, height: 1.5),
                        ),
                        const SizedBox(height: 22),
                        // Bilgi notu
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange, size: 19),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Yetki atandıktan sonra yukarıdaki güncelle butonuna basarak verileri yenileyebilirsiniz.',
                                  style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }
}

// Navigation card widget
class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C53F5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: const Color(0xFF6C53F5), size: 26),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Isletmeler bottom sheet
class _IsletmelerSheet extends StatelessWidget {
  final List isletmeler;
  final String? seciliId;

  const _IsletmelerSheet({
    required this.isletmeler,
    required this.seciliId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.business, color: Color(0xFF6C53F5), size: 20),
                const SizedBox(width: 8),
                Text(t('ui.businesses'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: isletmeler.length,
              itemBuilder: (context, index) {
                final i = isletmeler[index];
                final selected = i.id == seciliId;

                final colors = [
                  [const Color(0xFF6C53F5), const Color(0xFF8B5CF6)],
                  [const Color(0xFF0EA5E9), const Color(0xFF2563EB)],
                  [const Color(0xFF10B981), const Color(0xFF059669)],
                  [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  [const Color(0xFFEC4899), const Color(0xFFDB2777)],
                ];
                final gradColors = colors[index % colors.length];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF6C53F5).withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? Border.all(color: const Color(0xFF6C53F5).withValues(alpha: 0.3))
                        : Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradColors),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.ad, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1F2937))),
                            if (i.kod != null && i.kod!.isNotEmpty)
                              Text(i.kod!, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
