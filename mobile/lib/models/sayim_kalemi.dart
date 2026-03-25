class SayimKalemi {
  final String id;
  final String sayimId;
  final String urunId;
  final double miktar;
  final String? birim;
  final String? notlar;
  final String? urunKodu;
  final String? urunAdi;
  final String? isim2;

  SayimKalemi({
    required this.id,
    required this.sayimId,
    required this.urunId,
    required this.miktar,
    this.birim,
    this.notlar,
    this.urunKodu,
    this.urunAdi,
    this.isim2,
  });

  factory SayimKalemi.fromJson(Map<String, dynamic> json) {
    return SayimKalemi(
      id: json['id']?.toString() ?? '',
      sayimId: (json['sayim_id'] ?? json['sayimId'])?.toString() ?? '',
      urunId: (json['urun_id'] ?? json['urunId'])?.toString() ?? '',
      miktar: (json['miktar'] ?? 0).toDouble(),
      birim: json['birim'],
      notlar: json['notlar'],
      urunKodu: json['urun_kodu'] ?? json['isletme_urunler']?['urun_kodu'],
      urunAdi: json['urun_adi'] ?? json['isletme_urunler']?['urun_adi'],
      isim2: json['isim_2'] ?? json['isletme_urunler']?['isim_2'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sayim_id': sayimId,
    'urun_id': urunId,
    'miktar': miktar,
    'birim': birim,
    'notlar': notlar,
  };
}
