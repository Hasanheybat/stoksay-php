class Isletme {
  final String id;
  final String ad;
  final String? kod;
  final bool aktif;

  Isletme({required this.id, required this.ad, this.kod, this.aktif = true});

  factory Isletme.fromJson(Map<String, dynamic> json) {
    return Isletme(
      id: json['id']?.toString() ?? '',
      ad: json['ad'] ?? '',
      kod: json['kod'],
      aktif: json['aktif'] == true || json['aktif'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'ad': ad, 'kod': kod, 'aktif': aktif};
}
