import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../models/isletme.dart';
import '../services/isletme_service.dart';
import '../db/database_helper.dart';
import '../db/sync_service.dart';

class IsletmeState {
  final List<Isletme> isletmeler;
  final Isletme? secili;
  final bool yukleniyor;

  IsletmeState({this.isletmeler = const [], this.secili, this.yukleniyor = false});

  IsletmeState copyWith({List<Isletme>? isletmeler, Isletme? secili, bool? yukleniyor}) {
    return IsletmeState(
      isletmeler: isletmeler ?? this.isletmeler,
      secili: secili ?? this.secili,
      yukleniyor: yukleniyor ?? this.yukleniyor,
    );
  }
}

class IsletmeNotifier extends Notifier<IsletmeState> {
  @override
  IsletmeState build() => IsletmeState();

  Future<void> yukle() async {
    state = state.copyWith(yukleniyor: true);
    try {
      final isletmeler = await IsletmeService.isletmelerim();
      // SQLite cache (web'de calismaz, hata yakalanir)
      try {
        final db = await DatabaseHelper.database;
        await db.delete('isletmeler');
        for (final i in isletmeler) {
          await db.insert('isletmeler', {
            'id': i.id,
            'ad': i.ad,
            'kod': i.kod,
            'aktif': i.aktif ? 1 : 0,
            'son_guncelleme': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await SyncService.tamSenkronizasyon(isletmeler);
      } catch (_) {}
      state = IsletmeState(
        isletmeler: isletmeler,
        secili: isletmeler.isNotEmpty ? isletmeler.first : null,
        yukleniyor: false,
      );
    } catch (_) {
      try {
        final db = await DatabaseHelper.database;
        final rows = await db.query('isletmeler');
        final isletmeler = rows.map((r) => Isletme.fromJson(r)).toList();
        state = IsletmeState(
          isletmeler: isletmeler,
          secili: isletmeler.isNotEmpty ? isletmeler.first : null,
          yukleniyor: false,
        );
      } catch (_) {
        state = state.copyWith(yukleniyor: false);
      }
    }
  }

  void sec(Isletme isletme) {
    state = state.copyWith(secili: isletme);
  }
}

final isletmeProvider = NotifierProvider<IsletmeNotifier, IsletmeState>(IsletmeNotifier.new);
