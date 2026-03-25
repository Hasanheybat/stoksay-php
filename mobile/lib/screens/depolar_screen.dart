import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../providers/isletme_provider.dart';
import '../models/isletme.dart';
import '../services/depo_service.dart';
import '../services/storage_service.dart';
import '../services/offline_id_service.dart';
import '../widgets/aktif_sayim_dialog.dart';
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

class DepolarScreen extends ConsumerStatefulWidget {
  const DepolarScreen({super.key});

  @override
  ConsumerState<DepolarScreen> createState() => _DepolarScreenState();
}

class _DepolarScreenState extends ConsumerState<DepolarScreen> {
  List<Isletme> _isletmeler = [];
  String? _seciliIsletmeId;
  List<Map<String, dynamic>> _depolar = [];
  List<Map<String, dynamic>> _filtreliDepolar = [];
  String _aramaStr = '';
  bool _yukleniyor = false;

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
    if (_seciliIsletmeId != null) _fetchDepolar(_seciliIsletmeId!);
  }

  Future<void> _fetchDepolar(String isletmeId) async {
    setState(() => _yukleniyor = true);
    try {
      final data = await DepoService.listele(isletmeId);
      setState(() {
        _depolar = data;
        _filtreliDepolar = data;
        _yukleniyor = false;
      });
    } catch (_) {
      setState(() {
        _depolar = [];
        _filtreliDepolar = [];
        _yukleniyor = false;
      });
    }
  }

  void _filtrele(String query) {
    setState(() {
      _aramaStr = query;
      if (query.trim().isEmpty) {
        _filtreliDepolar = _depolar;
      } else {
        final q = query.toLowerCase();
        _filtreliDepolar = _depolar.where((d) {
          final ad = (d['ad'] ?? '').toString().toLowerCase();
          final konum = (d['konum'] ?? '').toString().toLowerCase();
          return ad.contains(q) || konum.contains(q);
        }).toList();
      }
    });
  }

  Isletme? get _seciliIsletme =>
      _isletmeler.where((i) => i.id == _seciliIsletmeId).firstOrNull;

  void _showDepoEkle() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _DepoEkleSheet(
          isletmeler: _isletmeler,
          seciliIsletmeId: _seciliIsletmeId,
          onKaydedildi: () {
            if (_seciliIsletmeId != null) _fetchDepolar(_seciliIsletmeId!);
          },
        ),
      ),
    );
  }

  void _showDepoDuzenle(Map<String, dynamic> depo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _DepoDuzenleSheet(
          depo: depo,
          isletmeId: _seciliIsletmeId,
          canEdit: _seciliIsletmeId != null
              && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'depo', 'duzenle')
              && (!StorageService.isOffline || OfflineIdService.isTempId(depo['id'])),
          canDelete: _seciliIsletmeId != null
              && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'depo', 'sil')
              && (!StorageService.isOffline || OfflineIdService.isTempId(depo['id'])),
          onKaydedildi: () {
            if (_seciliIsletmeId != null) _fetchDepolar(_seciliIsletmeId!);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEkle = _seciliIsletmeId != null && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'depo', 'ekle');
    return AppLayout(
      pageTitle: 'Depolar',
      showBack: true,
      onHeaderAction: canEkle ? _showDepoEkle : null,
      headerActionIcon: Icons.add,
      child: Column(
        children: [
          // Üst bar - İşletme seçici + Arama
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                // İşletme seçici
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
                const SizedBox(width: 8),
                // Arama
                SizedBox(
                  width: 112,
                  child: TextField(
                    onChanged: _filtrele,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Ara...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
              ],
            ),
          ),

          // Sonuç sayısı
          if (!_yukleniyor && _depolar.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${_filtreliDepolar.length} / ${_depolar.length} depo',
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

          // Depo listesi
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
                    : _filtreliDepolar.isEmpty
                        ? _EmptyState(
                            icon: Icons.warehouse,
                            title: _aramaStr.isNotEmpty ? 'Depo bulunamadı' : 'Henüz depo eklenmemiş',
                            subtitle: _aramaStr.isEmpty ? '+ butonuna basarak ilk depoyu ekleyin' : null,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _filtreliDepolar.length,
                            itemBuilder: (ctx, i) {
                              final d = _filtreliDepolar[i];
                              final gradColors = _GRADS[i % _GRADS.length];
                              final isOffline = StorageService.isOffline;
                              final isTempDepo = OfflineIdService.isTempId(d['id']);
                              final canDuzenle = _seciliIsletmeId != null
                                  && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'depo', 'duzenle')
                                  && (!isOffline || isTempDepo);
                              final canSil = _seciliIsletmeId != null
                                  && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'depo', 'sil')
                                  && (!isOffline || isTempDepo);
                              return _DepoCard(
                                depo: d,
                                gradColors: gradColors,
                                onDuzenle: (canDuzenle || canSil) ? () => _showDepoDuzenle(d) : null,
                                soluk: isOffline && !isTempDepo,
                              );
                            },
                          ),
          ),
        ],
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
            _aramaStr = '';
          });
          _fetchDepolar(ist.id);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ──────────────────────────────────────────
