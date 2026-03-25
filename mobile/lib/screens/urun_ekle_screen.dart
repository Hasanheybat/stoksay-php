import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/auth_provider.dart';
import '../services/sayim_service.dart';
import '../services/urun_service.dart';
import '../widgets/bildirim.dart';
import 'app_layout.dart';

const _P = Color(0xFF6C53F5);
const _PL = Color(0x1A6C53F5);

String _formatMiktar(dynamic val) {
  if (val == null) return '';
  final d = double.tryParse(val.toString());
  if (d == null) return val.toString();
  return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}

class UrunEkleScreen extends ConsumerStatefulWidget {
  final String sayimId;
  const UrunEkleScreen({super.key, required this.sayimId});

  @override
  ConsumerState<UrunEkleScreen> createState() => _UrunEkleScreenState();
}

class _UrunEkleScreenState extends ConsumerState<UrunEkleScreen> {
  String? _isletmeId;
  bool _ekleniyor = false;
  String _sonEklenenIsim = '';
  String _sonEklenenMiktar = '';
  String _sonEklenenBirim = '';

  // Form
  String? _urunId;
  final _isimController = TextEditingController();
  final _isim2Controller = TextEditingController();
  final _kodController = TextEditingController();
  String _birim = '';
  String _urunBirim = ''; // ürünün asıl birimi — picker için
  bool _birimAcik = false;
  String _miktar = '';
  List<String> _barkodlar = [];

  // Öneriler
  List<Map<String, dynamic>> _oneriler1 = [];
  bool _bos1 = false;
  bool _acik1 = false;
  List<Map<String, dynamic>> _oneriler2 = [];
  bool _bos2 = false;
  bool _acik2 = false;

  Timer? _debounce1;
  Timer? _debounce2;
  bool _skip1 = false;
  bool _skip2 = false;

  final _isimFocusNode = FocusNode();
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _fetchIsletmeId();

    _isimController.addListener(() {
      if (_skip1) { _skip1 = false; return; }
      if (_urunId != null) return; // ürün seçildiyse arama tetikleme
      _debounce1?.cancel();
      if (_isimController.text.isEmpty || _isletmeId == null) {
        setState(() { _oneriler1 = []; _acik1 = false; _bos1 = false; });
        return;
      }
      _debounce1 = Timer(const Duration(milliseconds: 300), () => _araUrun(_isimController.text, 1));
    });

