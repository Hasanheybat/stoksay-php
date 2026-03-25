import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/isletme_provider.dart';
import '../models/isletme.dart';
import '../services/depo_service.dart';
import '../services/sayim_service.dart';
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

class YeniSayimScreen extends ConsumerStatefulWidget {
  const YeniSayimScreen({super.key});

  @override
  ConsumerState<YeniSayimScreen> createState() => _YeniSayimScreenState();
}

class _YeniSayimScreenState extends ConsumerState<YeniSayimScreen> {
  List<Isletme> _isletmeler = [];
  List<Map<String, dynamic>> _depolar = [];
  String? _seciliIsletmeId;
  String? _seciliDepoId;
  String _tarih = '';
  List<String> _kisiler = [];
  final _kisiController = TextEditingController();
  bool _kaydediyor = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tarih = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIsletmeler());
  }

  @override
  void dispose() {
    _kisiController.dispose();
    super.dispose();
  }

  Future<void> _fetchIsletmeler() async {
    final isletmeState = ref.read(isletmeProvider);
    final list = isletmeState.isletmeler;
    setState(() {
      _isletmeler = list;
      if (list.length == 1) {
        _seciliIsletmeId = list.first.id;
        _fetchDepolar(list.first.id);
      }
    });
  }

  Future<void> _fetchDepolar(String isletmeId) async {
    try {
      final data = await DepoService.listele(isletmeId);
      setState(() {
        _depolar = data;
        _seciliDepoId = null;
      });
    } catch (_) {
      setState(() {
        _depolar = [];
        _seciliDepoId = null;
      });
    }
  }

  void _handleIsletme(String id) {
    setState(() {
      _seciliIsletmeId = id;
      _seciliDepoId = null;
      _depolar = [];
    });
    _fetchDepolar(id);
  }

  void _kisiEkle() {
    final ad = _kisiController.text.trim();
    if (ad.isEmpty) return;
    if (_kisiler.contains(ad)) {
      _showSnack('Bu kişi zaten eklendi.', basarili: false);
      return;
    }
    setState(() => _kisiler.add(ad));
    _kisiController.clear();
  }

  void _kisiSil(String ad) {
    setState(() => _kisiler.remove(ad));
  }

  void _showSnack(String msg, {bool basarili = true}) {
    showBildirim(context, msg, basarili: basarili);
  }

  Isletme? get _seciliIsletme =>
      _isletmeler.where((i) => i.id == _seciliIsletmeId).firstOrNull;

  String? get _seciliDepoAd {
    if (_seciliDepoId == null) return null;
    final d = _depolar.where((d) => d['id'] == _seciliDepoId).firstOrNull;
    return d?['ad'] as String?;
  }

  Future<void> _handleKaydet() async {
    if (_seciliIsletmeId == null) {
      _showSnack('İşletme seçin.', basarili: false);
      return;
    }
    if (_seciliDepoId == null) {
      _showSnack('Depo seçin.', basarili: false);
      return;
    }

    final isletmeAd = _seciliIsletme?.ad ?? '';
    final depoAd = _seciliDepoAd ?? '';
    final ad = '$isletmeAd — $depoAd ($_tarih)';

    setState(() => _kaydediyor = true);
    try {
      final data = await SayimService.olustur({
        'isletme_id': _seciliIsletmeId,
        'depo_id': _seciliDepoId,
        'ad': ad,
        'tarih': _tarih,
        'kisiler': _kisiler,
      });
      _showSnack('Sayım başlatıldı!');
      if (mounted) {
        context.go('/sayim/${data['id']}/urun-ekle');
      }
    } catch (e) {
      _showSnack('Sayım oluşturulamadı.', basarili: false);
      setState(() => _kaydediyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      pageTitle: 'Yeni Sayım',
      showBack: true,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İşletme
                  _label('İŞLETME'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showIsletmePicker(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business, size: 16, color: _P),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _seciliIsletme?.ad ?? 'İşletme seçin...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _seciliIsletmeId != null
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Depo
                  _label('DEPO'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      if (_seciliIsletmeId != null) _showDepoPicker();
                    },
                    child: Opacity(
                      opacity: _seciliIsletmeId != null ? 1.0 : 0.5,
                      child: Container(
                        width: double.infinity,
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
                                _seciliIsletmeId == null
                                    ? 'Önce işletme seçin'
                                    : _seciliDepoAd ?? (_depolar.isEmpty ? 'Bu işletmede depo yok' : 'Depo seçin...'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _seciliDepoId != null
                                      ? const Color(0xFF1F2937)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tarih
                  _label('TARİH'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(primary: _P),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _tarih = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        _tarih,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sayım Yapan Kişiler
                  _label('SAYIM YAPAN KİŞİLER'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: _kisiler.isEmpty
                        ? const Text('Kişi eklenmedi',
                            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _kisiler.map((k) {
                              return GestureDetector(
                                onTap: () => _kisiSil(k),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _PL,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(k,
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w600, color: _P)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.close, size: 12, color: _P.withValues(alpha: 0.6)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _kisiController,
                          onSubmitted: (_) => _kisiEkle(),
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Kişi adı girin...',
                            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _P),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _kisiEkle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _P,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Ekle',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Alt Buton
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: GestureDetector(
              onTap: _kaydediyor ? null : _handleKaydet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_P, Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_kaydediyor)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      const Icon(Icons.add, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _kaydediyor ? 'Başlatılıyor...' : 'Sayımı Başlat',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.5,
      ),
    );
  }

  void _showIsletmePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PickerSheet(
        title: 'İşletme Seç',
        icon: Icons.business,
        items: _isletmeler.map((i) => {'id': i.id, 'ad': i.ad, 'kod': i.kod}).toList(),
        seciliId: _seciliIsletmeId,
        onSelect: (id) {
          _handleIsletme(id);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showDepoPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PickerSheet(
        title: 'Depo Seç',
        icon: Icons.warehouse,
        items: _depolar.map((d) => {'id': d['id'], 'ad': d['ad']}).toList(),
        seciliId: _seciliDepoId,
        onSelect: (id) {
          setState(() => _seciliDepoId = id);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final String? seciliId;
  final Function(String) onSelect;

  const _PickerSheet({
    required this.title,
    required this.icon,
    required this.items,
    required this.seciliId,
    required this.onSelect,
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _PL,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 16, color: _P),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = item['id'] == seciliId;
                final gradColors = _GRADS[index % _GRADS.length];
                final ad = item['ad'] as String? ?? '';

                return GestureDetector(
                  onTap: () => onSelect(item['id'] as String),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected ? _PL : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: selected
                          ? Border.all(color: _P.withValues(alpha: 0.25), width: 1.5)
                          : Border.all(color: Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradColors),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              ad.isNotEmpty ? ad[0] : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ad,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF1F2937))),
                              if (item['kod'] != null && (item['kod'] as String).isNotEmpty)
                                Text(item['kod'] as String,
                                    style:
                                        const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        if (selected)
                          Container(
                            width: 20,
                            height: 20,
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
