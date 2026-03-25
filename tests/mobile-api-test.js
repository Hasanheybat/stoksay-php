#!/usr/bin/env node
/**
 * StokSay Mobil API Uyumluluk Test Suite
 * =======================================
 * Flutter mobil uygulamanın kullandığı tüm endpoint'leri test eder.
 * Mobil app Dio HTTP client ile bu endpoint'leri çağırır — aynı request/response
 * formatı PHP backend'de de korunmalıdır.
 *
 * Kullanım: node tests/mobile-api-test.js [BASE_URL]
 */

const BASE_URL = process.argv[2] || 'http://localhost:3001';
const API = `${BASE_URL}/api`;

let passed = 0, failed = 0;
const errors = [];
const results = [];
let token = '';
let userId = '';
let isletmeId = '';

const created = {
  sayimId: null,
  kalemId: null,
  urunId: null,
};

async function req(method, path, body = null, tkn = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (tkn) headers['Authorization'] = `Bearer ${tkn}`;
  const opts = { method, headers };
  if (body) opts.body = JSON.stringify(body);
  const start = Date.now();
  try {
    const res = await fetch(`${API}${path}`, opts);
    const ms = Date.now() - start;
    let data;
    const ct = res.headers.get('content-type') || '';
    data = ct.includes('json') ? await res.json() : await res.text();
    return { status: res.status, data, ms, ok: res.ok };
  } catch (err) {
    return { status: 0, data: null, ms: Date.now() - start, ok: false, error: err.message };
  }
}

function test(name, fn) { results.push({ name, fn }); }
function assert(cond, msg) { if (!cond) throw new Error(msg); }

// ═══════════════════════════════════════════════════════════════
// Mobil akış simülasyonu: Login → İşletme seç → Sayım → Ürün → Sync
// ═══════════════════════════════════════════════════════════════

test('📱 Login (AuthService.login)', async () => {
  const r = await req('POST', '/auth/login', { email: 'admin@stoksay.com', password: 'TestAdmin1234!' });
  assert(r.status === 200, `Status ${r.status}`);
  assert(r.data.token, 'token eksik');
  assert(r.data.kullanici, 'kullanici eksik');
  assert(r.data.kullanici.id, 'kullanici.id eksik');
  assert(r.data.kullanici.email, 'kullanici.email eksik');
  assert(r.data.kullanici.rol, 'kullanici.rol eksik');
  assert(!r.data.kullanici.password_hash, 'password_hash döndürülmemeli');
  token = r.data.token;
  userId = r.data.kullanici.id;
});

test('📱 Auth me (AuthProvider.oturumKontrol)', async () => {
  const r = await req('GET', '/auth/me', null, token);
  assert(r.status === 200, `Status ${r.status}`);
  assert(r.data.kullanici, 'kullanici eksik');
  assert(r.data.yetkilerMap !== undefined, 'yetkilerMap eksik');
  // Mobil bu yapıyı kullanarak yetki kontrolü yapar
});

test('📱 İşletmelerim (ProfilService → isletme seçimi)', async () => {
  const r = await req('GET', '/profil/isletmelerim', null, token);
  assert(r.status === 200, `Status ${r.status}`);
  assert(Array.isArray(r.data), 'Array bekleniyor');
  // Mobil uygulama ilk işletmeyi seçer
  if (r.data.length > 0) {
    isletmeId = r.data[0].id;
    // Mobil beklediği field'ler
    assert(r.data[0].id, 'id eksik');
    assert(r.data[0].ad, 'ad eksik');
  }
});

test('📱 Profil stats (HomeScreen istatistik)', async () => {
  const r = await req('GET', '/profil/stats', null, token);
  assert(r.status === 200, `Status ${r.status}`);
  assert(typeof r.data.sayimlar === 'number', 'sayimlar sayı olmalı');
  assert(typeof r.data.urunler === 'number', 'urunler sayı olmalı');
  assert(typeof r.data.depolar === 'number', 'depolar sayı olmalı');
});

