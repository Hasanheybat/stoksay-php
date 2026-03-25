class Kullanici {
  final String id;
  final String adSoyad;
  final String email;
  final String rol;
  final bool aktif;
  final Map<String, dynamic> ayarlar;

  Kullanici({
    required this.id,
    required this.adSoyad,
    required this.email,
    required this.rol,
    this.aktif = true,
    this.ayarlar = const {},
  });

  bool get birimOtomatik => ayarlar['birim_otomatik'] == true;
  bool get barkodSesi => ayarlar['barkod_sesi'] != false;

  factory Kullanici.fromJson(Map<String, dynamic> json) {
    return Kullanici(
      id: json['id']?.toString() ?? '',
      adSoyad: json['ad_soyad'] ?? json['adSoyad'] ?? '',
      email: json['email'] ?? '',
      rol: json['rol'] ?? 'kullanici',
      aktif: json['aktif'] == true || json['aktif'] == 1,
      ayarlar: json['ayarlar'] is Map ? Map<String, dynamic>.from(json['ayarlar']) : {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ad_soyad': adSoyad,
    'email': email,
    'rol': rol,
    'aktif': aktif,
    'ayarlar': ayarlar,
  };
}
