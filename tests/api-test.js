#!/usr/bin/env node
/**
 * StokSay API Test Suite — Node.js Backend
 * ==========================================
 * Tüm özellikleri test eder: Auth, İşletme, Depo, Ürün, Sayım, Kullanıcı, Rol, Profil, Stats
 *
 * Kullanım: node tests/api-test.js [BASE_URL]
 * Örnek:    node tests/api-test.js http://localhost:3001
 *
 * PHP'ye dönüştürdükten sonra aynı testi çalıştırarak sonuçları karşılaştırın.
 */

const BASE_URL = process.argv[2] || 'http://localhost:3001';
const API = `${BASE_URL}/api`;

// ─── Test altyapısı ───
let passed = 0, failed = 0, skipped = 0;
const errors = [];
const results = [];
let adminToken = '';
let userToken = '';

// Test verileri — cleanup için saklayacağız
const created = {
  isletmeId: null,
  isletme2Id: null,
  depoId: null,
  urunId: null,
  urun2Id: null,
  sayimId: null,
  kalemId: null,
  userId: null,
  rolId: null,
  toplanmisSayimId: null,
  sayim2Id: null,
};

// ─── HTTP Helper ───
async function req(method, path, body = null, token = null, isFormData = false) {
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  if (!isFormData) headers['Content-Type'] = 'application/json';

  const opts = { method, headers };
  if (body && !isFormData) opts.body = JSON.stringify(body);
  if (body && isFormData) opts.body = body;

  const start = Date.now();
  try {
    const res = await fetch(`${API}${path}`, opts);
    const ms = Date.now() - start;
    let data;
    const contentType = res.headers.get('content-type') || '';
    if (contentType.includes('json')) {
      data = await res.json();
    } else {
      data = await res.text();
    }
    return { status: res.status, data, ms, ok: res.ok };
  } catch (err) {
    return { status: 0, data: null, ms: Date.now() - start, ok: false, error: err.message };
  }
}

function test(name, fn) {
  results.push({ name, fn });
}

async function runTests() {
  console.log('\n╔══════════════════════════════════════════════════════════════╗');
  console.log('║          StokSay API Test Suite v1.0                        ║');
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

  // JSON rapor dosyası
  const report = {
    backend: BASE_URL,
    timestamp: new Date().toISOString(),
    summary: { passed, failed, total: passed + failed },
    errors,
  };
  const fs = require('fs');
  const reportPath = `${__dirname}/test-report-${Date.now()}.json`;
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`\n  Rapor: ${reportPath}\n`);

  process.exit(failed > 0 ? 1 : 0);
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg);
}

// ═══════════════════════════════════════════════════════════════
//  1. HEALTH CHECK
// ═══════════════════════════════════════════════════════════════

