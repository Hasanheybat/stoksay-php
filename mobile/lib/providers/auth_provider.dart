import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../models/kullanici.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../db/database_helper.dart';

class AuthState {
  final Kullanici? kullanici;
  final Map<String, dynamic> yetkilerMap;
  final bool yukleniyor;
  final String? hata;
  final bool cacheFallback;
  final bool pasif; // Kullanıcı pasife alınmış mı

  AuthState({
    this.kullanici,
    this.yetkilerMap = const {},
    this.yukleniyor = true,
    this.hata,
    this.cacheFallback = false,
    this.pasif = false,
  });

  AuthState copyWith({
    Kullanici? kullanici,
    Map<String, dynamic>? yetkilerMap,
    bool? yukleniyor,
    String? hata,
    bool? cacheFallback,
    bool? pasif,
  }) {
    return AuthState(
      kullanici: kullanici ?? this.kullanici,
      yetkilerMap: yetkilerMap ?? this.yetkilerMap,
      yukleniyor: yukleniyor ?? this.yukleniyor,
      hata: hata,
      cacheFallback: cacheFallback ?? this.cacheFallback,
      pasif: pasif ?? this.pasif,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  AppLifecycleListener? _lifecycleListener;

  @override
  AuthState build() => AuthState();

  /// App foreground'a geldiğinde yetkileri yeniden kontrol eder
  void initLifecycleObserver() {
    _lifecycleListener?.dispose();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (StorageService.hasToken) {
          oturumKontrol();
        }
      },
    );
  }

  Future<void> oturumKontrol() async {
    state = state.copyWith(yukleniyor: true, hata: null);

    if (!StorageService.hasToken) {
      final cached = await _cacheOku();
      if (cached != null) {
        state = AuthState(
          kullanici: cached['kullanici'],
          yetkilerMap: cached['yetkilerMap'],
          yukleniyor: false,
        );
        return;
      }
      state = AuthState(yukleniyor: false);
      return;
    }

    try {
      final data = await AuthService.oturumKontrol();
      final kullanici = Kullanici.fromJson(data['kullanici']);
      final yetkilerMap = Map<String, dynamic>.from(data['yetkilerMap'] ?? {});
      try { await _cacheYaz(kullanici, yetkilerMap); } catch (_) {}
      state = AuthState(kullanici: kullanici, yetkilerMap: yetkilerMap, yukleniyor: false);
    } catch (e) {
      // 403 = kullanıcı pasife alınmış → cache'e düşürme, pasif ekranı göster
      if (e is DioException && e.response?.statusCode == 403) {
        final cached = await _cacheOku();
        state = AuthState(
          kullanici: cached?['kullanici'],
          yetkilerMap: const {},
          yukleniyor: false,
          pasif: true,
        );
        return;
      }
      Map<String, dynamic>? cached;
      try { cached = await _cacheOku(); } catch (_) {}
      if (cached != null) {
        state = AuthState(kullanici: cached['kullanici'], yetkilerMap: cached['yetkilerMap'], yukleniyor: false, cacheFallback: true);
      } else {
        await StorageService.removeToken();
        state = AuthState(yukleniyor: false, hata: 'Oturum dogrulanamadi');
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(yukleniyor: true, hata: null);
    try {
      await AuthService.login(email, password);
      await oturumKontrol();
      return true;
    } catch (e) {
      String hata = 'Giris basarisiz';
      if (e is DioException && e.response != null) {
        final status = e.response?.statusCode;
        if (status == 401) hata = 'Email veya sifre hatali';
        if (status == 403) hata = 'Hesabiniz pasif durumdadir';
        if (status == 429) hata = 'Cok fazla deneme. Lutfen bekleyin.';
      }
      state = AuthState(yukleniyor: false, hata: hata);
      return false;
    }
  }

  Future<void> cikisYap() async {
    await AuthService.logout();
    await DatabaseHelper.clearAll();
    state = AuthState(yukleniyor: false);
  }

  void ayarlarGuncelle(Map<String, dynamic> yeniAyarlar) {
    final k = state.kullanici;
    if (k == null) return;
    final yeniKullanici = Kullanici(
      id: k.id,
      adSoyad: k.adSoyad,
      email: k.email,
      rol: k.rol,
      aktif: k.aktif,
      ayarlar: yeniAyarlar,
    );
    state = state.copyWith(kullanici: yeniKullanici);
    // Cache'i de güncelle
    try { _cacheYaz(yeniKullanici, state.yetkilerMap); } catch (_) {}
  }

  bool hasYetki(String kategori, String islem) {
    final k = state.kullanici;
    if (k == null) return false;
    if (k.rol == 'admin') return true;
    return state.yetkilerMap.values.any((y) {
      if (y is Map) {
        final kat = y[kategori];
        if (kat is Map) return kat[islem] == true;
      }
      return false;
    });
  }

  bool isletmeYetkisi(String isletmeId, String kategori, String islem) {
    final k = state.kullanici;
    if (k == null) return false;
    if (k.rol == 'admin') return true;
    final y = state.yetkilerMap[isletmeId];
    if (y is Map) {
      final kat = y[kategori];
      if (kat is Map) return kat[islem] == true;
    }
    return false;
  }

  Future<void> _cacheYaz(Kullanici kullanici, Map<String, dynamic> yetkilerMap) async {
    final db = await DatabaseHelper.database;
    await db.insert('kullanici_cache', {
      'id': 1,
      'kullanici': jsonEncode(kullanici.toJson()),
      'yetkiler_map': jsonEncode(yetkilerMap),
      'son_guncelleme': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> _cacheOku() async {
    try {
      final db = await DatabaseHelper.database;
      final result = await db.query('kullanici_cache', where: 'id = 1');
      if (result.isEmpty) return null;
      final row = result.first;
      return {
        'kullanici': Kullanici.fromJson(jsonDecode(row['kullanici'] as String)),
        'yetkilerMap': Map<String, dynamic>.from(jsonDecode(row['yetkiler_map'] as String)),
      };
    } catch (_) {
      return null;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
