import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../providers/isletme_provider.dart';
import '../models/isletme.dart';
import '../models/sayim.dart';
import '../services/sayim_service.dart';
import '../services/depo_service.dart';
import '../widgets/bildirim.dart';
import 'app_layout.dart';

const _P = Color(0xFF6C53F5);
const _PL = Color(0x1A6C53F5);

const List<List<Color>> _GRADS = [
  [Color(0xFF6C53F5), Color(0xFF8B5CF6)],
  [Color(0xFF0EA5E9), Color(0xFF2563EB)],
  [Color(0xFF10B981), Color(0xFF059669)],
  [Color(0xFFF59E0B), Color(0xFFD97706)],
  [Color(0xFFEC4899), Color(0xFFDB2777)],
];

class SayimlarScreen extends ConsumerStatefulWidget {
  const SayimlarScreen({super.key});

  @override
  ConsumerState<SayimlarScreen> createState() => _SayimlarScreenState();
}

class _SayimlarScreenState extends ConsumerState<SayimlarScreen> {
  List<Isletme> _isletmeler = [];
  String? _seciliIsletmeId;
  List<Sayim> _sayimlar = [];
  bool _yukleniyor = false;
  String _aktifFiltre = 'hepsi';

  // Toplama modu
  bool _toplamaMode = false;
  final Set<String> _seciliSayimlar = {};
  bool _menuAcik = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIsletmeler());
  }

  Future<void> _fetchIsletmeler() async {
    final isletmeState = ref.read(isletmeProvider);
    final list = isletmeState.isletmeler;
    setState(() {
      _isletmeler = list;
      if (list.isNotEmpty) _seciliIsletmeId = list.first.id;
    });
    if (_seciliIsletmeId != null) _fetchSayimlar(_seciliIsletmeId!);
  }

  Future<void> _fetchSayimlar(String isletmeId) async {
    setState(() => _yukleniyor = true);
    try {
      final data = await SayimService.listele(isletmeId);
      final sayimlar = data
          .where((s) => s['durum'] != 'silindi')
          .map((s) => Sayim.fromJson(s))
          .toList();
      // Backend zaten created_at DESC sıralı gönderiyor, ekstra sıralama gereksiz
      setState(() {
        _sayimlar = sayimlar;
        _yukleniyor = false;
      });
    } catch (_) {
      setState(() {
        _sayimlar = [];
        _yukleniyor = false;
      });
    }
  }

  Isletme? get _seciliIsletme =>
      _isletmeler.where((i) => i.id == _seciliIsletmeId).firstOrNull;

  List<Sayim> get _gosterilenSayimlar {
    if (_aktifFiltre == 'hepsi') return _sayimlar;
    return _sayimlar.where((s) => s.durum == _aktifFiltre).toList();
  }

  void _showDuzenle(Sayim sayim) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SayimDuzenleSheet(
        sayim: sayim,
        isletmeId: sayim.isletmeId,
        parentContext: context,
        canSil: _seciliIsletmeId != null && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'sayim', 'sil'),
        onKaydedildi: () {
          if (_seciliIsletmeId != null) _fetchSayimlar(_seciliIsletmeId!);
        },
        onSilindi: () {
          if (_seciliIsletmeId != null) _fetchSayimlar(_seciliIsletmeId!);
          if (mounted) {
            showBildirim(context, 'Sayım silindi', tip: BildirimTip.hata);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      pageTitle: 'Sayımlar',
      showBack: true,
      onHeaderAction: _toplamaMode ? null : () => setState(() => _menuAcik = !_menuAcik),
      headerActionIcon: _menuAcik ? Icons.close : Icons.add,
      child: Stack(
        children: [
          Column(
        children: [
          // Üst bar - İşletme seçici veya Toplama modu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: _toplamaMode
                ? Row(
                    children: [
                      // İptal butonu
                      GestureDetector(
                        onTap: () => setState(() {
                          _toplamaMode = false;
                          _seciliSayimlar.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close, size: 14, color: Color(0xFFEF4444)),
                              SizedBox(width: 4),
                              Text('İptal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ),
                      // Sayaç
                      Expanded(
                        child: Center(
                          child: Text(
                            '${_seciliSayimlar.length} sayım seçili',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                      // Topla butonu
                      GestureDetector(
                        onTap: _seciliSayimlar.length >= 2 ? _showToplamaModal : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: _seciliSayimlar.length >= 2
                                ? const LinearGradient(colors: [_P, Color(0xFF8B5CF6)])
                                : null,
                            color: _seciliSayimlar.length >= 2 ? null : const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calculate, size: 14, color: _seciliSayimlar.length >= 2 ? Colors.white : const Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Text('Topla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _seciliSayimlar.length >= 2 ? Colors.white : const Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showIsletmePicker(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _PL,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _P.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.business, size: 14, color: _P),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _seciliIsletme?.ad ?? 'İşletme',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _P,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down, size: 14, color: _P),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Filtre chipleri
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tümü',
                  active: _aktifFiltre == 'hepsi',
                  onTap: () => setState(() => _aktifFiltre = 'hepsi'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Devam (${_sayimlar.where((s) => s.durum == 'devam').length})',
                  active: _aktifFiltre == 'devam',
                  onTap: () => setState(() => _aktifFiltre = 'devam'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Tamamlanan (${_sayimlar.where((s) => s.durum == 'tamamlandi').length})',
                  active: _aktifFiltre == 'tamamlandi',
                  onTap: () => setState(() => _aktifFiltre = 'tamamlandi'),
                ),
              ],
            ),
          ),

          // Sonuç sayısı
          if (!_yukleniyor && _sayimlar.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${_gosterilenSayimlar.length} / ${_sayimlar.length} sayım',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  if (_seciliIsletme != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '· ${_seciliIsletme!.ad}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _P),
                    ),
                  ],
                ],
              ),
            ),

          // Sayım listesi
          Expanded(
            child: _yukleniyor
                ? const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3, color: _P),
                    ),
                  )
                : _isletmeler.isEmpty
                    ? const _EmptyState(
                        icon: Icons.business,
                        title: 'Atanmış işletme yok',
                        subtitle: 'Yöneticinizle iletişime geçin',
                      )
                    : _gosterilenSayimlar.isEmpty
                        ? _EmptyState(
                            icon: Icons.assignment,
                            title: _aktifFiltre == 'hepsi' ? 'Henüz sayım yok' : 'Sayım bulunamadı',
                            subtitle: _aktifFiltre == 'hepsi' ? '+ butonuna basarak yeni sayım başlatın' : null,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _gosterilenSayimlar.length,
                            itemBuilder: (ctx, i) {
                              final s = _gosterilenSayimlar[i];
                              final isTamamlandi = s.durum == 'tamamlandi';
                              final isSecili = _seciliSayimlar.contains(s.id);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    // Checkbox — sadece toplama modunda
                                    if (_toplamaMode) ...[
                                      GestureDetector(
                                        onTap: () {
                                          if (!isTamamlandi) {
                                            showBildirim(context, 'Sadece tamamlanmış sayımlar toplanabilir.', basarili: false);
                                            return;
                                          }
                                          setState(() {
                                            if (isSecili) {
                                              _seciliSayimlar.remove(s.id);
                                            } else {
                                              _seciliSayimlar.add(s.id);
                                            }
                                          });
                                        },
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: isSecili ? _P : (isTamamlandi ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB)),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSecili ? _P : (isTamamlandi ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB)),
                                              width: 2,
                                            ),
                                          ),
                                          child: isSecili
                                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // Kart
                                    Expanded(
                                      child: Opacity(
                                        opacity: _toplamaMode && !isTamamlandi ? 0.5 : 1.0,
                                        child: _SayimCard(
                                          sayim: s,
                                          isletmeAd: _isletmeler
                                              .where((ist) => ist.id == s.isletmeId)
                                              .firstOrNull
                                              ?.ad ?? '—',
                                          onDuzenle: !_toplamaMode && s.durum == 'devam' && _seciliIsletmeId != null && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'sayim', 'duzenle') ? () => _showDuzenle(s) : null,
                                          isSecili: _toplamaMode && isSecili,
                                          onTap: _toplamaMode
                                              ? () {
                                                  if (!isTamamlandi) {
                                                    showBildirim(context, 'Sadece tamamlanmış sayımlar toplanabilir.', basarili: false);
                                                    return;
                                                  }
                                                  setState(() {
                                                    if (isSecili) {
                                                      _seciliSayimlar.remove(s.id);
                                                    } else {
                                                      _seciliSayimlar.add(s.id);
                                                    }
                                                  });
                                                }
                                              : () async {
                                                  final result = await context.push('/sayim/${s.id}');
                                                  if (result == true && _seciliIsletmeId != null) {
                                                    _fetchSayimlar(_seciliIsletmeId!);
                                                  }
                                                },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
          // Menü overlay
          if (_menuAcik)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _menuAcik = false),
                child: Container(color: Colors.black.withValues(alpha: 0.1)),
              ),
            ),
          // Dropdown menü (header butonundan açılır)
          if (!_toplamaMode && _menuAcik)
            Positioned(
              right: 16,
              top: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_seciliIsletmeId == null || ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'sayim', 'ekle'))
                      GestureDetector(
                        onTap: () async {
                          setState(() => _menuAcik = false);
                          await context.push('/yeni-sayim');
                          if (_seciliIsletmeId != null) _fetchSayimlar(_seciliIsletmeId!);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.note_add_outlined, size: 16, color: _P),
                              SizedBox(width: 10),
                              Text('Sayım Ekle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                            ],
                          ),
                        ),
                      ),
                    if (_seciliIsletmeId != null && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'toplam_sayim', 'ekle')) ...[
                      Container(height: 1, color: const Color(0xFFF3F4F6)),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _menuAcik = false;
                            _toplamaMode = true;
                            _seciliSayimlar.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calculate, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 10),
                              Text('Sayım Topla', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showToplamaModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ToplamaIsimSheet(
        seciliSayimSayisi: _seciliSayimlar.length,
        onTopla: (isim) async {
          if (_seciliIsletmeId == null) return;
          try {
            await SayimService.topla(
              sayimIds: _seciliSayimlar.toList(),
              ad: isim,
              isletmeId: _seciliIsletmeId!,
            );
            if (!mounted) return;
            Navigator.pop(ctx);
            setState(() {
              _toplamaMode = false;
              _seciliSayimlar.clear();
            });
            showBildirim(context, 'Sayımlar toplandı!');
            _fetchSayimlar(_seciliIsletmeId!);
          } catch (e) {
            if (!mounted) return;
            String hata = 'Toplama başarısız.';
            if (e is DioException) {
              final data = e.response?.data;
              if (data is Map && data['hata'] != null) hata = data['hata'].toString();
            }
            showBildirim(context, hata, basarili: false);
          }
        },
      ),
    );
  }

  void _showIsletmePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _IsletmePickerSheet(
        isletmeler: _isletmeler,
        seciliId: _seciliIsletmeId,
        onSelect: (ist) {
          setState(() {
            _seciliIsletmeId = ist.id;
            _aktifFiltre = 'hepsi';
          });
          _fetchSayimlar(ist.id);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ──────────────────────────────────────────
// Filter Chip
// ──────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(colors: [Color(0xFF6C53F5), Color(0xFF8B5CF6)])
              : null,
          color: active ? null : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Sayım Kartı
// ──────────────────────────────────────────
class _SayimCard extends StatelessWidget {
  final Sayim sayim;
  final String isletmeAd;
  final VoidCallback? onDuzenle;
  final bool isSecili;
  final VoidCallback? onTap;

  const _SayimCard({required this.sayim, required this.isletmeAd, this.onDuzenle, this.isSecili = false, this.onTap});

  String _formatTarih(String? tarih) {
    if (tarih == null || tarih.isEmpty) return '';
    try {
      final dt = DateTime.parse(tarih);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      // Tarih parse edilemezse T'den öncesini al
      if (tarih.contains('T')) return tarih.split('T').first;
      return tarih;
    }
  }

  @override
  Widget build(BuildContext context) {
    final depoAd = sayim.depo?['ad'] ?? '—';
    final isTamamlandi = sayim.durum == 'tamamlandi';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSecili ? _P : const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? () {
            context.push('/sayim/${sayim.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        depoAd,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Durum badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTamamlandi ? const Color(0xFFECFDF5) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTamamlandi ? Icons.check_circle : Icons.access_time,
                            size: 12,
                            color: isTamamlandi ? const Color(0xFF059669) : const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTamamlandi ? 'Tamamlandı' : 'Devam Ediyor',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isTamamlandi ? const Color(0xFF059669) : const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Düzenleme butonu
                    if (onDuzenle != null) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 28, height: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 14,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: onDuzenle,
                          icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.business, size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(isletmeAd, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${sayim.id.split('-').first.toUpperCase()}',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF9CA3AF)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_formatTarih(sayim.tarih), style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Sayım Düzenle Bottom Sheet
// ──────────────────────────────────────────
class _SayimDuzenleSheet extends StatefulWidget {
  final Sayim sayim;
  final String isletmeId;
  final VoidCallback onKaydedildi;
  final VoidCallback onSilindi;
  final bool canSil;
  final BuildContext parentContext;

  const _SayimDuzenleSheet({required this.sayim, required this.isletmeId, required this.onKaydedildi, required this.onSilindi, this.canSil = true, required this.parentContext});

  @override
  State<_SayimDuzenleSheet> createState() => _SayimDuzenleSheetState();
}

class _SayimDuzenleSheetState extends State<_SayimDuzenleSheet> {
  List<Map<String, dynamic>> _depolar = [];
  String? _seciliDepoId;
  List<String> _kisiler = [];
  final _kisiCtrl = TextEditingController();
  bool _kaydediyor = false;
  String? _hataMesaji;

  @override
  void initState() {
    super.initState();
    _seciliDepoId = widget.sayim.depoId;
    _kisiler = List<String>.from(widget.sayim.kisiler.whereType<String>());
    _fetchDepolar();
  }

  @override
  void dispose() {
    _kisiCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDepolar() async {
    try {
      final data = await DepoService.listele(widget.isletmeId);
      setState(() => _depolar = data);
    } catch (_) {}
  }

  void _kisiEkle() {
    final t = _kisiCtrl.text.trim();
    if (t.isEmpty || _kisiler.contains(t)) return;
    setState(() {
      _kisiler.add(t);
      _kisiCtrl.clear();
    });
  }

  Future<void> _kaydet() async {
    if (_seciliDepoId == null) {
      setState(() => _hataMesaji = 'Depo seçin.');
      return;
    }
    setState(() {
      _kaydediyor = true;
      _hataMesaji = null;
    });

    final navigator = Navigator.of(context);
    final depoAd = _depolar.where((d) => d['id'] == _seciliDepoId).firstOrNull?['ad'] ?? '';
    final yeniAd = '${widget.sayim.isletme?['ad'] ?? ''} — $depoAd (${widget.sayim.tarih ?? ''})';

    try {
      await SayimService.guncelle(widget.sayim.id, {
        'depo_id': _seciliDepoId,
        'ad': yeniAd,
        'kisiler': _kisiler,
      });
      navigator.pop();
      widget.onKaydedildi();
    } catch (e) {
      if (!mounted) return;
      String hata = 'Sunucuya bağlanılamadı.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['hata'] != null) hata = data['hata'].toString();
      }
      setState(() {
        _hataMesaji = hata;
        _kaydediyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),

          // Başlık
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sayımı Düzenle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Depo seçici
                  _labelW('DEPO'),
                  GestureDetector(
                    onTap: () => _showDepoPicker(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warehouse, size: 16, color: _P),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _depolar.where((d) => d['id'] == _seciliDepoId).firstOrNull?['ad'] ?? 'Depo seçin...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _seciliDepoId != null ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Kişiler
                  _labelW('SAYIM YAPAN KİŞİLER'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: _kisiler.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Kişi eklenmedi', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _kisiler.map((k) => GestureDetector(
                              onTap: () => setState(() => _kisiler.remove(k)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: _PL, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(k, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _P)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.close, size: 10, color: _P),
                                  ],
                                ),
                              ),
                            )).toList(),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _kisiCtrl,
                          style: const TextStyle(fontSize: 14),
                          onSubmitted: (_) => _kisiEkle(),
                          decoration: InputDecoration(
                            hintText: 'Kişi adı girin...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _P)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _kisiEkle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: _P, borderRadius: BorderRadius.circular(12)),
                          child: const Text('Ekle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Hata
          if (_hataMesaji != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_hataMesaji!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)))),
                ],
              ),
            ),

          // Kaydet + Sil butonları (yan yana)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Sil butonu
                  if (widget.canSil) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: widget.parentContext,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => _SilOnaySheet(
                              sayimId: widget.sayim.id,
                              sayim: widget.sayim,
                              onSilindi: widget.onSilindi,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 6),
                              Text('Sil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Kaydet butonu
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _kaydediyor ? null : _kaydet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6C53F5), Color(0xFF8B5CF6)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_kaydediyor)
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            else
                              const Icon(Icons.check, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(_kaydediyor ? 'Kaydediliyor...' : 'Kaydet', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
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

  void _showDepoPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _DepoPickerSheet(
        depolar: _depolar,
        seciliId: _seciliDepoId,
        onSelect: (depoId) {
          setState(() => _seciliDepoId = depoId);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _labelW(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
    );
  }
}

// ──────────────────────────────────────────
// Silme Onay Bottom Sheet
// ──────────────────────────────────────────
class _SilOnaySheet extends StatefulWidget {
  final String sayimId;
  final Sayim? sayim;
  final VoidCallback onSilindi;

  const _SilOnaySheet({required this.sayimId, this.sayim, required this.onSilindi});

  @override
  State<_SilOnaySheet> createState() => _SilOnaySheetState();
}

class _SilOnaySheetState extends State<_SilOnaySheet> {
  bool _siliniyor = false;

  bool get _isToplanmis {
    final notlar = widget.sayim?.notlar;
    if (notlar == null || notlar.isEmpty) return false;
    try {
      final parsed = jsonDecode(notlar);
      if (parsed is Map && parsed['toplanan_sayimlar'] is List) return true;
    } catch (_) {}
    return false;
  }

  int get _toplananSayimSayisi {
    final notlar = widget.sayim?.notlar;
    if (notlar == null) return 0;
    try {
      final parsed = jsonDecode(notlar);
      if (parsed is Map && parsed['toplanan_sayimlar'] is List) {
        return (parsed['toplanan_sayimlar'] as List).length;
      }
    } catch (_) {}
    return 0;
  }

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToplanmis = _isToplanmis;
    final sayimAd = widget.sayim?.ad ?? 'Sayım';
    final toplananAdet = _toplananSayimSayisi;

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
                  child: Icon(
                    isToplanmis ? Icons.layers_clear_rounded : Icons.delete_outline_rounded,
                    size: 18,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isToplanmis ? 'Toplanmış Sayımı Sil' : 'Sayımı Sil',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1F2937)),
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
                    TextSpan(text: '"$sayimAd"', style: TextStyle(fontWeight: FontWeight.w700, color: isToplanmis ? _P : const Color(0xFF374151))),
                    TextSpan(
                      text: isToplanmis
                          ? ' adlı toplanmış sayım silinecek. Orijinal sayımlar etkilenmez.'
                          : ' silinmiş olarak işaretlenecek. Bu işlem geri alınamaz.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
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

// ──────────────────────────────────────────
// Depo Picker Sheet
// ──────────────────────────────────────────
class _DepoPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> depolar;
  final String? seciliId;
  final Function(String) onSelect;

  const _DepoPickerSheet({required this.depolar, required this.seciliId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _PL, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.warehouse, size: 16, color: _P),
                ),
                const SizedBox(width: 8),
                const Text('Depo Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: depolar.length,
              itemBuilder: (context, index) {
                final d = depolar[index];
                final selected = d['id'] == seciliId;
                final gradColors = _GRADS[index % _GRADS.length];

                return GestureDetector(
                  onTap: () => onSelect(d['id']),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected ? _PL : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: selected ? Border.all(color: _P.withValues(alpha: 0.25), width: 1.5) : Border.all(color: Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors), borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(d['ad']?.toString().isNotEmpty == true ? d['ad'][0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(d['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1F2937)))),
                        if (selected)
                          Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(color: _P, shape: BoxShape.circle),
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
    );
  }
}

// ──────────────────────────────────────────
// İşletme seçici bottom sheet
// ──────────────────────────────────────────
class _IsletmePickerSheet extends StatelessWidget {
  final List<Isletme> isletmeler;
  final String? seciliId;
  final Function(Isletme) onSelect;

  const _IsletmePickerSheet({required this.isletmeler, required this.seciliId, required this.onSelect});

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
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _PL, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.business, size: 16, color: _P),
                ),
                const SizedBox(width: 8),
                const Text('İşletme Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: isletmeler.length,
              itemBuilder: (context, index) {
                final ist = isletmeler[index];
                final selected = ist.id == seciliId;
                final gradColors = _GRADS[index % _GRADS.length];
                return GestureDetector(
                  onTap: () => onSelect(ist),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected ? _PL : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: selected ? Border.all(color: _P.withValues(alpha: 0.25), width: 1.5) : Border.all(color: Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors), borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(ist.ad.isNotEmpty ? ist.ad[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ist.ad, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1F2937))),
                              if (ist.kod != null && ist.kod!.isNotEmpty)
                                Text(ist.kod!, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        if (selected)
                          Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(color: _P, shape: BoxShape.circle),
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
    );
  }
}

// ──────────────────────────────────────────
// Toplama İsim Bottom Sheet
// ──────────────────────────────────────────
class _ToplamaIsimSheet extends StatefulWidget {
  final int seciliSayimSayisi;
  final Future<void> Function(String isim) onTopla;

  const _ToplamaIsimSheet({required this.seciliSayimSayisi, required this.onTopla});

  @override
  State<_ToplamaIsimSheet> createState() => _ToplamaIsimSheetState();
}

class _ToplamaIsimSheetState extends State<_ToplamaIsimSheet> {
  final _ctrl = TextEditingController();
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              // İkon
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: _PL, borderRadius: BorderRadius.circular(28)),
                child: const Icon(Icons.calculate, size: 24, color: _P),
              ),
              const SizedBox(height: 16),
              const Text('Sayımları Topla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
              const SizedBox(height: 6),
              Text(
                '${widget.seciliSayimSayisi} sayım seçildi. Toplanmış sayım için bir isim girin.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.5),
              ),
              const SizedBox(height: 20),
              // Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                  decoration: InputDecoration(
                    hintText: 'Toplanmış sayım adı...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _P, width: 1.5)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Butonlar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text('Vazgeç', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _yukleniyor || _ctrl.text.trim().isEmpty
                            ? null
                            : () async {
                                setState(() => _yukleniyor = true);
                                await widget.onTopla(_ctrl.text.trim());
                                if (mounted) setState(() => _yukleniyor = false);
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_P, Color(0xFF8B5CF6)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_yukleniyor)
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              else
                                const Icon(Icons.calculate, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(_yukleniyor ? 'Toplanıyor...' : 'Topla', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Boş durum widget
// ──────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _EmptyState({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Icon(icon, size: 48, color: const Color(0xFF9CA3AF).withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
