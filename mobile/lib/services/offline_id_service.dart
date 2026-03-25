import 'dart:math';

/// Offline modda oluşturulan kayıtlar için kriptografik rastgele temp ID üretir.
/// Online ID'ler UUID string, offline ID'ler "temp_" prefix'li rastgele string.
/// Böylece çakışma olmaz ve tahmin edilemez.
class OfflineIdService {
  static final _random = Random.secure();

  /// Kriptografik rastgele temp ID üretir
  /// Format: "temp_{timestamp}_{6 haneli secure random}"
  /// Entropi: ~20 bit timestamp (ms) + ~20 bit random = tahmin edilemez
  static Future<String> nextId() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(999999); // 6 haneli: 0-999999
    final rand2 = _random.nextInt(999999); // ekstra entropi
    return 'temp_${ts}_${rand}_$rand2';
  }

  /// Verilen ID'nin offline temp ID olup olmadığını kontrol eder
  static bool isTempId(dynamic id) {
    if (id is String) return id.startsWith('temp_');
    return false;
  }
}
