import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../providers/isletme_provider.dart';
import '../models/isletme.dart';
import '../services/urun_service.dart';
import '../services/storage_service.dart';
import '../services/offline_id_service.dart';
import '../services/depo_service.dart' show AktifSayimException;
import '../widgets/bildirim.dart';
import '../widgets/aktif_sayim_dialog.dart';
import 'app_layout.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _P = Color(0xFF6C53F5);
const _PL = Color(0x1A6C53F5);

const List<List<Color>> _GRADS = [
  [Color(0xFF6C53F5), Color(0xFF8B5CF6)],
  [Color(0xFF0EA5E9), Color(0xFF2563EB)],
  [Color(0xFF10B981), Color(0xFF059669)],
  [Color(0xFFF59E0B), Color(0xFFD97706)],
  [Color(0xFFEC4899), Color(0xFFDB2777)],
];

class StoklarScreen extends ConsumerStatefulWidget {
  const StoklarScreen({super.key});

  @override
  ConsumerState<StoklarScreen> createState() => _StoklarScreenState();
}

class _StoklarScreenState extends ConsumerState<StoklarScreen> {
  List<Isletme> _isletmeler = [];
  String? _seciliIsletmeId;
  List<Map<String, dynamic>> _urunler = [];
  List<Map<String, dynamic>> _filtreliUrunler = [];
  String _aramaStr = '';
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
        .where((i) => auth.isletmeYetkisi(i.id, 'urun', 'goruntule'))
        .toList();
    setState(() {
      _isletmeler = list;
      if (list.isNotEmpty) _seciliIsletmeId = list.first.id;
    });
    if (_seciliIsletmeId != null) _fetchUrunler(_seciliIsletmeId!);
  }

  Future<void> _fetchUrunler(String isletmeId) async {
    setState(() => _yukleniyor = true);
    try {
      final list = await UrunService.listele(isletmeId, limit: 10000);
      setState(() {
        _urunler = list;
        _filtreliUrunler = list;
        _yukleniyor = false;
      });
    } catch (_) {
      setState(() {
        _urunler = [];
        _filtreliUrunler = [];
        _yukleniyor = false;
      });
    }
  }

  void _filtrele(String query) {
    setState(() {
      _aramaStr = query;
      if (query.trim().isEmpty) {
        _filtreliUrunler = _urunler;
      } else {
        final q = query.toLowerCase();
        _filtreliUrunler = _urunler.where((u) {
          final ad = (u['urun_adi'] ?? '').toString().toLowerCase();
          final isim2 = (u['isim_2'] ?? '').toString().toLowerCase();
          final kod = (u['urun_kodu'] ?? '').toString().toLowerCase();
          final barkodlar = (u['barkodlar'] ?? '').toString().toLowerCase();
          return ad.contains(q) || isim2.contains(q) || kod.contains(q) || barkodlar.contains(q);
        }).toList();
      }
    });
  }

  Isletme? get _seciliIsletme =>
      _isletmeler.where((i) => i.id == _seciliIsletmeId).firstOrNull;

  void _showIsletmePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Icon(Icons.business, color: _P, size: 20),
                SizedBox(width: 8),
                Text('İşletme Seçin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              ]),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _isletmeler.length,
                itemBuilder: (_, index) {
                  final i = _isletmeler[index];
                  final selected = i.id == _seciliIsletmeId;
                  final colors = [
                    [const Color(0xFF6C53F5), const Color(0xFF8B5CF6)],
                    [const Color(0xFF0EA5E9), const Color(0xFF2563EB)],
                    [const Color(0xFF10B981), const Color(0xFF059669)],
                    [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                    [const Color(0xFFEC4899), const Color(0xFFDB2777)],
                  ];
                  final gradColors = colors[index % colors.length];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _seciliIsletmeId = i.id);
                      _fetchUrunler(i.id);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? _P.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: selected ? Border.all(color: _P.withValues(alpha: 0.3)) : Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors), borderRadius: BorderRadius.circular(10)),
                          child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(i.ad, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1F2937)))),
                        if (selected) Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showStokDuzenle(Map<String, dynamic> urun) {
    final auth = ref.read(authProvider.notifier);
    final isOffline = StorageService.isOffline;
    final isTempUrun = OfflineIdService.isTempId(urun['id']);
    // Offline'da sadece temp ürünler düzenlenebilir/silinebilir
    final canEdit = _seciliIsletmeId != null
        && auth.isletmeYetkisi(_seciliIsletmeId!, 'urun', 'duzenle')
        && (!isOffline || isTempUrun);
    final canDelete = _seciliIsletmeId != null
        && auth.isletmeYetkisi(_seciliIsletmeId!, 'urun', 'sil')
        && (!isOffline || isTempUrun);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StokDuzenleSheet(
        urun: urun,
        isletmeler: _isletmeler,
        canEdit: canEdit,
        canDelete: canDelete,
        onKaydedildi: () {
          if (_seciliIsletmeId != null) _fetchUrunler(_seciliIsletmeId!);
          showBildirim(context, 'Stok güncellendi', tip: BildirimTip.bilgi);
        },
        onSilindi: () {
          if (_seciliIsletmeId != null) _fetchUrunler(_seciliIsletmeId!);
          showBildirim(context, 'Stok silindi', tip: BildirimTip.hata);
        },
      ),
    );
  }

  void _showStokEkle() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StokEkleSheet(
        isletmeler: _isletmeler,
        seciliIsletmeId: _seciliIsletmeId,
        onKaydedildi: () {
          if (_seciliIsletmeId != null) _fetchUrunler(_seciliIsletmeId!);
          showBildirim(context, 'Stok eklendi');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEkle = _seciliIsletmeId != null && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'urun', 'ekle');
    return AppLayout(
      pageTitle: 'Stoklar',
      showBack: true,
      onHeaderAction: canEkle ? _showStokEkle : null,
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
                    Flexible(
                      flex: 3,
                      child: GestureDetector(
                        onTap: _showIsletmePicker,
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
                    Flexible(
                      flex: 2,
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
              if (!_yukleniyor && _urunler.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${_filtreliUrunler.length} / ${_urunler.length} ürün',
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

              // Ürün listesi
              Expanded(
                child: _yukleniyor
                    ? Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: _P,
                          ),
                        ),
                      )
                    : _isletmeler.isEmpty
                        ? _EmptyState(
                            icon: Icons.business,
                            title: 'Atanmış işletme yok',
                            subtitle: 'Yöneticinizle iletişime geçin',
                          )
                        : _filtreliUrunler.isEmpty
                            ? _EmptyState(
                                icon: Icons.search,
                                title: 'Ürün bulunamadı',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                                itemCount: _filtreliUrunler.length,
                                itemBuilder: (ctx, i) {
                                  final u = _filtreliUrunler[i];
                                  final isOffline = StorageService.isOffline;
                                  final isTempUrun = OfflineIdService.isTempId(u['id']);
                                  final canDuzenle = _seciliIsletmeId != null
                                      && ref.read(authProvider.notifier).isletmeYetkisi(_seciliIsletmeId!, 'urun', 'duzenle')
                                      && (!isOffline || isTempUrun); // Offline'da sadece temp ürünler düzenlenebilir
                                  return _UrunCard(
                                    urun: u,
                                    onDuzenle: canDuzenle ? () => _showStokDuzenle(u) : null,
                                    soluk: isOffline && !isTempUrun, // Sunucu ürünleri soluk
                                  );
                                },
                              ),
              ),
            ],
          ),
    );
  }
}

