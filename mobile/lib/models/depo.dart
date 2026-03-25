class Depo {
  final String id;
  final String ad;
  final String? konum;
  final String isletmeId;
  final bool aktif;

  Depo({required this.id, required this.ad, this.konum, required this.isletmeId, this.aktif = true});

  factory Depo.fromJson(Map<String, dynamic> json) {
    return Depo(
      id: json['id']?.toString() ?? '',
      ad: json['ad'] ?? '',
      konum: json['konum'],
      isletmeId: (json['isletme_id'] ?? json['isletmeId'])?.toString() ?? '',
      aktif: json['aktif'] == true || json['aktif'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'ad': ad, 'konum': konum, 'isletme_id': isletmeId, 'aktif': aktif};
}