    _isim2Controller.addListener(() {
      if (_skip2) { _skip2 = false; return; }
      if (_urunId != null) return; // ürün seçildiyse arama tetikleme
      _debounce2?.cancel();
      if (_isim2Controller.text.isEmpty || _isletmeId == null) {
        setState(() { _oneriler2 = []; _acik2 = false; _bos2 = false; });
        return;
      }
      _debounce2 = Timer(const Duration(milliseconds: 300), () => _araUrun(_isim2Controller.text, 2));
    });
  }

  @override
  void dispose() {
    _debounce1?.cancel();
    _debounce2?.cancel();
    _isimController.dispose();
    _isim2Controller.dispose();
    _kodController.dispose();
    _isimFocusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchIsletmeId() async {
    try {
      final data = await SayimService.detay(widget.sayimId);
      if (data['isletme_id'] != null) {
        setState(() => _isletmeId = data['isletme_id'].toString());
      }
    } catch (_) {}
    // Son eklenen kalemi çek
    try {
      final kalemler = await SayimService.kalemListele(widget.sayimId);
      if (kalemler.isNotEmpty) {
        final son = kalemler.last;
        final urun = son['isletme_urunler'];
        setState(() {
          _sonEklenenIsim = urun?['urun_adi']?.toString() ?? '';
          _sonEklenenMiktar = _formatMiktar(son['miktar']);
          _sonEklenenBirim = son['birim']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _araUrun(String q, int alan) async {
    if (_isletmeId == null) return;
    // Ürün zaten seçildiyse arama yapma
    if (_urunId != null) return;
    try {
      final sonuclar = await UrunService.listele(_isletmeId!, arama: q, limit: 10, alan: alan == 2 ? 'isim_2' : null);
      // Arama sonucu döndüğünde ürün seçilmişse listeyi açma
      if (_urunId != null) return;
      setState(() {
        if (alan == 1) {
          _oneriler1 = sonuclar;
          _bos1 = sonuclar.isEmpty;
          _acik1 = true;
        } else {
          _oneriler2 = sonuclar;
          _bos2 = sonuclar.isEmpty;
          _acik2 = true;
        }
      });
    } catch (_) {}
  }

  void _urunSec(Map<String, dynamic> u) {
    _skip1 = true;
    _skip2 = true;
    _debounce1?.cancel();
    _debounce2?.cancel();
    // Focus'u kaldır — öneri listesinin tekrar açılmasını engeller
    FocusScope.of(context).unfocus();
    final kullanici = ref.read(authProvider).kullanici;
    final birimOtomatik = kullanici?.ayarlar['birim_otomatik'] ?? true;
    final urunBirim = u['birim']?.toString() ?? '';
    setState(() {
      _urunId = u['id']?.toString();
      _isimController.text = u['urun_adi']?.toString() ?? '';
      _isim2Controller.text = u['isim_2']?.toString() ?? '';
      _kodController.text = u['urun_kodu']?.toString() ?? '';
      _birim = birimOtomatik ? urunBirim : '';
      _urunBirim = urunBirim; // picker için sakla
      final barkod = u['barkodlar'];
      if (barkod is List) {
        _barkodlar = barkod.map((b) => b.toString()).toList();
      } else if (barkod is String && barkod.isNotEmpty) {
        _barkodlar = barkod.split(',').map((b) => b.trim()).toList();
      } else {
        _barkodlar = [];
      }
      _oneriler1 = []; _acik1 = false; _bos1 = false;
      _oneriler2 = []; _acik2 = false; _bos2 = false;
    });
    if (!birimOtomatik && urunBirim.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _birimAcik = true);
      });
    }
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
                      _bipSesiCal();
                      Navigator.pop(ctx);
                      _barkodTara(barcode!.rawValue!);
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

  void _bipSesiCal() {
    final authState = ref.read(authProvider);
    final barkodSesi = authState.kullanici?.barkodSesi ?? true;
    if (barkodSesi) {
      _audioPlayer.play(AssetSource('sounds/beep.wav'));
    }
  }

  Future<void> _barkodTara(String barkod) async {
    if (_isletmeId == null) return;
    try {
      final urun = await UrunService.barkodBul(_isletmeId!, barkod);
      if (urun != null && urun['id'] != null) {
        _urunSec(urun);
        _showSnack('Ürün bulundu: ${urun['urun_adi'] ?? barkod}');
      } else {
        _showSnack('Bu barkoda ait ürün bulunamadı');
      }
    } catch (_) {
      _showSnack('Bu barkoda ait ürün bulunamadı');
    }
  }

  void _temizle() {
    _skip1 = true;
    _skip2 = true;
    _debounce1?.cancel();
    _debounce2?.cancel();
    setState(() {
      _urunId = null;
      _isimController.clear();
      _isim2Controller.clear();
      _kodController.clear();
      _birim = '';
      _urunBirim = '';
      _miktar = '';
      _barkodlar = [];
      _birimAcik = false;
      _oneriler1 = []; _acik1 = false; _bos1 = false;
      _oneriler2 = []; _acik2 = false; _bos2 = false;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      _isimFocusNode.requestFocus();
    });
  }

  void _showSnack(String msg, {bool basarili = true}) {
    showBildirim(context, msg, basarili: basarili);
  }

  Future<void> _handleEkle(String? miktarOverride) async {
    final miktar = miktarOverride ?? _miktar;
    if (_isimController.text.trim().isEmpty) {
      _showSnack('Ürün ismi boş olamaz.', basarili: false);
      return;
    }
    if (miktar.isEmpty) {
      _showSnack('Miktar girin.', basarili: false);
      return;
    }
    if (_urunId == null) {
      _showSnack('Listeden bir ürün seçin.', basarili: false);
      return;
    }
    if (_birim.isEmpty) {
      _showSnack('Birim seçin.', basarili: false);
      return;
    }

    setState(() => _ekleniyor = true);
    try {
      final sonuc = await SayimService.kalemEkle(widget.sayimId, {
        'urun_id': _urunId,
        'miktar': double.parse(miktar),
        'birim': _birim,
      });
      _showSnack('Ürün sayıma eklendi!');
      _temizle();
      final urun = sonuc['isletme_urunler'];
      setState(() {
        _sonEklenenIsim = urun?['urun_adi']?.toString() ?? '';
        _sonEklenenMiktar = _formatMiktar(sonuc['miktar']);
        _sonEklenenBirim = sonuc['birim']?.toString() ?? '';
      });
    } catch (e) {
      _showSnack('Kalem eklenemedi.', basarili: false);
    }
    setState(() => _ekleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      pageTitle: 'Ürün Ekle',
      showBack: true,
      child: Column(
        children: [
          // Son eklenen gösterge — ortada, sabit
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Center(
              child: _sonEklenenIsim.isNotEmpty
                  ? Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: '✓ ', style: TextStyle(color: Color(0xFF059669))),
                        TextSpan(text: _sonEklenenIsim, style: const TextStyle(color: Color(0xFF059669))),
                        if (_sonEklenenMiktar.isNotEmpty) ...[
                          const TextSpan(text: '  '),
                          TextSpan(text: _sonEklenenMiktar, style: const TextStyle(color: Color(0xFF2563EB))),
                        ],
                        if (_sonEklenenBirim.isNotEmpty) ...[
                          const TextSpan(text: ' '),
                          TextSpan(text: _sonEklenenBirim, style: const TextStyle(color: Color(0xFFEF4444))),
                        ],
                      ]),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const Text(
                      'Son eklenen ürün',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                    ),
            ),
          ),
          // Form
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Boş alana dokunulunca öneri listelerini kapat
                if (_acik1 || _acik2) {
                  setState(() { _acik1 = false; _acik2 = false; });
                }
                FocusScope.of(context).unfocus();
              },
              child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 42, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ürün İsmi 1 + Kamera
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _label('ÜRÜN İSMİ 1'),
                          if (_urunId != null)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Text('✓ seçildi',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                            ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _openBarcodeScanner,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _PL,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.camera_alt, size: 20, color: _P),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildSearchField(
                    controller: _isimController,
                    focusNode: _isimFocusNode,
                    hint: 'Ürün adı girin veya arayın...',
                    borderColor: _urunId != null ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                    oneriler: _oneriler1,
                    bos: _bos1,
                    acik: _acik1,
                    onChanged: (val) {
                      setState(() => _urunId = null);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Birim / Miktar
                  _label('BİRİM / MİKTAR'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Birim — otomatik modda statik, manuel modda tıklanabilir
                      _buildBirimWidget(),
                      const SizedBox(width: 8),
                      // Miktar butonu - hesap makinesi açar
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showHesapMakinesi(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              _miktar.isNotEmpty ? _miktar : 'Miktarı girin...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _miktar.isNotEmpty ? FontWeight.w700 : FontWeight.w400,
                                color: _miktar.isNotEmpty ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Inline birim seçici
                  if (_birimAcik && _urunBirim.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _birim = _urunBirim;
                            _birimAcik = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _birim == _urunBirim ? const Color(0xFFEF4444) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: Text(
                            _urunBirim,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _birim == _urunBirim ? Colors.white : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Ürün İsmi 2
                  _label('ÜRÜN İSMİ 2'),
                  const SizedBox(height: 6),
                  _buildSearchField(
                    controller: _isim2Controller,
                    hint: 'İkinci isim girin veya arayın...',
                    oneriler: _oneriler2,
                    bos: _bos2,
                    acik: _acik2,
                  ),
                  const SizedBox(height: 16),

                  // Ürün Kodu
                  const Text('ÜRÜN KODU',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD1D5DB), letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _kodController,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                    decoration: InputDecoration(
                      hintText: '—',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _P),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Barkodlar
                  if (_barkodlar.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _barkodlar.map((b) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(b,
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF6B7280))),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          ),

          // Alt buton - Temizle
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: GestureDetector(
              onTap: _temizle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Temizle',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightText(
    String text,
    String query, {
    double fontSize = 14,
    Color normalColor = const Color(0xFF6B7280),
    Color boldColor = const Color(0xFF1F2937),
  }) {
    if (query.isEmpty) {
      return Text(text, style: TextStyle(fontSize: fontSize, color: normalColor));
    }
    final lower = text.toLowerCase();
    final qLower = query.toLowerCase().trim();
    final idx = lower.indexOf(qLower);
    if (idx == -1) {
      return Text(text, style: TextStyle(fontSize: fontSize, color: normalColor));
    }
    return RichText(
      text: TextSpan(
        children: [
          if (idx > 0)
            TextSpan(
              text: text.substring(0, idx),
              style: TextStyle(fontSize: fontSize, color: normalColor),
            ),
          TextSpan(
            text: text.substring(idx, idx + qLower.length),
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: boldColor),
          ),
          if (idx + qLower.length < text.length)
            TextSpan(
              text: text.substring(idx + qLower.length),
              style: TextStyle(fontSize: fontSize, color: normalColor),
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

  Widget _buildSearchField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String hint,
    Color borderColor = const Color(0xFFE5E7EB),
    required List<Map<String, dynamic>> oneriler,
    required bool bos,
    required bool acik,
    Function(String)? onChanged,
    VoidCallback? onBlur,
  }) {
    return Column(
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _urunId != null ? const Color(0xFF10B981) : _P),
            ),
            isDense: true,
          ),
        ),
        if (acik)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: bos
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ürün bulunamadı.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                        SizedBox(height: 2),
                        Text('Farklı bir kelime deneyin.',
                            style: TextStyle(fontSize: 10, color: Color(0xFFD1D5DB))),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: oneriler.length,
                    itemBuilder: (ctx, i) {
                      final u = oneriler[i];
                      final alt = [u['isim_2'], u['urun_kodu'], u['birim']]
                          .where((s) => s != null && s.toString().isNotEmpty)
                          .join(' · ');
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _urunSec(u),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            border: i < oneriler.length - 1
                                ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _highlightText(
                                u['urun_adi']?.toString() ?? '',
                                controller.text,
                                fontSize: 13,
                              ),
                              if (alt.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: _highlightText(
                                    alt,
                                    controller.text,
                                    fontSize: 11,
                                    normalColor: const Color(0xFF9CA3AF),
                                    boldColor: const Color(0xFF6B7280),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Widget _buildBirimWidget() {
    final kullanici = ref.read(authProvider).kullanici;
    final birimOtomatik = kullanici?.ayarlar['birim_otomatik'] ?? true;

    if (birimOtomatik) {
      // Otomatik mod — statik gösterim
      return Container(
        constraints: const BoxConstraints(minWidth: 76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _PL,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            _birim.isNotEmpty ? _birim : 'Birim',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _birim.isNotEmpty ? _P : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      );
    } else {
      // Manuel mod — tıklanabilir birim seçici (inline toggle)
      return GestureDetector(
        onTap: () {
          if (_urunBirim.isNotEmpty) {
            setState(() => _birimAcik = !_birimAcik);
          } else {
            _showSnack('Önce ürün seçin.', basarili: false);
          }
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _birim.isNotEmpty ? _PL : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: _birim.isEmpty
                ? Border.all(color: const Color(0xFFD1D5DB), width: 1.5, strokeAlign: BorderSide.strokeAlignInside)
                : null,
          ),
          child: Center(
            child: Text(
              _birim.isNotEmpty ? _birim : 'Birim',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _birim.isNotEmpty ? _P : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
      );
    }
  }

  void _showBirimPicker() {
    // Sadece ürünün kendi birimi gösterilir
    final birimler = <String>{};
    if (_urunBirim.isNotEmpty) birimler.add(_urunBirim);

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
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Birim Seçin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            ...birimler.map((b) => GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _birim = b);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _birim == b ? _PL : Colors.transparent,
                  border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Text(
                  b,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: _birim == b ? FontWeight.w700 : FontWeight.w500,
                    color: _birim == b ? _P : const Color(0xFF4B5563),
                  ),
                ),
              ),
            )),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showHesapMakinesi() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _HesapMakinesi(
        mevcut: _miktar,
        onKapat: () => Navigator.pop(ctx),
        onEkle: (val) {
          Navigator.pop(ctx);
          Future.delayed(const Duration(milliseconds: 200), () => _handleEkle(val));
        },
        onMiktarSec: (val) {
          Navigator.pop(ctx);
          setState(() => _miktar = val);
        },
      ),
    );
  }
}

// ── Hesap Makinesi ──
class _HesapMakinesi extends StatefulWidget {
  final String mevcut;
  final VoidCallback onKapat;
  final Function(String) onEkle;
  final Function(String) onMiktarSec;

  const _HesapMakinesi({
    required this.mevcut,
    required this.onKapat,
    required this.onEkle,
    required this.onMiktarSec,
  });

  @override
  State<_HesapMakinesi> createState() => _HesapMakinesiState();
}

class _HesapMakinesiState extends State<_HesapMakinesi> {
  String _ifade = '';
  String? _sonuc;

  @override
  void initState() {
    super.initState();
    _ifade = widget.mevcut;
  }

  void _tus(String v) {
    setState(() {
      if (_sonuc != null) {
        if (RegExp(r'[0-9.]').hasMatch(v)) {
          _ifade = v;
          _sonuc = null;
        } else {
          _ifade = _sonuc! + v;
          _sonuc = null;
        }
        return;
      }
      _ifade += v;
    });
  }

  void _sil() {
    setState(() {
      if (_sonuc != null) {
        _ifade = '';
        _sonuc = null;
        return;
      }
      if (_ifade.isNotEmpty) _ifade = _ifade.substring(0, _ifade.length - 1);
    });
  }

  void _temizle() {
    setState(() {
      _ifade = '';
      _sonuc = null;
    });
  }

  void _hesapla() {
    if (_ifade.isEmpty) return;
    try {
      // Simple expression evaluator
      final expr = _ifade.replaceAll('×', '*').replaceAll('÷', '/');
      final result = _evalExpression(expr);
      if (result != null && result.isFinite && !result.isNaN) {
        setState(() => _sonuc = _formatNumber(result));
      }
    } catch (_) {}
  }

  double? _evalExpression(String expr) {
    try {
      // Simple tokenizer for basic math
      expr = expr.trim();
      if (expr.isEmpty) return null;

      // Handle simple expressions with +, -, *, /
      List<String> tokens = [];
      String current = '';
      for (int i = 0; i < expr.length; i++) {
        final c = expr[i];
        if ('+-*/'.contains(c) && current.isNotEmpty) {
          tokens.add(current);
          tokens.add(c);
          current = '';
        } else {
          current += c;
        }
      }
      if (current.isNotEmpty) tokens.add(current);

      if (tokens.isEmpty) return null;

      // First pass: * and /
      List<dynamic> pass1 = [];
      double val = double.parse(tokens[0]);
      for (int i = 1; i < tokens.length; i += 2) {
        final op = tokens[i];
        final next = double.parse(tokens[i + 1]);
        if (op == '*') {
          val *= next;
        } else if (op == '/') {
          val /= next;
        } else {
          pass1.add(val);
          pass1.add(op);
          val = next;
        }
      }
      pass1.add(val);

      // Second pass: + and -
      double result = pass1[0] as double;
      for (int i = 1; i < pass1.length; i += 2) {
        final op = pass1[i] as String;
        final next = pass1[i + 1] as double;
        if (op == '+') result += next;
        else if (op == '-') result -= next;
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  String _formatNumber(double n) {
    final s = n.toStringAsFixed(8);
    // Remove trailing zeros
    if (s.contains('.')) {
      String trimmed = s;
      while (trimmed.endsWith('0')) trimmed = trimmed.substring(0, trimmed.length - 1);
      if (trimmed.endsWith('.')) trimmed = trimmed.substring(0, trimmed.length - 1);
      return trimmed;
    }
    return s;
  }

  void _sayimaEkle() {
    String val;
    if (_sonuc != null) {
      val = _sonuc!;
    } else if (_ifade.isNotEmpty) {
      final expr = _ifade.replaceAll('×', '*').replaceAll('÷', '/');
      final result = _evalExpression(expr);
      val = result != null && result.isFinite && !result.isNaN
          ? _formatNumber(result)
          : _ifade;
    } else {
      val = '0';
    }
    widget.onEkle(val);
  }

  @override
  Widget build(BuildContext context) {
    // İfade metni (üstte küçük gösterilecek)
    final exprText = _ifade.isEmpty ? '' : _ifade;
    // Anlık hesaplama sonucu (altta büyük gösterilecek)
    String resultText;
    if (_sonuc != null) {
      resultText = _sonuc!;
    } else if (_ifade.isNotEmpty && RegExp(r'[+\-×÷]').hasMatch(_ifade)) {
      // Sondaki operatörü kaldırarak hesapla (3+6+ → 3+6 = 9)
      String cleanExpr = _ifade;
      while (cleanExpr.isNotEmpty && RegExp(r'[+\-×÷]$').hasMatch(cleanExpr)) {
        cleanExpr = cleanExpr.substring(0, cleanExpr.length - 1);
      }
      final expr = cleanExpr.replaceAll('×', '*').replaceAll('÷', '/');
      final preview = _evalExpression(expr);
      if (preview != null && preview.isFinite && !preview.isNaN) {
        resultText = _formatNumber(preview);
      } else {
        resultText = _ifade;
      }
    } else {
      resultText = _ifade.isEmpty ? '0' : _ifade;
    }

    const rows = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['.', '0', '⌫', '+'],
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // Ekran
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Üst: yazılan ifade (küçük)
                SizedBox(
                  height: 20,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      exprText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Alt: sonuç / toplam (büyük)
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      resultText,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tuş takımı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ...rows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: row.map((t) {
                        final isOp = '+-×÷'.contains(t);
                        final isDel = t == '⌫';
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () => isDel ? _sil() : _tus(t),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isOp
                                      ? _PL
                                      : isDel
                                          ? const Color(0xFFFEF2F2)
                                          : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: RegExp(r'[0-9.]').hasMatch(t) ? 20 : 18,
                                      fontWeight: FontWeight.w700,
                                      color: isOp
                                          ? _P
                                          : isDel
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
                // C = Sayıma Ekle
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: _temizle,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text('C',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFEF4444))),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: _hesapla,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: _P,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text('=',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: _sayimaEkle,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text('Sayıma\nEkle',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.2)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