// Ürün kart widget
class _UrunCard extends StatelessWidget {
  final Map<String, dynamic> urun;
  final VoidCallback? onDuzenle;
  final bool soluk;
  const _UrunCard({required this.urun, this.onDuzenle, this.soluk = false});

  @override
  Widget build(BuildContext context) {
    final ad = urun['urun_adi'] ?? '';
    final isim2 = urun['isim_2'];
    final kod = urun['urun_kodu'] ?? '';
    final birim = urun['birim'] ?? '';

    return Opacity(
      opacity: soluk ? 0.45 : 1.0,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          // Sol: İsim + birim + kod
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ad,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _PL,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        birim,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _P,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isim2 != null && isim2.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      isim2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      kod,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onDuzenle != null) ...[
            const SizedBox(width: 6),
            // Düzenle butonu
            GestureDetector(
              onTap: onDuzenle,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _PL,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, size: 14, color: _P),
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }
}

// Birim listesi
const List<String> _BIRIMLER = ['ADET','KG','GR','LT','ML','KOLİ','PAKET','KUTU','ÇUVAL','METRE','RULO','TON'];

// Stok Ekle Bottom Sheet
class _StokEkleSheet extends StatefulWidget {
  final List<Isletme> isletmeler;
  final String? seciliIsletmeId;
  final VoidCallback onKaydedildi;

