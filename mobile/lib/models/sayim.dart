import 'dart:convert';

class Sayim {
  final String id;
  final String isletmeId;
  final String? depoId;
  final String ad;
  final String? tarih;
  final String durum;
  final String? notlar;
  final List<dynamic> kisiler;
  final Map<String, dynamic>? depo;
  final Map<String, dynamic>? isletme;

  Sayim({
    required this.id,
    required this.isletmeId,
    this.depoId,
    required this.ad,
    this.tarih,
    this.durum = 'devam',
    this.notlar,
    this.kisiler = const [],
    this.depo,
    this.isletme,
  });

  factory Sayim.fromJson(Map<String, dynamic> json) {
    dynamic parseKisiler(dynamic val) {
      if (val is List) return val;
      if (val is String && val.isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) return decoded;
          return [];
        } catch (_) {
          return [];
        }
      }
      return [];
    }

    try {
      return Sayim(
        id: json['id']?.toString() ?? '',
        isletmeId: (json['isletme_id'] ?? json['isletmeId'])?.toString() ?? '',
        depoId: (json['depo_id'] ?? json['depoId'])?.toString(),
        ad: json['ad']?.toString() ?? '',
        tarih: json['tarih']?.toString(),
        durum: json['durum']?.toString() ?? 'devam',
        notlar: json['notlar']?.toString(),
        kisiler: parseKisiler(json['kisiler']),
        depo: json['depolar'] is Map ? Map<String, dynamic>.from(json['depolar']) : null,
        isletme: json['isletmeler'] is Map ? Map<String, dynamic>.from(json['isletmeler']) : null,
      );
    } catch (_) {
      return Sayim(id: json['id']?.toString() ?? '', isletmeId: '', ad: 'Hatalı veri');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'isletme_id': isletmeId,
    'depo_id': depoId,
    'ad': ad,
    'tarih': tarih,
    'durum': durum,
    'notlar': notlar,
    'kisiler': kisiler,
  };
}
