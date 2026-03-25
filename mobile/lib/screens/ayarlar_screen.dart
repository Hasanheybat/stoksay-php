import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/profil_service.dart';
import '../widgets/bildirim.dart';
import 'app_layout.dart';

const _P = Color(0xFF6C53F5);

class AyarlarScreen extends ConsumerStatefulWidget {
  const AyarlarScreen({super.key});

  @override
  ConsumerState<AyarlarScreen> createState() => _AyarlarScreenState();
}

class _AyarlarScreenState extends ConsumerState<AyarlarScreen> {
  late Map<String, dynamic> _ayarlar;
  bool _initialized = false;

  void _initAyarlar() {
    if (_initialized) return;
    final kullanici = ref.read(authProvider).kullanici;
    _ayarlar = Map<String, dynamic>.from(kullanici?.ayarlar ?? {});
    _initialized = true;
  }

  Future<void> _toggleAyar(String key) async {
    final onceki = Map<String, dynamic>.from(_ayarlar);
    setState(() {
      _ayarlar[key] = !(_ayarlar[key] == true);
    });
    try {
      await ProfilService.ayarlarGuncelle({'ayarlar': _ayarlar});
      // AuthProvider state'ini de güncelle (web app'teki setKullanici gibi)
      ref.read(authProvider.notifier).ayarlarGuncelle(Map<String, dynamic>.from(_ayarlar));
      if (mounted) {
        showBildirim(context, 'Ayar kaydedildi', tip: BildirimTip.bilgi);
      }
    } catch (e) {
      setState(() { _ayarlar = onceki; });
      if (mounted) {
        showBildirim(context, 'Ayar kaydedilemedi', basarili: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final kullanici = auth.kullanici;
    final ad = kullanici?.adSoyad ?? 'Kullanıcı';
    final email = kullanici?.email ?? '';
    final harf = ad.isNotEmpty ? ad[0].toUpperCase() : '?';
    _initAyarlar();

    return AppLayout(
      pageTitle: 'Ayarlar',
      showBack: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hesap Kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        harf,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ad,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield, size: 12, color: const Color(0xFF6366F1)),
                              const SizedBox(width: 4),
                              const Text(
                                'Depo Kullanıcısı',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6366F1),
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

            const SizedBox(height: 16),

            // Uygulama Ayarları
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    child: Text(
                      'UYGULAMA AYARLARI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9CA3AF),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),

                  // Birim Otomatik Gelsin
                  _ToggleRow(
                    icon: Icons.flash_on,
                    gradColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    title: 'Birim Otomatik Gelsin',
                    subtitle: 'Açık: Birim direkt kaydedilir, onay gerekmez',
                    value: _ayarlar['birim_otomatik'] == true,
                    onChanged: (_) => _toggleAyar('birim_otomatik'),
                  ),

                  const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF9FAFB)),

                  // Barkod Okuma Sesi
                  _ToggleRow(
                    icon: Icons.volume_up,
                    gradColors: const [Color(0xFF10B981), Color(0xFF059669)],
                    title: 'Barkod Okuma Sesi',
                    subtitle: 'Barkod okunduğunda bip sesi çıkar',
                    value: _ayarlar['barkod_sesi'] != false,
                    onChanged: (_) => _toggleAyar('barkod_sesi'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Uygulama Bilgisi
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UYGULAMA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9CA3AF),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Versiyon', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                      const Text('v2.0.0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sistem', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Aktif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Çıkış Yap butonu
            Builder(builder: (context) {
              final isOffline = ref.watch(connectivityProvider).offlineMode;
              return GestureDetector(
              onTap: isOffline ? () {
                showBildirim(context, 'Çevrimdışı modda çıkış yapamazsınız. Önce verileri senkronize edin.', tip: BildirimTip.hata);
              } : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Çıkış Yap'),
                    content: const Text('Oturumunuzu kapatmak istediğinize emin misiniz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(authProvider.notifier).cikisYap();
                  if (context.mounted) context.go('/login');
                }
              },
              child: Opacity(
                opacity: isOffline ? 0.4 : 1.0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Çıkış Yap',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (isOffline) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Çevrimdışı modda çıkış yapılamaz',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
            }),

            const SizedBox(height: 12),

            const Text(
              'StokSay Depo Sayım Sistemi',
              style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final List<Color> gradColors;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.gradColors,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradColors),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _Toggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 24,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF6366F1) : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
