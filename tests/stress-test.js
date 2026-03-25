#!/usr/bin/env node
/**
 * StokSay — Kapsamlı Stres & Davranış Testi
 * ===========================================
 * Büyük veri seti üzerinde tüm özellikleri test eder.
 * Hem Node.js hem PHP backend'e karşı çalışır.
 *
 * Kullanım: node tests/stress-test.js [BASE_URL]
 */

const BASE_URL = process.argv[2] || 'http://localhost:3001';
const API = `${BASE_URL}/api`;

// ─── Test altyapısı ───
let passed = 0, failed = 0;
const errors = [];
const results = [];
const timings = {};

// ─── State ───
let adminToken = '';
let userToken = '';
let userId = '';
let userEmail = '';
const state = {
  isletmeId: null,
  isletme2Id: null,
  depoId: null,
  depo2Id: null,
  urunIds: [],
  sayimId: null,
  sayim2Id: null,
  kalemIds: [],
  toplanmisSayimId: null,
  rolId: null,
  testUserId: null,
};

// ─── HTTP Helper ───
async function req(method, path, body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const opts = { method, headers };
  if (body) opts.body = JSON.stringify(body);
  const start = Date.now();
  try {
    const res = await fetch(`${API}${path}`, opts);
    const ms = Date.now() - start;
    const ct = res.headers.get('content-type') || '';
    const data = ct.includes('json') ? await res.json() : await res.text();
    return { status: res.status, data, ms, ok: res.ok };
  } catch (err) {
    return { status: 0, data: null, ms: Date.now() - start, ok: false, error: err.message };
  }
}

function test(name, fn) { results.push({ name, fn }); }
function assert(cond, msg) { if (!cond) throw new Error(msg); }

// ═══════════════════════════════════════════════════════════════
//  BÖLÜM 1: SEED DATA DOĞRULAMA
// ═══════════════════════════════════════════════════════════════

test('1.1 Admin login', async () => {
  const r = await req('POST', '/auth/login', { email: 'admin@stoksay.com', password: 'TestAdmin1234!' });
  assert(r.status === 200, `Status ${r.status}: ${JSON.stringify(r.data)}`);
  assert(r.data.token, 'Token yok');
  adminToken = r.data.token;
});