test('Health check — GET /api/health', async () => {
  const r = await req('GET', '/health');
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════════
//  2. AUTH — Login & Token
// ═══════════════════════════════════════════════════════════════

test('Auth — Login başarısız (yanlış şifre)', async () => {
  const r = await req('POST', '/auth/login', { email: 'admin@stoksay.com', password: 'yanlis_sifre_99' });
  assert(r.status === 401, `Beklenen 401, gelen ${r.status}`);
});

test('Auth — Login başarısız (eksik email)', async () => {
  const r = await req('POST', '/auth/login', { password: 'test1234' });
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('Auth — Login başarısız (geçersiz email)', async () => {
  const r = await req('POST', '/auth/login', { email: 'gecersiz', password: 'test1234' });
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('Auth — Admin login başarılı', async () => {
  const r = await req('POST', '/auth/login', { email: 'admin@stoksay.com', password: 'TestAdmin1234!' });
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.token, 'Token alınamadı');
  assert(r.data.kullanici, 'Kullanıcı bilgisi alınamadı');
  assert(r.data.kullanici.rol === 'admin', 'Rol admin olmalı');
  assert(!r.data.kullanici.password_hash, 'password_hash döndürülmemeli');
  adminToken = r.data.token;
});

test('Auth — GET /auth/me (admin)', async () => {
  const r = await req('GET', '/auth/me', null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.kullanici, 'Kullanıcı bilgisi alınamadı');
  assert(r.data.kullanici.rol === 'admin', 'Rol admin olmalı');
  assert(r.data.yetkilerMap !== undefined, 'yetkilerMap alınamadı');
});

test('Auth — Token olmadan erişim → 401', async () => {
  const r = await req('GET', '/auth/me');
  assert(r.status === 401, `Beklenen 401, gelen ${r.status}`);
});

test('Auth — Geçersiz token → 401', async () => {
  const r = await req('GET', '/auth/me', null, 'gecersiz.token.123');
  assert(r.status === 401 || r.status === 403, `Beklenen 401/403, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════════
//  3. İŞLETMELER
// ═══════════════════════════════════════════════════════════════

test('İşletme — Oluştur', async () => {
  const r = await req('POST', '/isletmeler', {
    ad: 'Test İşletme API',
    kod: `TST-${Date.now()}`,
    adres: 'Test Adres 123',
    telefon: '+90 555 123 4567',
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status} — ${JSON.stringify(r.data)}`);
  assert(r.data.id, 'İşletme ID alınamadı');
  assert(r.data.ad === 'Test İşletme API', 'Ad eşleşmiyor');
  created.isletmeId = r.data.id;
});

test('İşletme — Oluştur (2. işletme)', async () => {
  const r = await req('POST', '/isletmeler', {
    ad: 'Test İşletme 2',
    kod: `TST2-${Date.now()}`,
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status}`);
  created.isletme2Id = r.data.id;
});

test('İşletme — Ad ve kod zorunlu', async () => {
  const r = await req('POST', '/isletmeler', { ad: 'Eksik' }, adminToken);
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('İşletme — Listele (pagination)', async () => {
  const r = await req('GET', '/isletmeler?sayfa=1&limit=10', null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.data, 'data array bekleniyor');
  assert(typeof r.data.toplam === 'number', 'toplam sayı bekleniyor');
});

test('İşletme — Listele (pagination yok — dropdown)', async () => {
  const r = await req('GET', '/isletmeler', null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(Array.isArray(r.data), 'Array bekleniyor');
});

test('İşletme — Detay', async () => {
  const r = await req('GET', `/isletmeler/${created.isletmeId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.id === created.isletmeId, 'ID eşleşmiyor');
});

test('İşletme — Güncelle', async () => {
  const r = await req('PUT', `/isletmeler/${created.isletmeId}`, {
    ad: 'Test İşletme Güncellendi',
    telefon: '+90 555 999 8888',
  }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.ad === 'Test İşletme Güncellendi', 'Ad güncellenmedi');
});

test('İşletme — Geçersiz telefon', async () => {
  const r = await req('PUT', `/isletmeler/${created.isletmeId}`, {
    telefon: 'geçersiz!!!',
  }, adminToken);
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('İşletme — 404 olmayan ID', async () => {
  const r = await req('GET', '/isletmeler/olmayan-id-12345', null, adminToken);
  assert(r.status === 404, `Beklenen 404, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════════
//  4. DEPOLAR
// ═══════════════════════════════════════════════════════════════

test('Depo — Oluştur', async () => {
  const r = await req('POST', '/depolar', {
    isletme_id: created.isletmeId,
    ad: 'Test Depo API',
    kod: `DP-${Date.now()}`,
    konum: 'A Blok',
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status} — ${JSON.stringify(r.data)}`);
  assert(r.data.id, 'Depo ID alınamadı');
  created.depoId = r.data.id;
});

test('Depo — isletme_id ve ad zorunlu', async () => {
  const r = await req('POST', '/depolar', { ad: 'Eksik' }, adminToken);
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('Depo — Listele (admin, pagination)', async () => {
  const r = await req('GET', `/depolar?isletme_id=${created.isletmeId}&sayfa=1&limit=10`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.data, 'data array bekleniyor');
});

test('Depo — Detay', async () => {
  const r = await req('GET', `/depolar/${created.depoId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.id === created.depoId, 'ID eşleşmiyor');
});

test('Depo — Güncelle', async () => {
  const r = await req('PUT', `/depolar/${created.depoId}`, {
    ad: 'Test Depo Güncellendi',
    konum: 'B Blok',
  }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.ad === 'Test Depo Güncellendi', 'Ad güncellenmedi');
});

// ═══════════════════════════════════════════════════════════════
//  5. ÜRÜNLER
// ═══════════════════════════════════════════════════════════════

test('Ürün — Oluştur', async () => {
  const r = await req('POST', '/urunler', {
    isletme_id: created.isletmeId,
    urun_kodu: `PRD-${Date.now()}`,
    urun_adi: 'Test Ürün API',
    isim_2: 'Test Product API',
    birim: 'KG',
    barkodlar: [`TEST${Date.now()}`],
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status} — ${JSON.stringify(r.data)}`);
  assert(r.data.id, 'Ürün ID alınamadı');
  created.urunId = r.data.id;
  created.urunBarkod = r.data.barkodlar?.split(',')[0];
});

test('Ürün — Oluştur (2. ürün)', async () => {
  const r = await req('POST', '/urunler', {
    isletme_id: created.isletmeId,
    urun_kodu: `PRD2-${Date.now()}`,
    urun_adi: 'Test Ürün 2',
    barkodlar: [`BRK2-${Date.now()}`],
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status}`);
  created.urun2Id = r.data.id;
});

test('Ürün — isletme_id ve urun_adi zorunlu', async () => {
  const r = await req('POST', '/urunler', { isletme_id: created.isletmeId }, adminToken);
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('Ürün — Listele (admin, pagination)', async () => {
  const r = await req('GET', `/urunler?isletme_id=${created.isletmeId}&sayfa=1&limit=10`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.data, 'data array bekleniyor');
  assert(typeof r.data.toplam === 'number', 'toplam bekleniyor');
});

test('Ürün — Arama', async () => {
  const r = await req('GET', `/urunler?isletme_id=${created.isletmeId}&q=Test&sayfa=1`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.data.length > 0, 'Arama sonucu bulunamadı');
});

test('Ürün — Güncelle', async () => {
  const r = await req('PUT', `/urunler/${created.urunId}`, {
    urun_adi: 'Test Ürün Güncellendi',
    birim: 'ADET',
  }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.urun_adi === 'Test Ürün Güncellendi', 'Ad güncellenmedi');
});

test('Ürün — Barkod ile ara', async () => {
  if (!created.urunBarkod) { skipped++; return; }
  const r = await req('GET', `/urunler/barkod/${created.urunBarkod}?isletme_id=${created.isletmeId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.id === created.urunId, 'Barkod ile bulunan ürün eşleşmiyor');
});

test('Ürün — Olmayan barkod → 404', async () => {
  const r = await req('GET', `/urunler/barkod/OLMAYAN99999?isletme_id=${created.isletmeId}`, null, adminToken);
  assert(r.status === 404, `Beklenen 404, gelen ${r.status}`);
});

test('Ürün — Barkod ekle', async () => {
  const yeniBarkod = `YB-${Date.now()}`;
  const r = await req('POST', `/urunler/${created.urunId}/barkod`, { barkod: yeniBarkod }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.barkodlar.includes(yeniBarkod), 'Yeni barkod eklenmedi');
  created.ekleneBarkod = yeniBarkod;
});

test('Ürün — Aynı barkod tekrar ekle → 409', async () => {
  if (!created.ekleneBarkod) { skipped++; return; }
  const r = await req('POST', `/urunler/${created.urunId}/barkod`, { barkod: created.ekleneBarkod }, adminToken);
  assert(r.status === 409, `Beklenen 409, gelen ${r.status}`);
});

test('Ürün — Barkod sil', async () => {
  if (!created.ekleneBarkod) { skipped++; return; }
  const r = await req('DELETE', `/urunler/${created.urunId}/barkod/${created.ekleneBarkod}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(!r.data.barkodlar.includes(created.ekleneBarkod), 'Barkod silinmedi');
});

test('Ürün — Detay', async () => {
  const r = await req('GET', `/urunler/${created.urunId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.id === created.urunId, 'ID eşleşmiyor');
});

// ═══════════════════════════════════════════════════════════════
//  6. SAYIMLAR
// ═══════════════════════════════════════════════════════════════

test('Sayım — Oluştur', async () => {
  const r = await req('POST', '/sayimlar', {
    isletme_id: created.isletmeId,
    depo_id: created.depoId,
    ad: 'Test Sayım API',
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status} — ${JSON.stringify(r.data)}`);
  assert(r.data.id, 'Sayım ID alınamadı');
  assert(r.data.durum === 'devam', 'Durum devam olmalı');
  created.sayimId = r.data.id;
});

test('Sayım — Oluştur (2. sayım — birleştirme için)', async () => {
  const r = await req('POST', '/sayimlar', {
    isletme_id: created.isletmeId,
    depo_id: created.depoId,
    ad: 'Test Sayım 2',
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status}`);
  created.sayim2Id = r.data.id;
});

test('Sayım — Listele (admin, pagination)', async () => {
  const r = await req('GET', `/sayimlar?isletme_id=${created.isletmeId}&sayfa=1&limit=10`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.data, 'data array bekleniyor');
  assert(typeof r.data.toplam === 'number', 'toplam bekleniyor');
});

test('Sayım — Detay', async () => {
  const r = await req('GET', `/sayimlar/${created.sayimId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.id === created.sayimId, 'ID eşleşmiyor');
  assert(r.data.sayim_kalemleri !== undefined, 'sayim_kalemleri bekleniyor');
  assert(r.data.depolar, 'depolar join bekleniyor');
  assert(r.data.isletmeler, 'isletmeler join bekleniyor');
});

test('Sayım — Kalem ekle', async () => {
  const r = await req('POST', `/sayimlar/${created.sayimId}/kalem`, {
    urun_id: created.urunId,
    miktar: 10.5,
    birim: 'KG',
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status} — ${JSON.stringify(r.data)}`);
  assert(r.data.id, 'Kalem ID alınamadı');
  created.kalemId = r.data.id;
});

test('Sayım — Kalem ekle (2. ürün)', async () => {
  const r = await req('POST', `/sayimlar/${created.sayimId}/kalem`, {
    urun_id: created.urun2Id,
    miktar: 5,
    birim: 'ADET',
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status}`);
});

test('Sayım — 2. sayıma kalem ekle', async () => {
  const r = await req('POST', `/sayimlar/${created.sayim2Id}/kalem`, {
    urun_id: created.urunId,
    miktar: 3,
    birim: 'KG',
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status}`);
});

test('Sayım — Kalem güncelle', async () => {
  const r = await req('PUT', `/sayimlar/${created.sayimId}/kalem/${created.kalemId}`, {
    miktar: 15,
    notlar: 'Test notu',
  }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Sayım — Detay (kalemli)', async () => {
  const r = await req('GET', `/sayimlar/${created.sayimId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.sayim_kalemleri.length >= 2, `En az 2 kalem bekleniyor, ${r.data.sayim_kalemleri.length} bulundu`);
});

test('Sayım — Güncelle (ad)', async () => {
  const r = await req('PUT', `/sayimlar/${created.sayimId}`, {
    ad: 'Test Sayım Güncellendi',
  }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Sayım — Tamamla', async () => {
  const r = await req('PUT', `/sayimlar/${created.sayimId}/tamamla`, {}, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Sayım — Tamamlanan sayımda kalem eklenemez', async () => {
  const r = await req('POST', `/sayimlar/${created.sayimId}/kalem`, {
    urun_id: created.urunId,
    miktar: 1,
  }, adminToken);
  assert(r.status === 400 || r.status === 403 || r.status === 409, `Beklenen hata, gelen ${r.status}`);
});

test('Sayım — 2. sayımı tamamla (birleştirme için)', async () => {
  const r = await req('PUT', `/sayimlar/${created.sayim2Id}/tamamla`, {}, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Sayım — Birleştir (topla)', async () => {
  const r = await req('POST', '/sayimlar/topla', {
    sayim_ids: [created.sayimId, created.sayim2Id],
    ad: 'Toplanmış Sayım Test',
    isletme_id: created.isletmeId,
  }, adminToken);
  assert(r.status === 200 || r.status === 201, `Beklenen 200/201, gelen ${r.status} — ${JSON.stringify(r.data)}`);
  if (r.data?.id) created.toplanmisSayimId = r.data.id;
});

test('Sayım — Toplanmış listele', async () => {
  const r = await req('GET', `/sayimlar?isletme_id=${created.isletmeId}&toplama=1&sayfa=1`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Sayım — Durum filtresi', async () => {
  const r = await req('GET', `/sayimlar?isletme_id=${created.isletmeId}&durum=tamamlandi&sayfa=1`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Sayım — 404 olmayan ID', async () => {
  const r = await req('GET', '/sayimlar/olmayan-id-12345', null, adminToken);
  assert(r.status === 404, `Beklenen 404, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════════
//  7. KULLANICILAR
// ═══════════════════════════════════════════════════════════════

test('Kullanıcı — Oluştur', async () => {
  const r = await req('POST', '/kullanicilar', {
    ad_soyad: 'Test Kullanıcı API',
    email: `testuser_${Date.now()}@test.com`,
    sifre: 'test12345678',
    rol: 'kullanici',
    telefon: '+90 555 111 2233',
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status} — ${JSON.stringify(r.data)}`);
  assert(r.data.id, 'Kullanıcı ID alınamadı');
  assert(r.data.rol === 'kullanici', 'Rol kullanıcı olmalı');
  created.userId = r.data.id;
  created.userEmail = r.data.email;
});

test('Kullanıcı — Eksik alanlar → 400', async () => {
  const r = await req('POST', '/kullanicilar', { ad_soyad: 'Eksik' }, adminToken);
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('Kullanıcı — Kısa şifre → 400', async () => {
  const r = await req('POST', '/kullanicilar', {
    ad_soyad: 'Kısa Şifre',
    email: 'kisasifre@test.com',
    sifre: '123',
  }, adminToken);
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('Kullanıcı — Duplicate email → 409', async () => {
  const r = await req('POST', '/kullanicilar', {
    ad_soyad: 'Duplicate',
    email: created.userEmail,
    sifre: 'test12345678',
  }, adminToken);
  assert(r.status === 409, `Beklenen 409, gelen ${r.status}`);
});

test('Kullanıcı — Listele', async () => {
  const r = await req('GET', '/kullanicilar?sayfa=1&limit=10', null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.data, 'data array bekleniyor');
});

test('Kullanıcı — Detay', async () => {
  const r = await req('GET', `/kullanicilar/${created.userId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.id === created.userId, 'ID eşleşmiyor');
  assert(r.data.kullanici_isletme !== undefined, 'kullanici_isletme bekleniyor');
});

test('Kullanıcı — Güncelle', async () => {
  const r = await req('PUT', `/kullanicilar/${created.userId}`, {
    ad_soyad: 'Test Kullanıcı Güncellendi',
  }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.ad_soyad === 'Test Kullanıcı Güncellendi', 'Ad güncellenmedi');
});

test('Kullanıcı — İşletme ata', async () => {
  const r = await req('POST', `/kullanicilar/${created.userId}/isletme`, {
    isletme_id: created.isletmeId,
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status}`);
});

test('Kullanıcı — Yetki güncelle', async () => {
  const r = await req('PUT', `/kullanicilar/${created.userId}/yetkiler`, {
    isletme_id: created.isletmeId,
    yetkiler: {
      urun: { goruntule: true, ekle: true, duzenle: true, sil: false },
      depo: { goruntule: true, ekle: false, duzenle: false, sil: false },
      sayim: { goruntule: true, ekle: true, duzenle: true, sil: false },
      toplam_sayim: { goruntule: true, ekle: false, duzenle: false, sil: false },
    },
  }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.yetkiler, 'Yetkiler döndürülmedi');
});

test('Kullanıcı — Yetki sorgula', async () => {
  const r = await req('GET', `/kullanicilar/${created.userId}/yetkiler?isletme_id=${created.isletmeId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.yetkiler, 'Yetkiler alınamadı');
  assert(r.data.yetkiler.urun.ekle === true, 'Ürün ekle yetkisi true olmalı');
});

// Kullanıcı login ve yetki testi
test('Kullanıcı — Normal kullanıcı login', async () => {
  const r = await req('POST', '/auth/login', {
    email: created.userEmail,
    password: 'test12345678',
  });
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.token, 'Token alınamadı');
  userToken = r.data.token;
});

test('Kullanıcı — Normal kullanıcı /auth/me', async () => {
  const r = await req('GET', '/auth/me', null, userToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.yetkilerMap, 'yetkilerMap bekleniyor');
  assert(r.data.yetkilerMap[created.isletmeId], 'İşletme yetkisi bekleniyor');
});

test('Kullanıcı — Normal kullanıcı admin endpoint → 403', async () => {
  const r = await req('GET', '/isletmeler', null, userToken);
  assert(r.status === 403, `Beklenen 403, gelen ${r.status}`);
});

test('Kullanıcı — Normal kullanıcı kendi işletme ürünlerini listele', async () => {
  const r = await req('GET', `/urunler?isletme_id=${created.isletmeId}`, null, userToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Kullanıcı — Normal kullanıcı kendi işletme depolarını listele', async () => {
  const r = await req('GET', `/depolar?isletme_id=${created.isletmeId}`, null, userToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Kullanıcı — Normal kullanıcı yeni sayım oluştur', async () => {
  const r = await req('POST', '/sayimlar', {
    isletme_id: created.isletmeId,
    depo_id: created.depoId,
    ad: 'Kullanıcı Sayım Test',
  }, userToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status}`);
  if (r.data?.id) created.userSayimId = r.data.id;
});

test('Kullanıcı — Normal kullanıcı yetkisiz işletme → 403', async () => {
  const r = await req('GET', `/urunler?isletme_id=${created.isletme2Id}`, null, userToken);
  assert(r.status === 403, `Beklenen 403, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════════
//  8. ROLLER
// ═══════════════════════════════════════════════════════════════

test('Rol — Listele', async () => {
  const r = await req('GET', '/roller', null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(Array.isArray(r.data), 'Array bekleniyor');
});

test('Rol — Oluştur', async () => {
  const r = await req('POST', '/roller', {
    ad: `Test Rol ${Date.now()}`,
    yetkiler: {
      urun: { goruntule: true, ekle: true, duzenle: false, sil: false },
      depo: { goruntule: true, ekle: false, duzenle: false, sil: false },
      sayim: { goruntule: true, ekle: true, duzenle: true, sil: false },
      toplam_sayim: { goruntule: false, ekle: false, duzenle: false, sil: false },
    },
  }, adminToken);
  assert(r.status === 201, `Beklenen 201, gelen ${r.status}`);
  assert(r.data.id, 'Rol ID alınamadı');
  created.rolId = r.data.id;
});

test('Rol — Ad zorunlu', async () => {
  const r = await req('POST', '/roller', {}, adminToken);
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('Rol — Güncelle', async () => {
  const r = await req('PUT', `/roller/${created.rolId}`, {
    ad: 'Test Rol Güncellendi',
    yetkiler: {
      urun: { goruntule: true, ekle: true, duzenle: true, sil: true },
      depo: { goruntule: true, ekle: true, duzenle: true, sil: true },
      sayim: { goruntule: true, ekle: true, duzenle: true, sil: true },
      toplam_sayim: { goruntule: true, ekle: true, duzenle: true, sil: true },
    },
  }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Rol — Atanmışlar', async () => {
  const r = await req('GET', `/roller/${created.rolId}/atanmislar`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(Array.isArray(r.data), 'Array bekleniyor');
});

// ═══════════════════════════════════════════════════════════════
//  9. PROFİL
// ═══════════════════════════════════════════════════════════════

test('Profil — İşletmelerim', async () => {
  const r = await req('GET', '/profil/isletmelerim', null, userToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(Array.isArray(r.data), 'Array bekleniyor');
  assert(r.data.length > 0, 'En az 1 işletme bekleniyor');
});

test('Profil — Stats', async () => {
  const r = await req('GET', '/profil/stats', null, userToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(typeof r.data.sayimlar === 'number', 'sayimlar sayı olmalı');
  assert(typeof r.data.urunler === 'number', 'urunler sayı olmalı');
  assert(typeof r.data.depolar === 'number', 'depolar sayı olmalı');
});

test('Profil — Ayarlar güncelle', async () => {
  const r = await req('PUT', '/profil/ayarlar', {
    ayarlar: { tema: 'dark', dil: 'tr' },
  }, userToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(r.data.ok === true, 'ok=true bekleniyor');
});

// ═══════════════════════════════════════════════════════════════
//  10. STATS (Dashboard)
// ═══════════════════════════════════════════════════════════════

test('Stats — Dashboard', async () => {
  const r = await req('GET', '/stats', null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(typeof r.data.isletme === 'number', 'isletme sayısı bekleniyor');
  assert(typeof r.data.depo === 'number', 'depo sayısı bekleniyor');
  assert(typeof r.data.kullanici === 'number', 'kullanici sayısı bekleniyor');
  assert(typeof r.data.urun === 'number', 'urun sayısı bekleniyor');
  assert(typeof r.data.sayim_devam === 'number', 'sayim_devam bekleniyor');
  assert(typeof r.data.sayim_tamamlandi === 'number', 'sayim_tamamlandi bekleniyor');
  assert(typeof r.data.sayim_toplam === 'number', 'sayim_toplam bekleniyor');
});

test('Stats — Sayım trend', async () => {
  const r = await req('GET', '/stats/sayim-trend', null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(Array.isArray(r.data), 'Array bekleniyor');
});

test('Stats — İşletme sayımları', async () => {
  const r = await req('GET', '/stats/isletme-sayimlar', null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(Array.isArray(r.data), 'Array bekleniyor');
});

test('Stats — Son sayımlar', async () => {
  const r = await req('GET', '/stats/son-sayimlar', null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  assert(Array.isArray(r.data), 'Array bekleniyor');
});

// ═══════════════════════════════════════════════════════════════
//  11. AUTH — Şifre & Email Güncelleme
// ═══════════════════════════════════════════════════════════════

test('Auth — Şifre güncelle (yanlış eski şifre) → 401', async () => {
  const r = await req('PUT', '/auth/update-password', {
    eskiSifre: 'yanlis123456',
    yeniSifre: 'yenisifre123',
  }, userToken);
  assert(r.status === 401, `Beklenen 401, gelen ${r.status}`);
});

test('Auth — Şifre güncelle (kısa yeni şifre) → 400', async () => {
  const r = await req('PUT', '/auth/update-password', {
    eskiSifre: 'test12345678',
    yeniSifre: '123',
  }, userToken);
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('Auth — Şifre güncelle başarılı', async () => {
  const r = await req('PUT', '/auth/update-password', {
    eskiSifre: 'test12345678',
    yeniSifre: 'yenisifre12345',
  }, userToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Auth — Yeni şifre ile login', async () => {
  const r = await req('POST', '/auth/login', {
    email: created.userEmail,
    password: 'yenisifre12345',
  });
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
  userToken = r.data.token;
});

// ═══════════════════════════════════════════════════════════════
//  12. CLEANUP — Oluşturulan verileri temizle
// ═══════════════════════════════════════════════════════════════

test('Cleanup — Sayım kalem sil', async () => {
  if (!created.kalemId) { skipped++; return; }
  // Tamamlanmış sayımda kalem silinemez — bu beklenen bir durum
  const r = await req('DELETE', `/sayimlar/${created.sayimId}/kalem/${created.kalemId}`, null, adminToken);
  // Tamamlanmış sayımda 400/403 dönebilir
  assert(r.status === 200 || r.status === 400 || r.status === 403 || r.status === 409, `Beklenmeyen status: ${r.status}`);
});

test('Cleanup — Ürün aktif sayımda sil → 409', async () => {
  // Kullanıcının devam eden sayımında ürün varsa 409 dönmeli
  if (!created.userSayimId || !created.urunId) { skipped++; return; }
  // Önce kullanıcı sayımına kalem ekle
  await req('POST', `/sayimlar/${created.userSayimId}/kalem`, {
    urun_id: created.urunId, miktar: 1,
  }, userToken);
  const r = await req('DELETE', `/urunler/${created.urunId}`, null, adminToken);
  assert(r.status === 409, `Beklenen 409 (aktif sayımda), gelen ${r.status}`);
});

test('Cleanup — Kullanıcı sayımını sil', async () => {
  if (!created.userSayimId) { skipped++; return; }
  const r = await req('DELETE', `/sayimlar/${created.userSayimId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Cleanup — Ürün sil (soft delete)', async () => {
  if (!created.urunId) { skipped++; return; }
  const r = await req('DELETE', `/urunler/${created.urunId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Cleanup — Ürün geri al (restore)', async () => {
  if (!created.urunId) { skipped++; return; }
  const r = await req('PUT', `/urunler/${created.urunId}/restore`, {}, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Cleanup — Depo sil (soft delete)', async () => {
  if (!created.depoId) { skipped++; return; }
  // Aktif sayımlar olabilir
  const r = await req('DELETE', `/depolar/${created.depoId}`, null, adminToken);
  // 200 veya 409 (aktif sayımda) kabul
  assert(r.status === 200 || r.status === 409, `Beklenen 200/409, gelen ${r.status}`);
});

test('Cleanup — Kullanıcı işletme ataması kaldır', async () => {
  if (!created.userId || !created.isletmeId) { skipped++; return; }
  const r = await req('DELETE', `/kullanicilar/${created.userId}/isletme/${created.isletmeId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Cleanup — Kullanıcı pasife al → login edilemez', async () => {
  if (!created.userId) { skipped++; return; }
  const r = await req('PUT', `/kullanicilar/${created.userId}`, { aktif: false }, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);

  // Pasif kullanıcı login → 403
  const loginR = await req('POST', '/auth/login', {
    email: created.userEmail,
    password: 'yenisifre12345',
  });
  assert(loginR.status === 403, `Pasif kullanıcı login — beklenen 403, gelen ${loginR.status}`);
});

test('Cleanup — Kullanıcı geri al (restore)', async () => {
  if (!created.userId) { skipped++; return; }
  const r = await req('PUT', `/kullanicilar/${created.userId}/restore`, {}, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Cleanup — Rol sil', async () => {
  if (!created.rolId) { skipped++; return; }
  const r = await req('DELETE', `/roller/${created.rolId}`, {}, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Cleanup — İşletme pasife al', async () => {
  if (!created.isletmeId) { skipped++; return; }
  const r = await req('DELETE', `/isletmeler/${created.isletmeId}`, null, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

test('Cleanup — İşletme geri al (restore)', async () => {
  if (!created.isletmeId) { skipped++; return; }
  const r = await req('PUT', `/isletmeler/${created.isletmeId}/restore`, {}, adminToken);
  assert(r.status === 200, `Beklenen 200, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════════
//  RUN
// ═══════════════════════════════════════════════════════════════

runTests();
