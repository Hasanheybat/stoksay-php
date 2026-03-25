import 'package:flutter/material.dart';

/// Aktif sayımda kullanılan depo/ürün silinmeye çalışıldığında gösterilen uyarı dialogu.
/// Sync result dialog ile aynı tasarımda.
class AktifSayimDialog extends StatelessWidget {
  final String baslik; // "Depo Silinemedi" veya "Ürün Silinemedi"
  final String mesaj; // "Bu depo aktif sayımlarda kullanılıyor."
  final List<String> sayimAdlari; // Aktif sayım adları

  const AktifSayimDialog({
    super.key,
    required this.baslik,
    required this.mesaj,
    required this.sayimAdlari,
  });

  /// Dialogu göster ve sonucu döndür.
  static Future<void> show(
    BuildContext context, {
    required String baslik,
    required String mesaj,
    required List<String> sayimAdlari,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AktifSayimDialog(
        baslik: baslik,
        mesaj: mesaj,
        sayimAdlari: sayimAdlari,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              baslik,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Özet mesaj
          Text(
            mesaj,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (sayimAdlari.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Badge
            _badge('${sayimAdlari.length} aktif sayım', Colors.orange),
            const SizedBox(height: 16),
            // Sayım listesi
            const Text(
              'Kullanıldığı sayımlar:',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...sayimAdlari.take(10).map((ad) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Colors.orange, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(ad, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                      ),
                    ],
                  ),
                )),
            if (sayimAdlari.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '... ve ${sayimAdlari.length - 10} sayım daha',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: 12),
          // Bilgi notu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Önce sayımları tamamlayın veya silin.',
                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tamam', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