test('1.2 Stats — büyük veri seti doğrulama', async () => {
  const r = await req('GET', '/stats', null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['stats'] = r.ms;
  console.log(`     → İşletme:${r.data.isletme} Depo:${r.data.depo} Kullanıcı:${r.data.kullanici} Ürün:${r.data.urun} Sayım:${r.data.sayim_toplam} (${r.ms}ms)`);
  assert(r.data.isletme >= 10, `En az 10 işletme bekleniyor, ${r.data.isletme} var`);
  assert(r.data.urun >= 100, `En az 100 ürün bekleniyor, ${r.data.urun} var`);
});

test('1.3 İşletme listele — pagination performans', async () => {
  const r = await req('GET', '/isletmeler?sayfa=1&limit=50', null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['isletme_list'] = r.ms;
  assert(r.data.data.length > 0, 'Veri yok');
  state.isletmeId = r.data.data[0].id;
  if (r.data.data.length > 1) state.isletme2Id = r.data.data[1].id;
});

test('1.4 Depo listele — performans', async () => {
  const r = await req('GET', `/depolar?isletme_id=${state.isletmeId}&sayfa=1&limit=50`, null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['depo_list'] = r.ms;
  if (r.data.data && r.data.data.length > 0) {
    state.depoId = r.data.data[0].id;
    if (r.data.data.length > 1) state.depo2Id = r.data.data[1].id;
  }
});

test('1.5 Ürün listele — büyük veri pagination', async () => {
  const r = await req('GET', `/urunler?isletme_id=${state.isletmeId}&sayfa=1&limit=200`, null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['urun_list'] = r.ms;
  assert(r.data.data, 'data array yok');
  // İlk 5 ürün ID'sini sakla
  state.urunIds = r.data.data.slice(0, 5).map(u => u.id);
  console.log(`     → ${r.data.toplam} ürün, sayfa 1 (${r.ms}ms)`);
});

test('1.6 Ürün arama — performans', async () => {
  const r = await req('GET', `/urunler?isletme_id=${state.isletmeId}&q=Ürün&sayfa=1&limit=20`, null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['urun_search'] = r.ms;
});

test('1.7 Sayım listele — performans', async () => {
  const r = await req('GET', `/sayimlar?isletme_id=${state.isletmeId}&sayfa=1&limit=50`, null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['sayim_list'] = r.ms;
});

// ═══════════════════════════════════════════════════════════════
//  BÖLÜM 2: CRUD OPERASYONLARİ — Oluştur
// ═══════════════════════════════════════════════════════════════

test('2.1 Yeni işletme oluştur', async () => {
  const r = await req('POST', '/isletmeler', {
    ad: 'Stres Test İşletme', kod: `STRES-${Date.now()}`, adres: 'Test Cad. 1', telefon: '+90 555 000 0001',
  }, adminToken);
  assert(r.status === 201, `Status ${r.status}`);
  state.testIsletmeId = r.data.id;
});

test('2.2 Yeni depo oluştur (2 adet)', async () => {
  for (let i = 0; i < 2; i++) {
    const r = await req('POST', '/depolar', {
      isletme_id: state.testIsletmeId, ad: `Stres Depo ${i+1}`, kod: `SD${i+1}`,
    }, adminToken);
    assert(r.status === 201, `Depo ${i+1} — Status ${r.status}`);
    if (i === 0) state.testDepoId = r.data.id;
    else state.testDepo2Id = r.data.id;
  }
});

test('2.3 Toplu ürün oluştur (20 adet)', async () => {
  const start = Date.now();
  const ids = [];
  for (let i = 0; i < 20; i++) {
    const r = await req('POST', '/urunler', {
      isletme_id: state.testIsletmeId,
      urun_kodu: `STRES-URN-${Date.now()}-${i}`,
      urun_adi: `Stres Test Ürün ${i+1}`,
      isim_2: `Stress Product ${i+1}`,
      birim: i % 2 === 0 ? 'KG' : 'ADET',
      barkodlar: [`STRESBRK${Date.now()}${i}`],
    }, adminToken);
    assert(r.status === 201, `Ürün ${i+1} — Status ${r.status}`);
    ids.push(r.data.id);
  }
  state.testUrunIds = ids;
  timings['bulk_urun_create'] = Date.now() - start;
  console.log(`     → 20 ürün: ${timings['bulk_urun_create']}ms`);
});

test('2.4 Rol oluştur', async () => {
  const r = await req('POST', '/roller', {
    ad: `Stres Test Rol ${Date.now()}`,
    yetkiler: {
      urun: { goruntule: true, ekle: true, duzenle: true, sil: true },
      depo: { goruntule: true, ekle: true, duzenle: true, sil: false },
      sayim: { goruntule: true, ekle: true, duzenle: true, sil: true },
      toplam_sayim: { goruntule: true, ekle: true, duzenle: false, sil: false },
    },
  }, adminToken);
  assert(r.status === 201, `Status ${r.status}`);
  state.rolId = r.data.id;
});

test('2.5 Kullanıcı oluştur + işletme ata + yetki ver', async () => {
  // Oluştur
  const ts = Date.now();
  userEmail = `strestest_${ts}@test.com`;
  let r = await req('POST', '/kullanicilar', {
    ad_soyad: 'Stres Test Kullanıcı', email: userEmail, sifre: 'stres12345678', rol: 'kullanici',
  }, adminToken);
  assert(r.status === 201, `Create — Status ${r.status}`);
  state.testUserId = r.data.id;

  // İşletme ata
  r = await req('POST', `/kullanicilar/${state.testUserId}/isletme`, {
    isletme_id: state.testIsletmeId,
  }, adminToken);
  assert(r.status === 201, `Assign — Status ${r.status}`);

  // Yetki ver
  r = await req('PUT', `/kullanicilar/${state.testUserId}/yetkiler`, {
    isletme_id: state.testIsletmeId,
    yetkiler: {
      urun: { goruntule: true, ekle: true, duzenle: true, sil: true },
      depo: { goruntule: true, ekle: true, duzenle: false, sil: false },
      sayim: { goruntule: true, ekle: true, duzenle: true, sil: true },
      toplam_sayim: { goruntule: true, ekle: true, duzenle: false, sil: false },
    },
    rol_id: state.rolId,
  }, adminToken);
  assert(r.status === 200, `Perms — Status ${r.status}`);
});

test('2.6 Kullanıcı login', async () => {
  const r = await req('POST', '/auth/login', { email: userEmail, password: 'stres12345678' });
  assert(r.status === 200, `Status ${r.status}`);
  userToken = r.data.token;
});

// ═══════════════════════════════════════════════════════════════
//  BÖLÜM 3: KULLANICI İŞLEMLERİ (yetki bazlı)
// ═══════════════════════════════════════════════════════════════

test('3.1 Kullanıcı — kendi işletme ürünlerini listele', async () => {
  const r = await req('GET', `/urunler?isletme_id=${state.testIsletmeId}`, null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
  assert(Array.isArray(r.data), 'Array bekleniyor');
  assert(r.data.length === 20, `20 ürün bekleniyor, ${r.data.length} bulundu`);
});

test('3.2 Kullanıcı — depo listele', async () => {
  const r = await req('GET', `/depolar?isletme_id=${state.testIsletmeId}`, null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
});

test('3.3 Kullanıcı — yetkisiz işletmeye erişim → 403', async () => {
  const r = await req('GET', `/urunler?isletme_id=${state.isletmeId}`, null, userToken);
  assert(r.status === 403, `Beklenen 403, gelen ${r.status}`);
});

test('3.4 Kullanıcı — sayım oluştur', async () => {
  const r = await req('POST', '/sayimlar', {
    isletme_id: state.testIsletmeId, depo_id: state.testDepoId, ad: 'Kullanıcı Stres Sayım 1',
  }, userToken);
  assert(r.status === 201, `Status ${r.status}`);
  state.sayimId = r.data.id;
});

test('3.5 Kullanıcı — 2. sayım oluştur', async () => {
  const r = await req('POST', '/sayimlar', {
    isletme_id: state.testIsletmeId, depo_id: state.testDepo2Id, ad: 'Kullanıcı Stres Sayım 2',
  }, userToken);
  assert(r.status === 201, `Status ${r.status}`);
  state.sayim2Id = r.data.id;
});

test('3.6 Kullanıcı — toplu kalem ekle (10 ürün × 2 sayım)', async () => {
  const start = Date.now();
  for (let i = 0; i < 10; i++) {
    const r = await req('POST', `/sayimlar/${state.sayimId}/kalem`, {
      urun_id: state.testUrunIds[i], miktar: (i + 1) * 2.5, birim: i % 2 === 0 ? 'KG' : 'ADET',
    }, userToken);
    assert(r.status === 201, `Kalem ${i+1} sayım1 — Status ${r.status}`);
    state.kalemIds.push(r.data.id);
  }
  for (let i = 0; i < 5; i++) {
    const r = await req('POST', `/sayimlar/${state.sayim2Id}/kalem`, {
      urun_id: state.testUrunIds[i], miktar: (i + 1) * 1.5, birim: 'KG',
    }, userToken);
    assert(r.status === 201, `Kalem ${i+1} sayım2 — Status ${r.status}`);
  }
  timings['bulk_kalem_add'] = Date.now() - start;
  console.log(`     → 15 kalem: ${timings['bulk_kalem_add']}ms`);
});

test('3.7 Kullanıcı — kalem güncelle', async () => {
  const r = await req('PUT', `/sayimlar/${state.sayimId}/kalem/${state.kalemIds[0]}`, {
    miktar: 99.9, notlar: 'Stres test güncellemesi',
  }, userToken);
  assert(r.status === 200, `Status ${r.status}`);
});

test('3.8 Kullanıcı — kalem sil', async () => {
  const r = await req('DELETE', `/sayimlar/${state.sayimId}/kalem/${state.kalemIds[9]}`, null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
});

test('3.9 Kullanıcı — sayım detay (kalemli)', async () => {
  const r = await req('GET', `/sayimlar/${state.sayimId}`, null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
  assert(r.data.sayim_kalemleri.length === 9, `9 kalem bekleniyor, ${r.data.sayim_kalemleri.length} bulundu`);
  timings['sayim_detail'] = r.ms;
});

// ═══════════════════════════════════════════════════════════════
//  BÖLÜM 4: ÜRÜN YÖNETİMİ
// ═══════════════════════════════════════════════════════════════

test('4.1 Ürün güncelle', async () => {
  const r = await req('PUT', `/urunler/${state.testUrunIds[0]}`, {
    urun_adi: 'Güncellenen Stres Ürün', birim: 'LT',
  }, userToken);
  assert(r.status === 200, `Status ${r.status}`);
  assert(r.data.urun_adi === 'Güncellenen Stres Ürün', 'Ad güncellenmedi');
});

test('4.2 Ürün barkod ekle', async () => {
  const yeniBarkod = `EKBRK-${Date.now()}`;
  const r = await req('POST', `/urunler/${state.testUrunIds[1]}/barkod`, { barkod: yeniBarkod }, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  state.ekleneBarkod = yeniBarkod;
});

test('4.3 Barkod ile ürün ara', async () => {
  const r = await req('GET', `/urunler/barkod/${state.ekleneBarkod}?isletme_id=${state.testIsletmeId}`, null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  assert(r.data.id === state.testUrunIds[1], 'Yanlış ürün bulundu');
});

test('4.4 Aktif sayımda ürün sil → 409', async () => {
  const r = await req('DELETE', `/urunler/${state.testUrunIds[0]}`, null, userToken);
  assert(r.status === 409, `Beklenen 409, gelen ${r.status}`);
  assert(r.data.sayimlar, 'Sayım adları bekleniyor');
});

test('4.5 Ürün oluştur + yeni barkod', async () => {
  const r = await req('POST', '/urunler', {
    isletme_id: state.testIsletmeId, urun_adi: 'Barkodlu Yeni Ürün',
    barkodlar: [`YENI-${Date.now()}`],
  }, userToken);
  assert(r.status === 201, `Status ${r.status}`);
  state.newUrunId = r.data.id;
});

// ═══════════════════════════════════════════════════════════════
//  BÖLÜM 5: SAYIM TAMAMLA & BİRLEŞTİR
// ═══════════════════════════════════════════════════════════════

test('5.1 Sayım tamamla (1)', async () => {
  const r = await req('PUT', `/sayimlar/${state.sayimId}/tamamla`, {}, userToken);
  assert(r.status === 200, `Status ${r.status}`);
});

test('5.2 Tamamlanan sayıma kalem eklenemez', async () => {
  const r = await req('POST', `/sayimlar/${state.sayimId}/kalem`, {
    urun_id: state.testUrunIds[15], miktar: 1,
  }, userToken);
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('5.3 Sayım tamamla (2)', async () => {
  const r = await req('PUT', `/sayimlar/${state.sayim2Id}/tamamla`, {}, userToken);
  assert(r.status === 200, `Status ${r.status}`);
});

test('5.4 Sayımları birleştir (topla)', async () => {
  const r = await req('POST', '/sayimlar/topla', {
    sayim_ids: [state.sayimId, state.sayim2Id],
    ad: 'Birleştirilmiş Stres Sayım',
    isletme_id: state.testIsletmeId,
  }, userToken);
  assert(r.status === 201 || r.status === 200, `Status ${r.status}`);
  state.toplanmisSayimId = r.data?.id;
  timings['topla'] = r.ms;
});

test('5.5 Toplanmış sayım detay', async () => {
  if (!state.toplanmisSayimId) return;
  const r = await req('GET', `/sayimlar/${state.toplanmisSayimId}`, null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
  // Birleştirmede aynı ürünlerin miktarları toplandı mı?
  const kalemleri = r.data.sayim_kalemleri || [];
  assert(kalemleri.length > 0, 'Birleştirilmiş sayımda kalem yok');
  console.log(`     → ${kalemleri.length} benzersiz ürün birleştirildi`);
});

// ═══════════════════════════════════════════════════════════════
//  BÖLÜM 6: PROFİL & STATS
// ═══════════════════════════════════════════════════════════════

test('6.1 Profil — işletmelerim', async () => {
  const r = await req('GET', '/profil/isletmelerim', null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
  assert(Array.isArray(r.data) && r.data.length > 0, 'İşletme bekleniyor');
});

test('6.2 Profil — stats', async () => {
  const r = await req('GET', '/profil/stats', null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
  assert(r.data.sayimlar >= 2, `En az 2 sayım bekleniyor, ${r.data.sayimlar} var`);
});

test('6.3 Profil — ayarlar güncelle', async () => {
  const r = await req('PUT', '/profil/ayarlar', { ayarlar: { tema: 'dark', dil: 'tr', barkod_sesi: true } }, userToken);
  assert(r.status === 200, `Status ${r.status}`);
});

test('6.4 Admin stats — dashboard', async () => {
  const r = await req('GET', '/stats', null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['admin_stats'] = r.ms;
});

test('6.5 Admin stats — sayım trend', async () => {
  const r = await req('GET', '/stats/sayim-trend', null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['sayim_trend'] = r.ms;
});

test('6.6 Admin stats — son sayımlar', async () => {
  const r = await req('GET', '/stats/son-sayimlar', null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  assert(Array.isArray(r.data) && r.data.length > 0, 'Son sayımlar bekleniyor');
});

// ═══════════════════════════════════════════════════════════════
//  BÖLÜM 7: MOBİL SİMÜLASYON (Online/Offline Sync)
// ═══════════════════════════════════════════════════════════════

test('7.1 Mobil sync — tam depo pull', async () => {
  const start = Date.now();
  const r = await req('GET', `/depolar?isletme_id=${state.testIsletmeId}`, null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['sync_depo'] = Date.now() - start;
});

test('7.2 Mobil sync — tam ürün pull (sayfalı)', async () => {
  const start = Date.now();
  const r = await req('GET', `/urunler?isletme_id=${state.testIsletmeId}&sayfa=1&limit=200`, null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['sync_urun'] = Date.now() - start;
});

test('7.3 Mobil sync — tam sayım pull', async () => {
  const start = Date.now();
  const r = await req('GET', `/sayimlar?isletme_id=${state.testIsletmeId}&sayfa=1&limit=200`, null, userToken);
  assert(r.status === 200, `Status ${r.status}`);
  timings['sync_sayim'] = Date.now() - start;
});

test('7.4 Mobil — offline sonrası yeni sayım push', async () => {
  const r = await req('POST', '/sayimlar', {
    isletme_id: state.testIsletmeId, depo_id: state.testDepoId, ad: 'Offline Sync Sayım',
  }, userToken);
  assert(r.status === 201, `Status ${r.status}`);
  state.offlineSayimId = r.data.id;
});

test('7.5 Mobil — offline kalem push (5 adet)', async () => {
  for (let i = 10; i < 15; i++) {
    const r = await req('POST', `/sayimlar/${state.offlineSayimId}/kalem`, {
      urun_id: state.testUrunIds[i], miktar: (i - 9) * 3, birim: 'ADET',
    }, userToken);
    assert(r.status === 201, `Kalem ${i-9} — Status ${r.status}`);
  }
});

// ═══════════════════════════════════════════════════════════════
//  BÖLÜM 8: ŞİFRE & AUTH İŞLEMLERİ
// ═══════════════════════════════════════════════════════════════

test('8.1 Şifre güncelle', async () => {
  const r = await req('PUT', '/auth/update-password', {
    eskiSifre: 'stres12345678', yeniSifre: 'yenistres12345',
  }, userToken);
  assert(r.status === 200, `Status ${r.status}`);
});

test('8.2 Yeni şifre ile login', async () => {
  const r = await req('POST', '/auth/login', { email: userEmail, password: 'yenistres12345' });
  assert(r.status === 200, `Status ${r.status}`);
  userToken = r.data.token;
});

// ═══════════════════════════════════════════════════════════════
//  BÖLÜM 9: CLEANUP
// ═══════════════════════════════════════════════════════════════

test('9.1 Sayımları sil', async () => {
  if (state.offlineSayimId) {
    await req('DELETE', `/sayimlar/${state.offlineSayimId}`, null, adminToken);
  }
  if (state.toplanmisSayimId) {
    await req('DELETE', `/sayimlar/${state.toplanmisSayimId}`, null, adminToken);
  }
});

test('9.2 Ürünleri sil', async () => {
  for (const id of (state.testUrunIds || [])) {
    await req('DELETE', `/urunler/${id}`, null, adminToken);
  }
  if (state.newUrunId) await req('DELETE', `/urunler/${state.newUrunId}`, null, adminToken);
});

test('9.3 Depoları sil', async () => {
  if (state.testDepoId) await req('DELETE', `/depolar/${state.testDepoId}`, null, adminToken);
  if (state.testDepo2Id) await req('DELETE', `/depolar/${state.testDepo2Id}`, null, adminToken);
});

test('9.4 Kullanıcı pasife al', async () => {
  if (state.testUserId) {
    await req('PUT', `/kullanicilar/${state.testUserId}`, { aktif: false }, adminToken);
  }
});

test('9.5 Rol sil', async () => {
  if (state.rolId) await req('DELETE', `/roller/${state.rolId}`, {}, adminToken);
});

test('9.6 İşletme pasife al', async () => {
  if (state.testIsletmeId) await req('DELETE', `/isletmeler/${state.testIsletmeId}`, null, adminToken);
});

// ═══════════════════════════════════════════════════════════════
//  RUN
// ═══════════════════════════════════════════════════════════════

async function runTests() {
  const totalStart = Date.now();
  console.log('\n╔══════════════════════════════════════════════════════════════╗');
  console.log('║       StokSay Kapsamlı Stres & Davranış Testi               ║');
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

  const totalMs = Date.now() - totalStart;

  console.log('\n══════════════════════════════════════════════════════════════');
  console.log(`  Sonuç: ${passed} başarılı, ${failed} başarısız, toplam ${passed + failed}`);
  console.log(`  Toplam süre: ${(totalMs / 1000).toFixed(1)}s`);
  console.log('══════════════════════════════════════════════════════════════');

  if (Object.keys(timings).length) {
    console.log('\n  ⏱  Performans:');
    for (const [k, v] of Object.entries(timings)) {
      console.log(`     ${k.padEnd(25)} ${v}ms`);
    }
  }

  if (errors.length) {
    console.log('\n  Başarısız:');
    errors.forEach(e => console.log(`    - ${e.name}: ${e.error}`));
  }

  const fs = require('fs');
  const report = {
    backend: BASE_URL, timestamp: new Date().toISOString(),
    summary: { passed, failed, total: passed + failed, duration_ms: totalMs },
    timings, errors,
  };
  const reportPath = `${__dirname}/stress-report-${Date.now()}.json`;
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`\n  Rapor: ${reportPath}\n`);

  process.exit(failed > 0 ? 1 : 0);
}

runTests();