  const _StokEkleSheet({
    required this.isletmeler,
    required this.seciliIsletmeId,
    required this.onKaydedildi,
  });

  @override
  State<_StokEkleSheet> createState() => _StokEkleSheetState();
}

class _StokEkleSheetState extends State<_StokEkleSheet> {
  late String? _isletmeId;
  final _urunAdiCtrl = TextEditingController();
  final _isim2Ctrl = TextEditingController();
  final _urunKoduCtrl = TextEditingController();
  final _manuelBarkodCtrl = TextEditingController();
  List<String> _barkodlar = [];
  String? _birim;
  bool _kaydediyor = false;
  String? _hataMesaji;

  @override
  void initState() {
    super.initState();
    _isletmeId = widget.seciliIsletmeId;
  }

  @override
  void dispose() {
    _urunAdiCtrl.dispose();
    _isim2Ctrl.dispose();
    _urunKoduCtrl.dispose();
    _manuelBarkodCtrl.dispose();
    super.dispose();
  }

  Isletme? get _seciliIsletme =>
      widget.isletmeler.where((i) => i.id == _isletmeId).firstOrNull;

  void _barkodEkle(String deger) {
    final temiz = deger.trim();
    if (temiz.isEmpty) return;
    if (_barkodlar.contains(temiz)) {
      showBildirim(context, 'Bu barkod zaten ekli.', basarili: false);
      return;
    }
    setState(() => _barkodlar = [..._barkodlar, temiz]);
    _manuelBarkodCtrl.clear();
  }

  void _barkodSil(String b) {
    setState(() => _barkodlar = _barkodlar.where((x) => x != b).toList());
  }

  void _temizle() {
    setState(() {
      _urunAdiCtrl.clear();
      _isim2Ctrl.clear();
      _urunKoduCtrl.clear();
      _manuelBarkodCtrl.clear();
      _barkodlar = [];
      _birim = null;
      _isletmeId = widget.seciliIsletmeId;
      _hataMesaji = null;
    });
  }