// ── DEPOLAR (SyncService.tamSenkronizasyon → depolar) ──

test('📱 Depo listele (DepoService.listeleOnline)', async () => {
  if (!isletmeId) return;
  const r = await req('GET', `/depolar?isletme_id=${isletmeId}`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
  // Mobil response formatı: { data: [...], toplam: N } veya direkt array
  const data = r.data.data || r.data;
  assert(Array.isArray(data), 'Array bekleniyor');
  if (data.length > 0) {
    assert(data[0].id, 'depo.id eksik');
    assert(data[0].ad, 'depo.ad eksik');
    created.depoId = data[0].id;
  }
});

// ── ÜRÜNLER (SyncService.tamSenkronizasyon → ürünler) ──

test('📱 Ürün listele (UrunService.listeleOnline)', async () => {
  if (!isletmeId) return;
  const r = await req('GET', `/urunler?isletme_id=${isletmeId}&sayfa=1&limit=20`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
  // Admin için { data: [...], toplam, sayfa, limit }
  if (r.data.data) {
    assert(Array.isArray(r.data.data), 'data array bekleniyor');
    assert(typeof r.data.toplam === 'number', 'toplam bekleniyor');
    if (r.data.data.length > 0) {
      const u = r.data.data[0];
      assert(u.id, 'urun.id eksik');
      assert(u.urun_adi !== undefined, 'urun_adi eksik');
      created.existingUrunId = u.id;
    }
  } else {
    // Kullanıcı formatı: direkt array
    assert(Array.isArray(r.data), 'Array bekleniyor');
  }
});

test('📱 Ürün arama (UrunService.listeleOnline — arama)', async () => {
  if (!isletmeId) return;
  const r = await req('GET', `/urunler?isletme_id=${isletmeId}&q=test&sayfa=1&limit=20`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
});

test('📱 Barkod ara (UrunService.barkodBulOnline)', async () => {
  if (!isletmeId) return;
  const r = await req('GET', `/urunler/barkod/NONEXISTENT123?isletme_id=${isletmeId}`, null, token);
  // Olmayan barkod → 404
  assert(r.status === 404, `Beklenen 404, gelen ${r.status}`);
  assert(r.data.hata, 'hata mesajı bekleniyor');
});

test('📱 Ürün ekle (UrunService.ekleOnline)', async () => {
  if (!isletmeId) return;
  const r = await req('POST', '/urunler', {
    isletme_id: isletmeId,
    urun_kodu: `MOB-${Date.now()}`,
    urun_adi: 'Mobil Test Ürün',
    birim: 'ADET',
    barkodlar: [`MOBBRK-${Date.now()}`],
  }, token);
  assert(r.status === 201, `Status ${r.status} — ${JSON.stringify(r.data)}`);
  assert(r.data.id, 'id eksik');
  created.urunId = r.data.id;
});

test('📱 Ürün güncelle (UrunService.guncelleOnline)', async () => {
  if (!created.urunId) return;
  const r = await req('PUT', `/urunler/${created.urunId}`, {
    urun_adi: 'Mobil Test Ürün Güncellendi',
    birim: 'KG',
  }, token);
  assert(r.status === 200, `Status ${r.status}`);
  assert(r.data.urun_adi === 'Mobil Test Ürün Güncellendi', 'Ad güncellenmedi');
});

// ── SAYIMLAR ──

test('📱 Sayım listele (SayimService.listeleOnline)', async () => {
  if (!isletmeId) return;
  const r = await req('GET', `/sayimlar?isletme_id=${isletmeId}&sayfa=1&limit=50`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
  assert(r.data.data !== undefined, 'data bekleniyor');
  assert(typeof r.data.toplam === 'number', 'toplam bekleniyor');
  if (r.data.data.length > 0) {
    const s = r.data.data[0];
    assert(s.id, 'sayim.id eksik');
    assert(s.depolar !== undefined, 'depolar join eksik');
    assert(s.isletmeler !== undefined, 'isletmeler join eksik');
  }
});

test('📱 Sayım oluştur (SayimService.olusturOnline)', async () => {
  if (!isletmeId || !created.depoId) return;
  const r = await req('POST', '/sayimlar', {
    isletme_id: isletmeId,
    depo_id: created.depoId,
    ad: 'Mobil Sayım Test',
  }, token);
  assert(r.status === 201, `Status ${r.status} — ${JSON.stringify(r.data)}`);
  assert(r.data.id, 'sayim.id eksik');
  assert(r.data.durum === 'devam', 'durum devam olmalı');
  created.sayimId = r.data.id;
});

test('📱 Sayım detay (SayimService.detayOnline)', async () => {
  if (!created.sayimId) return;
  const r = await req('GET', `/sayimlar/${created.sayimId}`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
  // Mobil bu alanları bekler
  assert(r.data.id, 'id eksik');
  assert(r.data.ad, 'ad eksik');
  assert(r.data.durum, 'durum eksik');
  assert(r.data.sayim_kalemleri !== undefined, 'sayim_kalemleri eksik');
  assert(r.data.depolar !== undefined, 'depolar eksik');
  assert(r.data.isletmeler !== undefined, 'isletmeler eksik');
  assert(r.data.kullanicilar !== undefined, 'kullanicilar eksik');
});

test('📱 Kalem ekle (SayimService.kalemEkleOnline)', async () => {
  if (!created.sayimId || !created.urunId) return;
  const r = await req('POST', `/sayimlar/${created.sayimId}/kalem`, {
    urun_id: created.urunId,
    miktar: 7.5,
    birim: 'KG',
  }, token);
  assert(r.status === 201, `Status ${r.status} — ${JSON.stringify(r.data)}`);
  assert(r.data.id, 'kalem.id eksik');
  created.kalemId = r.data.id;
});

test('📱 Kalem güncelle (SayimService.kalemGuncelleOnline)', async () => {
  if (!created.kalemId) return;
  const r = await req('PUT', `/sayimlar/${created.sayimId}/kalem/${created.kalemId}`, {
    miktar: 12,
    notlar: 'Mobil test notu',
  }, token);
  assert(r.status === 200, `Status ${r.status}`);
});

test('📱 Kalem sil (SayimService.kalemSilOnline)', async () => {
  if (!created.kalemId) return;
  const r = await req('DELETE', `/sayimlar/${created.sayimId}/kalem/${created.kalemId}`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
});

test('📱 Sayım güncelle (SayimService.guncelleOnline)', async () => {
  if (!created.sayimId) return;
  const r = await req('PUT', `/sayimlar/${created.sayimId}`, {
    ad: 'Mobil Sayım Güncellendi',
  }, token);
  assert(r.status === 200, `Status ${r.status}`);
});

test('📱 Sayım tamamla (SayimService.tamamlaOnline)', async () => {
  if (!created.sayimId) return;
  const r = await req('PUT', `/sayimlar/${created.sayimId}/tamamla`, {}, token);
  assert(r.status === 200, `Status ${r.status}`);
});

test('📱 Toplanmış sayımlar listele (SayimService.toplanmisListeleOnline)', async () => {
  if (!isletmeId) return;
  const r = await req('GET', `/sayimlar?isletme_id=${isletmeId}&toplama=1&sayfa=1`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
  assert(r.data.data !== undefined, 'data bekleniyor');
});

// ── SYNC SİMÜLASYONU ──
// Mobil offline → online geçişte SyncService bu sırayla çağırır:
// 1. /depolar?isletme_id=X
// 2. /urunler?isletme_id=X
// 3. /sayimlar?isletme_id=X
// 4. /sayimlar/:id (her sayım için)

test('📱 Sync — Depo pull', async () => {
  if (!isletmeId) return;
  const r = await req('GET', `/depolar?isletme_id=${isletmeId}`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
});

test('📱 Sync — Ürün pull (sayfalı)', async () => {
  if (!isletmeId) return;
  const r = await req('GET', `/urunler?isletme_id=${isletmeId}&sayfa=1&limit=200`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
});

test('📱 Sync — Sayım pull', async () => {
  if (!isletmeId) return;
  const r = await req('GET', `/sayimlar?isletme_id=${isletmeId}&sayfa=1&limit=200`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
});

// ── RESPONSE FORMAT KONTROLLERI ──
// Mobil uygulamanın beklediği JSON yapılarını doğrula

test('📱 Response format — Login response', async () => {
  const r = await req('POST', '/auth/login', { email: 'admin@stoksay.com', password: 'TestAdmin1234!' });
  const k = r.data.kullanici;
  // Flutter Kullanici.fromJson beklediği alanlar:
  assert(k.id !== undefined, 'kullanici.id gerekli');
  assert(k.ad_soyad !== undefined, 'kullanici.ad_soyad gerekli');
  assert(k.email !== undefined, 'kullanici.email gerekli');
  assert(k.rol !== undefined, 'kullanici.rol gerekli');
  assert(k.aktif !== undefined, 'kullanici.aktif gerekli');
});

test('📱 Response format — Sayım detay kalemler', async () => {
  // Tamamlanan sayımdan detay al
  if (!created.sayimId) return;
  const r = await req('GET', `/sayimlar/${created.sayimId}`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
  // Flutter SayimKalemi.fromJson beklediği yapı:
  if (r.data.sayim_kalemleri && r.data.sayim_kalemleri.length > 0) {
    const k = r.data.sayim_kalemleri[0];
    assert(k.id !== undefined, 'kalem.id gerekli');
    assert(k.miktar !== undefined, 'kalem.miktar gerekli');
  }
});

test('📱 Response format — 401 unauthorized', async () => {
  const r = await req('GET', '/auth/me', null, 'expired.token.here');
  assert(r.status === 401 || r.status === 403, 'Geçersiz token hata dönmeli');
  // Mobil ApiService 401'de logout yapar
});

// ── CLEANUP ──

test('📱 Cleanup — Sayım sil', async () => {
  if (!created.sayimId) return;
  const r = await req('DELETE', `/sayimlar/${created.sayimId}`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
});

test('📱 Cleanup — Ürün sil', async () => {
  if (!created.urunId) return;
  const r = await req('DELETE', `/urunler/${created.urunId}`, null, token);
  assert(r.status === 200, `Status ${r.status}`);
});

// ═══════════════════════════════════════════════════════════════
async function runTests() {
  console.log('\n╔══════════════════════════════════════════════════════════════╗');
  console.log('║       📱 StokSay Mobil API Uyumluluk Testi                  ║');
  console.log(`║  Backend: ${BASE_URL.padEnd(48)}║`);
  console.log(`║  Tarih:   ${new Date().toISOString().padEnd(48)}║`);
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  for (const { name, fn } of results) {
    try {
      await fn();
      passed++;
      console.log(`  ✅ ${name}`);
    } catch (err) {
      failed++;
      errors.push({ name, error: err.message });
      console.log(`  ❌ ${name}`);
      console.log(`     → ${err.message}`);
    }
  }

  console.log('\n══════════════════════════════════════════════════════════════');
  console.log(`  Sonuç: ${passed} başarılı, ${failed} başarısız, toplam ${passed + failed}`);
  console.log('══════════════════════════════════════════════════════════════');

  if (errors.length) {
    console.log('\n  Başarısız testler:');
    errors.forEach(e => console.log(`    - ${e.name}: ${e.error}`));
  }

  const fs = require('fs');
  const report = {
    type: 'mobile-api-compat',
    backend: BASE_URL,
    timestamp: new Date().toISOString(),
    summary: { passed, failed, total: passed + failed },
    errors,
  };
  const reportPath = `${__dirname}/mobile-test-report-${Date.now()}.json`;
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`\n  Rapor: ${reportPath}\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runTests();
