import 'package:flutter/material.dart';
import '../db/sync_service.dart';

/// Senkronizasyon sonuçlarını gösteren dialog
class SyncResultDialog extends StatelessWidget {
  final SyncResult result;

  const SyncResultDialog({super.key, required this.result});

  static Future<void> show(BuildContext context, SyncResult result) {
    return showDialog(
      context: context,
      builder: (_) => SyncResultDialog(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final basarili = result.basarili > 0;
    final basarisiz = result.basarisiz > 0;
    final bos = result.basarili == 0 && result.basarisiz == 0;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            bos
                ? Icons.info_outline
                : basarisiz
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
            color: bos
                ? Colors.blue
                : basarisiz
                    ? Colors.orange
                    : Colors.green,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            bos ? 'Güncelleme' : 'Senkronizasyon',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bos)
            const Text(
              'Bekleyen işlem yok. Veriler güncellendi.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          if (!bos) ...[
            // Özet
            Row(
              children: [
                if (basarili)
                  _badge('${result.basarili} başarılı', Colors.green),
                if (basarili && basarisiz) const SizedBox(width: 8),
                if (basarisiz)
                  _badge('${result.basarisiz} başarısız', Colors.red),
              ],
            ),
            // Hata listesi
            if (result.hatalar.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Başarısız işlemler:',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...result.hatalar.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.close, color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(h, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
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