// Depo kart widget
// ──────────────────────────────────────────
class _DepoCard extends StatelessWidget {
  final Map<String, dynamic> depo;
  final List<Color> gradColors;
  final VoidCallback? onDuzenle;
  final bool soluk;
  const _DepoCard({required this.depo, required this.gradColors, this.onDuzenle, this.soluk = false});

  @override
  Widget build(BuildContext context) {
    final ad = depo['ad'] ?? '';
    final konum = depo['konum'];

    return Opacity(
      opacity: soluk ? 0.45 : 1.0,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: soluk ? const Color(0xFFF9FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
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
          // Renk ikonu
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradColors),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // İsim / Konum
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (konum != null && konum.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      konum,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Düzenle butonu
          if (onDuzenle != null)
            GestureDetector(
              onTap: onDuzenle,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF9CA3AF)),
              ),
            ),
        ],
      ),
    ),
    );
  }
}

// ──────────────────────────────────────────
// Depo Ekle Bottom Sheet
// ──────────────────────────────────────────
class _DepoEkleSheet extends StatefulWidget {
  final List<Isletme> isletmeler;
  final String? seciliIsletmeId;
  final VoidCallback onKaydedildi;

  const _DepoEkleSheet({
    required this.isletmeler,
    required this.seciliIsletmeId,
    required this.onKaydedildi,
  });

  @override
  State<_DepoEkleSheet> createState() => _DepoEkleSheetState();
}

class _DepoEkleSheetState extends State<_DepoEkleSheet> {
  late String? _seciliIsletmeId;
  final _depoAdiCtrl = TextEditingController();
  bool _kaydediyor = false;
  String? _hataMesaji;

  @override
  void initState() {
    super.initState();
    _seciliIsletmeId = widget.seciliIsletmeId ?? (widget.isletmeler.isNotEmpty ? widget.isletmeler.first.id : null);
  }

  @override
  void dispose() {
    _depoAdiCtrl.dispose();
    super.dispose();
  }

  Isletme? get _seciliIsletme =>
      widget.isletmeler.where((i) => i.id == _seciliIsletmeId).firstOrNull;

  void _sifirla() {
    setState(() {
      _depoAdiCtrl.clear();
      _hataMesaji = null;
    });
  }

