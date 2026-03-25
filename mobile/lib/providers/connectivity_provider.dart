import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/sync_service.dart';
import '../services/storage_service.dart';
import '../models/isletme.dart';

class ConnectivityState {
  final bool online;
  final int bekleyenSync;
  final bool offlineMode;
  final bool syncing;

  const ConnectivityState({
    this.online = true,
    this.bekleyenSync = 0,
    this.offlineMode = false,
    this.syncing = false,
  });

  ConnectivityState copyWith({
    bool? online,
    int? bekleyenSync,
    bool? offlineMode,
    bool? syncing,
  }) {
    return ConnectivityState(
      online: online ?? this.online,
      bekleyenSync: bekleyenSync ?? this.bekleyenSync,
      offlineMode: offlineMode ?? this.offlineMode,
      syncing: syncing ?? this.syncing,
    );
  }
}

class ConnectivityNotifier extends Notifier<ConnectivityState> {
  StreamSubscription? _sub;

  @override
  ConnectivityState build() {
    ref.onDispose(() => _sub?.cancel());
    _init();
    return ConnectivityState(offlineMode: StorageService.isOffline);
  }

  void _init() {
    Connectivity().checkConnectivity().then((results) {
      state = state.copyWith(online: !results.contains(ConnectivityResult.none));
      _updateBekleyen();
    });

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      final wasOffline = !state.online;
      state = state.copyWith(online: online);
      // Offline moddayken otomatik sync yapma
      if (online && wasOffline && !state.offlineMode) {
        SyncService.kuyruguGonder().then((_) => _updateBekleyen());
      }
    });
  }

  /// Offline moda geç: tüm verileri SQLite'a indir, SyncStats döndür
  Future<SyncStats> enterOfflineMode(List<Isletme> isletmeler) async {
    state = state.copyWith(syncing: true);
    try {
      final stats = await SyncService.tamSenkronizasyon(isletmeler);
      await StorageService.setOfflineMode(true);
      await _updateBekleyen();
      state = state.copyWith(offlineMode: true, syncing: false, bekleyenSync: 0);
      return stats;
    } catch (e) {
      state = state.copyWith(syncing: false);
      rethrow;
    }
  }

  /// Online moda dön: otomatik push → pull → sonuç döndür
  Future<SyncResult> exitOfflineMode(List<Isletme> isletmeler) async {
    state = state.copyWith(syncing: true);
    try {
      // 1. Push: bekleyen offline işlemleri sunucuya gönder
      final result = await SyncService.kuyruguGonder();

      // 2. Başarısız kalan queue kayıtlarını temizle (artık online'dayız, eski hatalar gereksiz)
      await SyncService.kuyruguBosalt();

      // 3. Offline modu kapat (pull'dan ÖNCE, böylece tamSenkronizasyon temiz siler)
      await StorageService.setOfflineMode(false);

      // 4. Pull: sunucudan taze veriyi çek (isOffline=false → tüm eski veri silinir)
      await SyncService.tamSenkronizasyon(isletmeler);

      await _updateBekleyen();
      state = state.copyWith(offlineMode: false, syncing: false);
      return result;
    } catch (e) {
      // Hata olsa bile offline moddan çık
      await StorageService.setOfflineMode(false);
      state = state.copyWith(offlineMode: false, syncing: false);
      rethrow;
    }
  }

  /// Verileri güncelle: önce push, sonra pull (offline moddayken)
  Future<SyncResult> verileriGuncelle(List<Isletme> isletmeler) async {
    state = state.copyWith(syncing: true);
    try {
      final result = await SyncService.kuyruguGonder();
      await SyncService.tamSenkronizasyon(isletmeler);
      await _updateBekleyen();
      state = state.copyWith(syncing: false);
      return result;
    } catch (e) {
      state = state.copyWith(syncing: false);
      rethrow;
    }
  }

  Future<void> _updateBekleyen() async {
    final count = await SyncService.bekleyenSayisi();
    state = state.copyWith(bekleyenSync: count);
  }

  Future<void> bekleyenGuncelle() async {
    await _updateBekleyen();
  }
}

final connectivityProvider = NotifierProvider<ConnectivityNotifier, ConnectivityState>(ConnectivityNotifier.new);