  Future<void> _kaydet() async {
    // Validasyon — sadece İsim 1 ve Birim zorunlu
    if (_urunAdiCtrl.text.trim().isEmpty) {
      setState(() => _hataMesaji = 'Stok adı (İsim 1) girin.');
      return;
    }
    if (_birim == null) {
      setState(() => _hataMesaji = 'Birim seçin.');
      return;
    }

    setState(() {
      _kaydediyor = true;
      _hataMesaji = null;
    });

    final navigator = Navigator.of(context);

    try {
      final barkodStr = _barkodlar.join(',');
      final urunKodu = _urunKoduCtrl.text.trim();
      await UrunService.ekle({
        'isletme_id': _isletmeId,
        'urun_adi': _urunAdiCtrl.text.trim(),
        'isim_2': _isim2Ctrl.text.trim(),
        if (urunKodu.isNotEmpty) 'urun_kodu': urunKodu,
        'barkodlar': barkodStr,
        'birim': _birim,
      });
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
        _kaydediyor = false;
        _hataMesaji = hata;
      });
    }
  }

  void _showBirimPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Birim Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.5,
                children: _BIRIMLER.map((b) {
                  final selected = _birim == b;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _birim = b);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? _P : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          b,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  void _showIsletmePickerForForm() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _PL, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.business, size: 16, color: _P),
                ),
                const SizedBox(width: 8),
                const Text('İşletme Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
              ]),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.isletmeler.length,
                itemBuilder: (_, index) {
                  final i = widget.isletmeler[index];
                  final aktif = i.id == _isletmeId;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _isletmeId = i.id);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: aktif ? _PL : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: aktif ? Border.all(color: _P.withValues(alpha: 0.25)) : Border.all(color: Colors.transparent),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF6C53F5), Color(0xFF8B5CF6)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text(i.ad.isNotEmpty ? i.ad[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.ad, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1F2937))),
                              if (i.kod != null && i.kod!.isNotEmpty)
                                Text(i.kod!, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        if (aktif)
                          Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(color: _P, shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _openBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Barkod Okut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            // Scanner
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcode = capture.barcodes.firstOrNull;
                    if (barcode?.rawValue != null) {
                      Navigator.pop(ctx);
                      _barkodEkle(barcode!.rawValue!);
                    }
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Barkodu çerçeve içine hizalayın', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 16),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),

          // Başlık
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yeni Stok Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                    SizedBox(height: 2),
                    Text('Tüm alanları doldurun', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Form - scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İşletme Seçici
                  _label('İŞLETME'),
                  GestureDetector(
                    onTap: _showIsletmePickerForForm,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.business, size: 16, color: _P),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _seciliIsletme?.ad ?? 'İşletme seçin...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _seciliIsletme != null ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9CA3AF)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // İsim 1
                  _label('İSİM 1 — SAYIM İSMİ *'),
                  _input(_urunAdiCtrl, 'Sayımda kullanılan isim... (örn: Patates)'),
                  const SizedBox(height: 20),

                  // İsim 2
                  Row(
                    children: [
                      _label('İSİM 2 — STOK İSMİ'),
                      const SizedBox(width: 4),
                      const Text('(opsiyonel)', style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB))),
                    ],
                  ),
                  _input(_isim2Ctrl, 'Sistem / resmi isim... (örn: Potato)'),
                  const SizedBox(height: 20),

                  // Stok Kodu
                  _label('STOK KODU'),
                  _input(_urunKoduCtrl, 'Örn: ALF-013', mono: true),
                  const SizedBox(height: 20),

                  // Barkodlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _label('BARKODLAR'),
                      GestureDetector(
                        onTap: _openBarcodeScanner,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: _PL, borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt, size: 14, color: _P),
                              SizedBox(width: 6),
                              Text('Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Barkod chips
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: _barkodlar.isEmpty
                        ? const Text('Barkod yok — kamera veya manuel ekle', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _barkodlar.map((b) => GestureDetector(
                              onTap: () => _barkodSil(b),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: _PL, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(b, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: _P)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.close, size: 12, color: _P.withValues(alpha: 0.6)),
                                  ],
                                ),
                              ),
                            )).toList(),
                          ),
                  ),
                  const SizedBox(height: 8),
                  // Manuel barkod girişi
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manuelBarkodCtrl,
                          onSubmitted: _barkodEkle,
                          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: 'Manuel barkod gir...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        onTap: () => _barkodEkle(_manuelBarkodCtrl.text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: _P, borderRadius: BorderRadius.circular(12)),
                          child: const Text('Ekle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Birim
                  _label('BİRİM *'),
                  GestureDetector(
                    onTap: _showBirimPicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _birim == null && _hataMesaji != null && _hataMesaji!.contains('Birim') ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _birim ?? 'Birim seçin...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _birim != null ? _P : const Color(0xFF9CA3AF),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9CA3AF)),
                        ],
                      ),
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
                  Expanded(
                    child: Text(
                      _hataMesaji!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ),

          // Alt butonlar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Temizle
                  Expanded(
                    child: GestureDetector(
                      onTap: _temizle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, size: 16, color: Color(0xFF6B7280)),
                            SizedBox(width: 6),
                            Text('Temizle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Ekle
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _kaydediyor ? null : _kaydet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF6C53F5), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_kaydediyor)
                              const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            else
                              const Icon(Icons.add, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              _kaydediyor ? 'Ekleniyor...' : 'Ekle',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, {bool mono = false}) {
    return TextField(
      controller: ctrl,
      style: TextStyle(fontSize: 14, fontFamily: mono ? 'monospace' : null),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _P)),
        isDense: true,
      ),
    );
  }
}

// Stok Düzenle Bottom Sheet
class _StokDuzenleSheet extends StatefulWidget {
  final Map<String, dynamic> urun;
  final List<Isletme> isletmeler;
  final VoidCallback onKaydedildi;
  final VoidCallback? onSilindi;
  final bool canEdit;
  final bool canDelete;

  const _StokDuzenleSheet({
    required this.urun,
    required this.isletmeler,
    required this.onKaydedildi,
    this.onSilindi,
    this.canEdit = true,
    this.canDelete = true,
  });