  Future<void> _kaydet() async {
    if (_seciliIsletmeId == null) {
      setState(() => _hataMesaji = 'Lütfen işletme seçin.');
      return;
    }
    if (_depoAdiCtrl.text.trim().isEmpty) {
      setState(() => _hataMesaji = 'Depo adı girin.');
      return;
    }

    setState(() {
      _kaydediyor = true;
      _hataMesaji = null;
    });

    final navigator = Navigator.of(context);
    try {
      await DepoService.ekle(_seciliIsletmeId!, _depoAdiCtrl.text.trim());
      navigator.pop();
      widget.onKaydedildi();
    } catch (e) {
      if (!mounted) return;
      String hata = 'Sunucuya bağlanılamadı.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['hata'] != null) {
          hata = data['hata'].toString();
        }
      }
      setState(() {
        _hataMesaji = hata;
        _kaydediyor = false;
      });
    }
  }

  void _showIsletmePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _IsletmePickerSheet(
        isletmeler: widget.isletmeler,
        seciliId: _seciliIsletmeId,
        onSelect: (ist) {
          setState(() => _seciliIsletmeId = ist.id);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                const Text('Depo Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
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
                  // İşletme seçici
                  _labelW('İŞLETME'),
                  GestureDetector(
                    onTap: _showIsletmePicker,
                    child: Container(
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
                                fontWeight: FontWeight.w700,
                                color: _seciliIsletme != null ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Depo Adı
                  _labelW('DEPO ADI'),
                  TextField(
                    controller: _depoAdiCtrl,
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (_) => _kaydet(),
                    decoration: InputDecoration(
                      hintText: 'Örn: Ana Depo, Soğuk Depo...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _P)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Hata mesajı
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

          // Alt butonlar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _sifirla,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, size: 16, color: Color(0xFF6B7280)),
                            SizedBox(width: 6),
                            Text('Sıfırla', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
    ));
  }

  Widget _labelW(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
    );
  }
}

// ──────────────────────────────────────────
// Depo Düzenle Bottom Sheet
// ──────────────────────────────────────────
class _DepoDuzenleSheet extends StatefulWidget {
  final Map<String, dynamic> depo;
  final String? isletmeId;
  final VoidCallback onKaydedildi;
  final bool canEdit;
  final bool canDelete;

  const _DepoDuzenleSheet({required this.depo, this.isletmeId, required this.onKaydedildi, this.canEdit = true, this.canDelete = true});

  @override
  State<_DepoDuzenleSheet> createState() => _DepoDuzenleSheetState();
}

class _DepoDuzenleSheetState extends State<_DepoDuzenleSheet> {
  late TextEditingController _adCtrl;
  bool _kaydediyor = false;
  String? _hataMesaji;
  String? _onayModu; // 'sifirla' | 'sil' | null

  @override
  void initState() {
    super.initState();
    _adCtrl = TextEditingController(text: widget.depo['ad'] ?? '');
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    super.dispose();
  }

  void _sifirla() {
    setState(() {
      _adCtrl.text = widget.depo['ad'] ?? '';
      _hataMesaji = null;
      _onayModu = null;
    });
  }

  Future<void> _sil() async {
    setState(() => _onayModu = null);
    final navigator = Navigator.of(context);
    final depoId = widget.depo['id'];
    try {
      await DepoService.sil(depoId, isletmeId: widget.isletmeId);
      navigator.pop();
      widget.onKaydedildi();
    } catch (e) {
      if (!mounted) return;
      if (e is AktifSayimException) {
        AktifSayimDialog.show(
          context,
          baslik: 'Depo Silinemedi',
          mesaj: e.mesaj,
          sayimAdlari: e.sayimAdlari,
        );
        return;
      }
      String hata;
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['hata'] != null) {
          hata = data['hata'].toString();
        } else if (e.response?.statusCode == 403) {
          hata = 'Bu işlem için yetkiniz yok.';
        } else {
          hata = 'Sunucuya bağlanılamadı.';
        }
      } else {
        hata = e.toString().replaceFirst('Exception: ', '');
      }
      setState(() => _hataMesaji = hata);
    }
  }

  Future<void> _kaydet() async {
    if (_adCtrl.text.trim().isEmpty) {
      setState(() => _hataMesaji = 'Depo adı girin.');
      return;
    }

    setState(() {
      _kaydediyor = true;
      _hataMesaji = null;
    });

    final navigator = Navigator.of(context);
    final depoId = widget.depo['id'];
    try {
      await DepoService.guncelle(depoId, {'ad': _adCtrl.text.trim()});
      navigator.pop();
      widget.onKaydedildi();
    } catch (e) {
      if (!mounted) return;
      String hata = 'Sunucuya bağlanılamadı.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['hata'] != null) {
          hata = data['hata'].toString();
        } else if (e.response?.statusCode == 403) {
          hata = 'Bu işlem için yetkiniz yok.';
        }
      }
      setState(() {
        _hataMesaji = hata;
        _kaydediyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Depo Düzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                    const SizedBox(height: 2),
                    Text(widget.depo['ad'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
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
                  _labelW('DEPO ADI'),
                  TextField(
                    controller: _adCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Depo adı...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _P)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Hata mesajı
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

          // Onay barı
          if (_onayModu != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _onayModu == 'sil' ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _onayModu == 'sil' ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  Icon(
                    _onayModu == 'sil' ? Icons.warning_amber_rounded : Icons.info_outline,
                    size: 16,
                    color: _onayModu == 'sil' ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _onayModu == 'sil'
                          ? 'Bu depoyu silmek istediğinizden emin misiniz?'
                          : 'Yapılan değişiklikler geri alınacak. Emin misiniz?',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _onayModu == 'sil' ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _onayModu = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: const Text('İptal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _onayModu == 'sil' ? _sil : _sifirla,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _onayModu == 'sil' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _onayModu == 'sil' ? 'Sil' : 'Evet',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Alt butonlar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _onayModu = 'sifirla'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, size: 16, color: Color(0xFF6B7280)),
                            SizedBox(width: 6),
                            Text('Sıfırla', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.canDelete) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _onayModu = 'sil'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Sil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
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
    ));
  }

  Widget _labelW(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
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

  const _IsletmePickerSheet({
    required this.isletmeler,
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
                      border: selected
                          ? Border.all(color: _P.withValues(alpha: 0.25), width: 1.5)
                          : Border.all(color: Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors), borderRadius: BorderRadius.circular(12)),
                          child: Center(
                            child: Text(ist.ad.isNotEmpty ? ist.ad[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                          ),
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
