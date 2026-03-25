import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/language_provider.dart';
import '../services/profil_service.dart';
import '../services/language_service.dart';
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
        showBildirim(context, t('app.setting_saved'), tip: BildirimTip.bilgi);
      }
    } catch (e) {
      setState(() { _ayarlar = onceki; });
      if (mounted) {
        showBildirim(context, t('app.setting_save_failed'), basarili: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final kullanici = auth.kullanici;
    final ad = kullanici?.adSoyad ?? t('app.user');
    final email = kullanici?.email ?? '';
    final harf = ad.isNotEmpty ? ad[0].toUpperCase() : '?';
    _initAyarlar();

    return AppLayout(
      pageTitle: t('ui.settings'),
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
                              Text(
                                t('app.warehouse_user'),
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
                      t('app.app_settings'),
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
                    title: t('app.auto_unit'),
                    subtitle: t('app.auto_unit_desc'),
                    value: _ayarlar['birim_otomatik'] == true,
                    onChanged: (_) => _toggleAyar('birim_otomatik'),
                  ),

                  const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF9FAFB)),

                  // Barkod Okuma Sesi
                  _ToggleRow(
                    icon: Icons.volume_up,
                    gradColors: const [Color(0xFF10B981), Color(0xFF059669)],
                    title: t('app.barcode_sound'),
                    subtitle: t('app.barcode_sound_desc'),
                    value: _ayarlar['barkod_sesi'] != false,
                    onChanged: (_) => _toggleAyar('barkod_sesi'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dil Secimi
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    child: Text(
                      t('ui.language').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9CA3AF),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  ...LanguageService.availableLanguages.entries.map((entry) {
                    final langCode = entry.key;
                    final langName = entry.value;
                    final isSelected = ref.watch(languageProvider).currentLanguage == langCode;
                    final isLoading = ref.watch(languageProvider).loading;
                    return GestureDetector(
                      onTap: isLoading ? null : () async {
                        if (isSelected) return;
                        await ref.read(languageProvider.notifier).changeLanguage(langCode);
                        if (mounted) {
                          showBildirim(context, t('app.language_changed'), tip: BildirimTip.bilgi);
                          setState(() {}); // Rebuild to update all text
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? const [Color(0xFF6366F1), Color(0xFF8B5CF6)]
                                      : const [Color(0xFFE5E7EB), Color(0xFFD1D5DB)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  langCode.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                langName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF6366F1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 12),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
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
                    t('app.application'),
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
                      Text(t('app.version_label'), style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                      const Text('v2.0.0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t('app.system_label'), style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
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
                          Text(t('ui.active'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
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
                showBildirim(context, t('app.offline_no_logout'), tip: BildirimTip.hata);
              } : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(t('ui.sign_out')),
                    content: Text(t('app.confirm_logout')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(t('ui.cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(t('ui.sign_out'), style: const TextStyle(color: Colors.red)),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            t('ui.sign_out'),
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
                        Text(
                          t('app.offline_no_logout_short'),
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

            Text(
              t('app.app_system_name'),
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