  @override
  State<_StokDuzenleSheet> createState() => _StokDuzenleSheetState();
}

class _StokDuzenleSheetState extends State<_StokDuzenleSheet> {
  final _urunAdiCtrl = TextEditingController();
  final _isim2Ctrl = TextEditingController();
  final _urunKoduCtrl = TextEditingController();
  final _manuelBarkodCtrl = TextEditingController();
  List<String> _barkodlar = [];
  String? _birim;
  bool _kaydediyor = false;
  String? _hataMesaji;
  String? _onayModu; // 'sifirla' | 'sil' | null

  @override
  void initState() {
    super.initState();
    _urunAdiCtrl.text = widget.urun['urun_adi'] ?? '';
    _isim2Ctrl.text = widget.urun['isim_2'] ?? '';
    _urunKoduCtrl.text = widget.urun['urun_kodu'] ?? '';
    _birim = widget.urun['birim'] ?? 'ADET';
    // Barkodları parse et
    final barkodRaw = widget.urun['barkodlar'];
    if (barkodRaw is String && barkodRaw.isNotEmpty) {
      _barkodlar = barkodRaw.split(',').map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
    } else if (barkodRaw is List) {
      _barkodlar = List<String>.from(barkodRaw);
    }
  }

  @override
  void dispose() {
    _urunAdiCtrl.dispose();
    _isim2Ctrl.dispose();
    _urunKoduCtrl.dispose();
    _manuelBarkodCtrl.dispose();
    super.dispose();
  }

  void _barkodEkle(String deger) {
    final temiz = deger.trim();
    if (temiz.isEmpty) return;
    if (_barkodlar.contains(temiz)) {
      setState(() => _hataMesaji = 'Bu barkod zaten ekli.');
      return;
    }
    setState(() {
      _barkodlar = [..._barkodlar, temiz];
      _hataMesaji = null;
    });
    _manuelBarkodCtrl.clear();
  }

  void _barkodSil(String b) {
    setState(() => _barkodlar = _barkodlar.where((x) => x != b).toList());
  }

  void _sifirla() {
    setState(() {
      _urunAdiCtrl.text = widget.urun['urun_adi'] ?? '';
      _isim2Ctrl.text = widget.urun['isim_2'] ?? '';
      _urunKoduCtrl.text = widget.urun['urun_kodu'] ?? '';
      _birim = widget.urun['birim'] ?? 'ADET';
      final barkodRaw = widget.urun['barkodlar'];
      if (barkodRaw is String && barkodRaw.isNotEmpty) {
        _barkodlar = barkodRaw.split(',').map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
      } else if (barkodRaw is List) {
        _barkodlar = List<String>.from(barkodRaw);
      } else {
        _barkodlar = [];
      }
      _hataMesaji = null;
      _onayModu = null;
    });
  }

