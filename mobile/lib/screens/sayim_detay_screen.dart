import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as xl;
import '../services/sayim_service.dart';
import '../widgets/bildirim.dart';
import 'app_layout.dart';

const _P = Color(0xFF6C53F5);
const _PL = Color(0x1A6C53F5);

class SayimDetayScreen extends ConsumerStatefulWidget {
  final String sayimId;
  const SayimDetayScreen({super.key, required this.sayimId});

  @override
  ConsumerState<SayimDetayScreen> createState() => _SayimDetayScreenState();
}

class _SayimDetayScreenState extends ConsumerState<SayimDetayScreen> {
  Map<String, dynamic>? _sayim;
  List<Map<String, dynamic>> _kalemler = [];
  bool _yukleniyor = true;
  bool _tamamlaniyor = false;
  String _aramaMetni = '';
  Set<int> _acikKalemler = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSayim());
  }

  Future<void> _fetchSayim() async {
    setState(() => _yukleniyor = true);
    try {
      final kalemler = await SayimService.kalemListele(widget.sayimId);
      // Reverse to show newest first
      setState(() {
        _kalemler = kalemler.reversed.toList();
        _yukleniyor = false;
      });
    } catch (_) {
      setState(() => _yukleniyor = false);
    }

    // Fetch sayim details
    try {
      final res = await _fetchSayimDetay();
      if (res != null) {
        setState(() => _sayim = res);
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _fetchSayimDetay() async {
    try {
      final res = await _getSayimById(widget.sayimId);
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getSayimById(String id) async {
    // Use the API directly via Dio
    final res = await SayimService.detay(id);
    return res;
  }

  Future<void> _fetchKalemler() async {
    try {
      final kalemler = await SayimService.kalemListele(widget.sayimId);
      setState(() => _kalemler = kalemler.reversed.toList());
    } catch (_) {}
  }

  bool get _devam => _sayim?['durum'] == 'devam';

  List<Map<String, dynamic>> get _filtreliKalemler {
    if (_aramaMetni.isEmpty) return _kalemler;
    final q = _aramaMetni.toLowerCase();
    return _kalemler.where((k) {
      final urun = k['isletme_urunler'] as Map<String, dynamic>? ?? {};
      final ad = urun['urun_adi']?.toString().toLowerCase() ?? '';
      final isim2 = urun['isim_2']?.toString().toLowerCase() ?? '';
      final kod = urun['urun_kodu']?.toString().toLowerCase() ?? '';
      final barkod = urun['barkodlar']?.toString().toLowerCase() ?? '';
      return ad.contains(q) || isim2.contains(q) || kod.contains(q) || barkod.contains(q);
    }).toList();
  }

  String get _tarihStr {
    final tarih = _sayim?['tarih'];
    if (tarih == null) return '—';
    try {
      final dt = DateTime.parse(tarih.toString());
      const aylar = [
        '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${aylar[dt.month]} ${dt.year}';
    } catch (_) {
      return tarih.toString();
    }
  }

  void _showSnack(String msg, {bool basarili = true, BildirimTip? tip}) {
    showBildirim(context, msg, basarili: basarili, tip: tip);
  }

  Future<void> _handleTamamla() async {
    if (_kalemler.isEmpty) {
      _showSnack('Sayıma en az 1 ürün ekleyin.', basarili: false);
      return;
    }
    setState(() => _tamamlaniyor = true);
    try {
      await SayimService.tamamla(widget.sayimId);
      _showSnack('Sayım tamamlandı!');
      if (mounted) context.pop(true);
    } catch (e) {
      _showSnack('Sayım tamamlanamadı.', basarili: false);
    }
    setState(() => _tamamlaniyor = false);
  }

  Future<void> _handleKalemSil(dynamic kalemId) async {
    try {
      await SayimService.kalemSil(widget.sayimId, kalemId);
      setState(() => _kalemler.removeWhere((k) => k['id'] == kalemId));
      _showSnack('Kalem silindi.', tip: BildirimTip.hata);
    } catch (e) {
      _showSnack('Kalem silinemedi.', basarili: false);
    }
  }

  Future<void> _handleGuncelle(dynamic kalemId, String yeniMiktar) async {
    if (yeniMiktar.isEmpty) {
      _showSnack('Miktar girin.', basarili: false);
      return;
    }
    try {
      await SayimService.kalemGuncelle(widget.sayimId, kalemId, {'miktar': double.parse(yeniMiktar)});
      setState(() {
        _kalemler = _kalemler.map((k) {
          if (k['id'] == kalemId) {
            return {...k, 'miktar': double.parse(yeniMiktar)};
          }
          return k;
        }).toList();
      });
      _showSnack('Miktar güncellendi.', tip: BildirimTip.bilgi);
    } catch (e) {
      _showSnack('Güncelleme başarısız.', basarili: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      pageTitle: 'Sayım Detay',
      showBack: true,
      child: Column(
        children: [
          // Üst bar - Sayım adı + aksiyonlar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                // Depo adı (ilk 5 harf)
                Text(
                  (() {
                    final depo = _sayim?['depolar']?['ad']?.toString() ?? '';
                    return depo.length > 5 ? '${depo.substring(0, 5)}..' : depo;
                  })(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(width: 6),
                // Bilgi butonu
                _iconBtn(Icons.info_outline, () => _showBilgi()),
                const SizedBox(width: 8),
                // Arama alanı
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      onChanged: (val) => setState(() => _aramaMetni = val),
                      decoration: InputDecoration(
                        hintText: 'Ara...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _P)),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Paylaş butonu (sadece tamamlanmış sayımlar)
                if (!_devam)
                  _iconBtn(Icons.share, () => _showPaylas()),
                // Tamamla butonu
                if (_devam) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      if (_kalemler.isEmpty) {
                        _showSnack('Sayıma en az 1 ürün ekleyin.', basarili: false);
                        return;
                      }
                      _showTamamlaOnay();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('Tamamla',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669))),
                        ],
                      ),
                    ),
                  ),
                ],
                // Ürün Ekle butonu
                if (_devam) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () async {
                      await context.push('/sayim/${widget.sayimId}/urun-ekle');
                      _fetchKalemler();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_P, Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Kalemler listesi
          Expanded(
            child: _yukleniyor
                ? const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3, color: _P),
                    ),
                  )
                : _filtreliKalemler.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Text(
                            _aramaMetni.isNotEmpty ? 'Sonuç bulunamadı.' : (_devam ? 'Henüz ürün eklenmedi.' : 'Bu sayımda kalem bulunmuyor.'),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtreliKalemler.length,
                        itemBuilder: (ctx, i) {
                          final k = _filtreliKalemler[i];
                          final urun = k['isletme_urunler'] as Map<String, dynamic>? ?? {};
                          final urunAdi = urun['urun_adi'] ?? '—';
                          final isim2 = urun['isim_2'] ?? '';
                          final urunKodu = urun['urun_kodu'] ?? '';
                          final urunSilindi = urun['aktif'] == 0 || urun['aktif'] == false;
                          final alt = [isim2, urunKodu].where((s) => s.toString().isNotEmpty).join(' · ');
                          final miktarRaw = k['miktar'] ?? 0;
                          final miktarD = double.tryParse(miktarRaw.toString()) ?? 0;
                          final miktar = miktarD == miktarD.roundToDouble() ? miktarD.toInt() : miktarD;
                          final birim = k['birim'] ?? '';

                          final barkodlar = urun['barkodlar']?.toString() ?? '';
                          final acik = _acikKalemler.contains(i);

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() {
                              if (acik) {
                                _acikKalemler.remove(i);
                              } else {
                                _acikKalemler.add(i);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: urunSilindi ? const Color(0xFFFEF2F2) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: acik ? _P.withOpacity(0.3) : (urunSilindi ? const Color(0xFFFCA5A5) : const Color(0xFFF3F4F6))),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Ürün bilgileri
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    urunAdi.toString(),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: urunSilindi ? const Color(0xFFDC2626) : const Color(0xFF1F2937),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (urunSilindi) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFEE2E2),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: const Color(0xFFFCA5A5), width: 0.5),
                                                    ),
                                                    child: const Text('Pasif', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (alt.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  alt,
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Miktar
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '$miktar ',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: _P,
                                              ),
                                            ),
                                            TextSpan(
                                              text: birim.toString(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Düzenle butonu
                                      if (_devam) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _showDuzenle(k),
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: _PL,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.edit, size: 14, color: _P),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  // Genişletilmiş detay bilgileri
                                  if (acik) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFF3F4F6)),
                                      ),
                                      child: Column(
                                        children: [
                                          if (urunKodu.toString().isNotEmpty)
                                            _kalemDetayRow('Ürün Kodu', urunKodu.toString()),
                                          if (isim2.toString().isNotEmpty)
                                            _kalemDetayRow('İkinci İsim', isim2.toString()),
                                          if (barkodlar.isNotEmpty)
                                            _kalemDetayRow('Barkod', barkodlar),
                                          _kalemDetayRow('Birim', birim.toString().isNotEmpty ? birim.toString() : 'ADET'),
                                          if (urunSilindi)
                                            _kalemDetayRow('Durum', 'Pasif Ürün', valueColor: const Color(0xFFDC2626)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
      ),
    );
  }

  void _showBilgi() {
    // Toplanan sayım mı kontrol et
    List<dynamic> topDepolar = [];
    try {
      final notlar = _sayim?['notlar'];
      if (notlar is String && notlar.contains('toplanan_sayimlar')) {
        final parsed = jsonDecode(notlar);
        final liste = parsed['toplanan_sayimlar'] as List? ?? [];
        topDepolar = liste;
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Sayım Bilgileri',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sayım ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                  GestureDetector(
                    onTap: () {
                      final shortId = '#${_sayim?['id']?.toString().split('-')[0].toUpperCase() ?? ''}';
                      Clipboard.setData(ClipboardData(text: shortId));
                      Navigator.pop(context);
                      showBildirim(context, 'Sayım ID kopyalandı', basarili: true);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#${_sayim?['id']?.toString().split('-')[0].toUpperCase() ?? '—'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy, size: 14, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _bilgiRow('İşletme', _sayim?['isletmeler']?['ad'] ?? '—'),
            _bilgiRow('Sayım', _sayim?['ad'] ?? '—'),
            _bilgiRow('Tarih', _tarihStr),
            if (topDepolar.isNotEmpty)
              _bilgiRow('Depolar', topDepolar.map((d) => d['depo']?.toString() ?? '').where((s) => s.isNotEmpty).join(', '))
            else
              _bilgiRow('Depo', _sayim?['depolar']?['ad'] ?? '—'),
            _bilgiRow('Durum', _devam ? 'Devam Ediyor' : '✓ Tamamlandı',
                color: _devam ? const Color(0xFF6366F1) : const Color(0xFF059669)),
            _bilgiRow('Toplam Kalem', '${_kalemler.length} kalem', color: _P),
          ],
        ),
      ),
    );
  }

  Widget _kalemDetayRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
          Flexible(child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF374151)), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _bilgiRow(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF374151))),
        ],
      ),
    );
  }

  String _fmtMiktar(dynamic val) {
    final d = double.tryParse(val?.toString() ?? '');
    if (d == null) return val?.toString() ?? '';
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  Future<void> _exportExcel() async {
    final isletme = _sayim?['isletmeler']?['ad'] ?? '';
    final depo = _sayim?['depolar']?['ad'] ?? '';
    final sayimAd = _sayim?['ad'] ?? '';
    final sayimId = widget.sayimId;

    final excel = xl.Excel.createExcel();
    final sheet = excel['Sayım'];
    // Varsayılan Sheet1'i sil
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    // Başlık bilgileri
    final infoRows = [
      ['İşletme', isletme],
      ['Depo', depo],
      ['Sayım', sayimAd],
      ['Sayım ID', '#${sayimId.split('-').first.toUpperCase()}'],
      ['Tarih', _tarihStr],
      ['Toplam Kalem', '${_kalemler.length}'],
    ];
    for (final r in infoRows) {
      sheet.appendRow(r.map((c) => xl.TextCellValue(c)).toList());
    }
    // Boş satır
    sheet.appendRow([xl.TextCellValue('')]);

    // Tablo başlıkları
    final headers = ['Ürün Adı', 'İsim 2', 'Ürün Kodu', 'Miktar', 'Birim', 'Barkodlar'];
    sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());

    // Kalem verileri
    for (final k in _kalemler) {
      final urun = k['isletme_urunler'] as Map<String, dynamic>?;
      sheet.appendRow([
        xl.TextCellValue(urun?['urun_adi']?.toString() ?? ''),
        xl.TextCellValue(urun?['isim_2']?.toString() ?? ''),
        xl.TextCellValue(urun?['urun_kodu']?.toString() ?? ''),
        xl.TextCellValue(_fmtMiktar(k['miktar'])),
        xl.TextCellValue(k['birim']?.toString() ?? ''),
        xl.TextCellValue(urun?['barkodlar']?.toString() ?? ''),
      ]);
    }

    final dir = await getTemporaryDirectory();
    final fileName = '${sayimAd}_$depo'.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final file = File('${dir.path}/$fileName.xlsx');
    final bytes = excel.encode();
    if (bytes == null) return;
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> _exportPDF() async {
    final isletme = _sayim?['isletmeler']?['ad'] ?? '';
    final depo = _sayim?['depolar']?['ad'] ?? '';
    final sayimAd = _sayim?['ad'] ?? '';

    // Azerbaycan karakterlerini destekleyen font
    final fontData = await rootBundle.load('assets/fonts/Roboto.ttf');
    final ttf = pw.Font.ttf(fontData);
    final baseStyle = pw.TextStyle(font: ttf, fontSize: 9);
    final boldStyle = pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
        build: (ctx) => [
          pw.Text('$isletme - $depo', style: titleStyle),
          pw.SizedBox(height: 4),
          pw.Text('Sayım: $sayimAd  |  Tarih: $_tarihStr  |  Toplam: ${_kalemler.length} kalem', style: baseStyle),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerStyle: boldStyle,
            cellStyle: baseStyle,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: ['#', 'Ürün Adı', 'İsim 2', 'Kod', 'Miktar', 'Birim'],
            data: List.generate(_kalemler.length, (i) {
              final k = _kalemler[i];
              final urun = k['isletme_urunler'] as Map<String, dynamic>?;
              return [
                '${i + 1}',
                urun?['urun_adi']?.toString() ?? '',
                urun?['isim_2']?.toString() ?? '',
                urun?['urun_kodu']?.toString() ?? '',
                _fmtMiktar(k['miktar']),
                k['birim']?.toString() ?? '',
              ];
            }),
          ),
        ],
      ),
    );
    final dir = await getTemporaryDirectory();
    final fileName = '${sayimAd}_$depo'.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  void _showPaylas() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paylaş / İndir',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Sayım özeti
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _PL,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_sayim?['isletmeler']?['ad'] ?? '—'} · ${_sayim?['depolar']?['ad'] ?? '—'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_tarihStr · ${_kalemler.length} kalem',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Excel
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _exportExcel();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.table_chart, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Excel (XLSX)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                        SizedBox(height: 2),
                        Text('Gerçek Excel dosyası olarak paylaş',
                            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // PDF
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _exportPDF();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PDF / Yazdır',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                        SizedBox(height: 2),
                        Text('Yazdır veya PDF olarak kaydet',
                            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTamamlaOnay() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.check_circle, size: 32, color: Color(0xFF059669)),
            ),
            const SizedBox(height: 12),
            const Text('Sayımı Tamamla',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
            const SizedBox(height: 4),
            const Text('Tamamlandıktan sonra ürün ekleyemez veya düzenleyemezsiniz.',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${_kalemler.length} ürün kaydedilecek.',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _handleTamamla();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Evet, Tamamla',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Vazgeç',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDuzenle(Map<String, dynamic> kalem) {
    final urun = kalem['isletme_urunler'] as Map<String, dynamic>? ?? {};
    final mRaw = double.tryParse(kalem['miktar']?.toString() ?? '');
    final mText = mRaw != null ? (mRaw == mRaw.roundToDouble() ? mRaw.toInt().toString() : mRaw.toString()) : '';
    final miktarController = TextEditingController(text: mText);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kalemi Düzenle',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Ürün bilgisi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ürün', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 2),
                    Text(urun['urun_adi']?.toString() ?? '—',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Miktar
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('MİKTAR',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 76),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _PL,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        kalem['birim']?.toString() ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _P),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: miktarController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSilOnay(kalem['id']);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                            SizedBox(width: 6),
                            Text('Sil',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final yeniMiktar = miktarController.text;
                        Navigator.pop(ctx);
                        _handleGuncelle(kalem['id'], yeniMiktar);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_P, Color(0xFF8B5CF6)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Kaydet',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSilOnay(dynamic kalemId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, size: 24, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 12),
            const Text('Ürünü Sil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
            const SizedBox(height: 4),
            const Text('Bu ürün sayımdan kalıcı olarak silinecek.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Vazgeç',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _handleKalemSil(kalemId);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Evet, Sil',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
