import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/isletme_provider.dart';
import '../models/isletme.dart';
import '../services/sayim_service.dart';
import '../widgets/bildirim.dart';
import 'app_layout.dart';

const _primary = Color(0xFF6C53F5);
const _primaryLight = Color(0x1A6C53F5);

const _grads = [
  [Color(0xFF6C53F5), Color(0xFF8B5CF6)],
  [Color(0xFF0EA5E9), Color(0xFF2563EB)],
  [Color(0xFF10B981), Color(0xFF059669)],
  [Color(0xFFF59E0B), Color(0xFFD97706)],
  [Color(0xFFEC4899), Color(0xFFDB2777)],
];

class ToplanmisSayimlarScreen extends ConsumerStatefulWidget {
  const ToplanmisSayimlarScreen({super.key});

  @override
  ConsumerState<ToplanmisSayimlarScreen> createState() =>
      _ToplanmisSayimlarScreenState();
}

class _ToplanmisSayimlarScreenState
    extends ConsumerState<ToplanmisSayimlarScreen> {
  List<Isletme> _isletmeler = [];
  String? _seciliIsletmeId;
  List<Map<String, dynamic>> _sayimlar = [];
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIsletmeler());
  }

  Future<void> _fetchIsletmeler() async {
    final isletmeState = ref.read(isletmeProvider);
    final auth = ref.read(authProvider.notifier);
    final list = isletmeState.isletmeler
        .where((i) => auth.isletmeYetkisi(i.id, 'toplam_sayim', 'goruntule'))
        .toList();
    setState(() {
      _isletmeler = list;
      if (list.isNotEmpty) _seciliIsletmeId = list.first.id;
    });
    if (_seciliIsletmeId != null) _fetch();
  }

  Future<void> _fetch() async {
    if (_seciliIsletmeId == null) return;
    setState(() => _yukleniyor = true);
    try {
      final data = await SayimService.toplanmisListele(_seciliIsletmeId!);
      if (mounted) setState(() => _sayimlar = data);
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  Isletme? get _seciliIsletme =>
      _isletmeler.where((i) => i.id == _seciliIsletmeId).firstOrNull;

  void _showIsletmePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.business, color: _primary, size: 20),
                  SizedBox(width: 8),
                  Text('İşletme Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _isletmeler.length,
                itemBuilder: (_, i) {
                  final ist = _isletmeler[i];
                  final secili = ist.id == _seciliIsletmeId;
                  final grad = _grads[i % _grads.length];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _seciliIsletmeId = ist.id);
                      _fetch();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: secili ? _primaryLight : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: secili ? _primary.withValues(alpha: 0.25) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: grad),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(ist.ad.isNotEmpty ? ist.ad[0] : '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(ist.ad, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1F2937))),
                          ),
                          if (secili)
                            Container(
                              width: 20, height: 20,
                              decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                              child: const Icon(Icons.check, color: Colors.white, size: 12),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _parseKaynaklar(dynamic notlar) {
    try {
      if (notlar == null) return [];
      final obj = notlar is String ? jsonDecode(notlar) : notlar;
      if (obj is Map && obj['toplanan_sayimlar'] is List) {
        return List<Map<String, dynamic>>.from(obj['toplanan_sayimlar']);
      }
    } catch (_) {}
    return [];
  }

  String _formatTarih(dynamic tarih) {
    if (tarih == null) return '';
    try {
      final d = DateTime.parse(tarih.toString());
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return tarih.toString();
    }
  }

  Widget _infoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
          Flexible(child: Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  void _showInfoModal(Map<String, dynamic> sayim) {
    final kaynaklar = _parseKaynaklar(sayim['notlar']);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
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
            // Başlık
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sayim['ad'] ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Toplanan sayımların detayları',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Bilgi satırları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sayım ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                        GestureDetector(
                          onTap: () {
                            final shortId = '#${sayim['id']?.toString().split('-')[0].toUpperCase() ?? ''}';
                            Clipboard.setData(ClipboardData(text: shortId));
                            Navigator.pop(ctx);
                            showBildirim(context, 'Sayım ID kopyalandı', basarili: true);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('#${sayim['id']?.toString().split('-')[0].toUpperCase() ?? '—'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy, size: 14, color: Color(0xFF9CA3AF)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _infoRow('Sayım', sayim['ad']?.toString() ?? '—'),
                  _infoRow('Tarih', (() {
                    final t = sayim['tarih'];
                    if (t == null) return '—';
                    try {
                      final dt = DateTime.parse(t.toString());
                      const aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
                      return '${dt.day.toString().padLeft(2, '0')} ${aylar[dt.month]} ${dt.year}';
                    } catch (_) { return '—'; }
                  })()),
                  _infoRow('Depolar', kaynaklar.map((k) => k['depo']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ')),
                  _infoRow('Durum', sayim['durum'] == 'devam' ? 'Devam Ediyor' : '✓ Tamamlandı'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'TOPLANAN SAYIMLAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Liste
            Flexible(
              child: kaynaklar.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Kaynak bilgisi bulunamadı',
                        style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: kaynaklar.length,
                      itemBuilder: (_, i) {
                        final k = kaynaklar[i];
                        final grad = _grads[i % _grads.length];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF3F4F6)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: grad),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      k['ad'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF1F2937),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '#${(k['id'] ?? '').toString().split('-').first.toUpperCase()}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF9CA3AF),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        if (k['tarih'] != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTarih(k['tarih']),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                        if (k['depo'] != null) ...[
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              k['depo'],
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
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
      ),
    );
  }

  void _showDuzenleModal(Map<String, dynamic> sayim) {
    final controller = TextEditingController(text: sayim['ad'] ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Başlık
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sayımı Düzenle',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          sayim['ad'] ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // İsim input
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SAYIM İSMİ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Butonlar yan yana
              Row(
                children: [
                  // Sil butonu — toplam_sayim.sil yetkisi gerekli
                  if (_seciliIsletmeId != null && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'toplam_sayim', 'sil'))
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      // Toplanan sayım sayısı
                      int toplananAdet = 0;
                      try {
                        final notlar = sayim['notlar'];
                        if (notlar != null && notlar.toString().isNotEmpty) {
                          final parsed = jsonDecode(notlar.toString());
                          if (parsed is Map && parsed['toplanan_sayimlar'] is List) {
                            toplananAdet = (parsed['toplanan_sayimlar'] as List).length;
                          }
                        }
                      } catch (_) {}

                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (sheetCtx) => _ToplanmisSilOnaySheet(
                          sayimId: sayim['id'].toString(),
                          sayimAd: sayim['ad'] ?? 'Toplanmış Sayım',
                          toplananAdet: toplananAdet,
                          onSilindi: () {
                            if (mounted) {
                              showBildirim(context, 'Sayım silindi', tip: BildirimTip.hata);
                              _fetch();
                            }
                          },
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                          SizedBox(width: 6),
                          Text(
                            'Sil',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Kaydet butonu
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final yeni = controller.text.trim();
                        if (yeni.isEmpty || yeni == sayim['ad']) return;
                        try {
                          await SayimService.guncelle(sayim['id'], {'ad': yeni});
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            showBildirim(context, 'İsim güncellendi', tip: BildirimTip.bilgi);
                            _fetch();
                          }
                        } catch (_) {
                          if (mounted) {
                            showBildirim(context, 'Güncelleme başarısız', basarili: false);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primary, Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Kaydet',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      pageTitle: 'Toplam Sayımlar',
      showBack: true,
      child: Column(
        children: [
          // İşletme seçici bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: GestureDetector(
              onTap: _showIsletmePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 16, color: _primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _seciliIsletme?.ad ?? 'İşletme Seç',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 18, color: _primary),
                  ],
                ),
              ),
            ),
          ),
          // İçerik
          Expanded(
            child: _yukleniyor
          ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : _sayimlar.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.playlist_add_check,
                        size: 48,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Toplanmış sayım yok',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sayımlar sayfasından sayım toplayabilirsiniz',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _primary,
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sayimlar.length,
                    itemBuilder: (_, index) {
                      final s = _sayimlar[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push('/sayim/${s['id']}'),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Sol: İsim, ID, Tarih
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s['ad'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFF1F2937),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '#${(s['id'] ?? '').toString().split('-').first.toUpperCase()}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF6B7280),
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatTarih(s['tarih']),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Sağ: Info + Düzenle
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showInfoModal(s),
                                        child: Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: _primaryLight,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.info_outline,
                                            size: 18,
                                            color: _primary,
                                          ),
                                        ),
                                      ),
                                      if (_seciliIsletmeId != null && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'toplam_sayim', 'duzenle')) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _showDuzenleModal(s),
                                          child: Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              size: 18,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ), // Expanded
        ], // Column children
      ), // Column
    );
  }
}

// ─────────────────────────────────────────────
// Toplanmış Sayım Silme Onay Bottom Sheet
// ─────────────────────────────────────────────
class _ToplanmisSilOnaySheet extends StatefulWidget {
  final String sayimId;
  final String sayimAd;
  final int toplananAdet;
  final VoidCallback onSilindi;

  const _ToplanmisSilOnaySheet({
    required this.sayimId,
    required this.sayimAd,
    required this.toplananAdet,
    required this.onSilindi,
  });

  @override
  State<_ToplanmisSilOnaySheet> createState() => _ToplanmisSilOnaySheetState();
}

class _ToplanmisSilOnaySheetState extends State<_ToplanmisSilOnaySheet> {
  bool _siliniyor = false;

  Future<void> _sil() async {
    setState(() => _siliniyor = true);
    final navigator = Navigator.of(context);
    try {
      await SayimService.sil(widget.sayimId);
      navigator.pop();
      widget.onSilindi();
    } catch (e) {
      if (!mounted) return;
      setState(() => _siliniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            // İkon + Başlık yan yana
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.layers_clear_rounded, size: 18, color: Color(0xFFEF4444)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Toplanmış Sayımı Sil',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1F2937)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Açıklama — sayım adı bold inline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5),
                  children: [
                    TextSpan(text: '"${widget.sayimAd}"', style: const TextStyle(fontWeight: FontWeight.w700, color: _primary)),
                    const TextSpan(text: ' adlı toplanmış sayım silinecek. Orijinal sayımlar etkilenmez.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Butonlar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('Vazgeç', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _siliniyor ? null : _sil,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_siliniyor)
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            else
                              const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(_siliniyor ? 'Siliniyor...' : 'Evet, Sil', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