  Future<void> _sil() async {
    setState(() => _onayModu = null);
    final navigator = Navigator.of(context);
    final urunId = widget.urun['id'];
    try {
      await UrunService.sil(urunId, isletmeId: widget.urun['isletme_id']?.toString());
      navigator.pop();
      if (widget.onSilindi != null) {
        widget.onSilindi!();
      } else {
        widget.onKaydedildi();
      }
    } catch (e) {
      if (!mounted) return;
      if (e is AktifSayimException) {
        AktifSayimDialog.show(
          context,
          baslik: 'Ürün Silinemedi',
          mesaj: e.mesaj,
          sayimAdlari: e.sayimAdlari,
        );
        return;
      }
      String hata = 'Bir hata oluştu.';
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
        hata = e.toString();
      }
      setState(() => _hataMesaji = hata);
    }
  }

  Future<void> _kaydet() async {
    if (_urunAdiCtrl.text.trim().isEmpty) {
      setState(() => _hataMesaji = 'Stok adı (İsim 1) girin.');
      return;
    }
    if (_birim == null) {
      setState(() => _hataMesaji = 'Birim seçin.');
      return;
    }

    setState(() {
      _kaydediyor = true;
      _hataMesaji = null;
    });

    final navigator = Navigator.of(context);
    final urunId = widget.urun['id'];

    try {
      final urunKodu = _urunKoduCtrl.text.trim();
      await UrunService.guncelle(urunId, {
        'urun_adi': _urunAdiCtrl.text.trim(),
        'isim_2': _isim2Ctrl.text.trim(),
        'urun_kodu': urunKodu,
        'barkodlar': _barkodlar.join(','),
        'birim': _birim,
      });
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
        _kaydediyor = false;
        _hataMesaji = hata;
      });
    }
  }

  void _showBirimPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Birim Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.5,
                children: _BIRIMLER.map((b) {
                  final selected = _birim == b;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _birim = b);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? _P : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          b,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  void _openBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Barkod Okut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcode = capture.barcodes.firstOrNull;
                    if (barcode?.rawValue != null) {
                      Navigator.pop(ctx);
                      _barkodEkle(barcode!.rawValue!);
                    }
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Barkodu çerçeve içine hizalayın', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urunKodu = widget.urun['urun_kodu'] ?? '';
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
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
                    const Text('Stok Düzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                    const SizedBox(height: 2),
                    Text(urunKodu, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontFamily: 'monospace')),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
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
                  // İsim 1
                  _labelW('İSİM 1 — SAYIM İSMİ *'),
                  _inputW(_urunAdiCtrl, 'Sayımda kullanılan isim...'),
                  const SizedBox(height: 20),

                  // İsim 2
                  Row(
                    children: [
                      _labelW('İSİM 2 — STOK İSMİ'),
                      const SizedBox(width: 4),
                      const Text('(opsiyonel)', style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB))),
                    ],
                  ),
                  _inputW(_isim2Ctrl, 'Sistem / resmi isim...'),
                  const SizedBox(height: 20),

                  // Stok Kodu
                  _labelW('STOK KODU'),
                  _inputW(_urunKoduCtrl, 'Örn: ALF-013', mono: true),
                  const SizedBox(height: 20),

                  // Barkodlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _labelW('BARKODLAR'),
                      GestureDetector(
                        onTap: _openBarcodeScanner,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: _PL, borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt, size: 14, color: _P),
                              SizedBox(width: 6),
                              Text('Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: _barkodlar.isEmpty
                        ? const Text('Barkod yok — kamera veya manuel ekle', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _barkodlar.map((b) => GestureDetector(
                              onTap: () => _barkodSil(b),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: _PL, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(b, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: _P)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.close, size: 12, color: _P.withValues(alpha: 0.6)),
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
                          controller: _manuelBarkodCtrl,
                          onSubmitted: _barkodEkle,
                          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: 'Manuel barkod gir...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        onTap: () => _barkodEkle(_manuelBarkodCtrl.text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: _P, borderRadius: BorderRadius.circular(12)),
                          child: const Text('Ekle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Birim
                  _labelW('BİRİM *'),
                  GestureDetector(
                    onTap: _showBirimPicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _birim == null && _hataMesaji != null && _hataMesaji!.contains('Birim') ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _birim ?? 'Birim seçin...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _birim != null ? _P : const Color(0xFF9CA3AF),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9CA3AF)),
                        ],
                      ),
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
                  Expanded(
                    child: Text(
                      _hataMesaji!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                    ),
                  ),
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
                          ? 'Bu ürünü silmek istediğinizden emin misiniz?'
                          : 'Yapılan değişiklikler geri alınacak. Emin misiniz?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _onayModu == 'sil' ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _onayModu = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
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
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _onayModu = 'sifirla'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                      onTap: (_kaydediyor || !widget.canEdit) ? null : _kaydet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.canEdit
                                ? [const Color(0xFF6C53F5), const Color(0xFF8B5CF6)]
                                : [const Color(0xFF9CA3AF), const Color(0xFF9CA3AF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_kaydediyor)
                              const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            else
                              const Icon(Icons.check, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              _kaydediyor ? 'Kaydediliyor...' : 'Kaydet',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
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

  Widget _labelW(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
      ),
    );
  }

  Widget _inputW(TextEditingController ctrl, String hint, {bool mono = false}) {
    return TextField(
      controller: ctrl,
      style: TextStyle(fontSize: 14, fontFamily: mono ? 'monospace' : null),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _P)),
        isDense: true,
      ),
    );
  }
}

// Boş durum widget
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
              Text(subtitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ],
        ),
      ),
    );
  }
}
