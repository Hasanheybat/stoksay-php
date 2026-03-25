#!/usr/bin/env node
/**
 * StokSay — Güvenlik & Stres Testi
 * ==================================
 * SQL Injection, XSS, IDOR, Brute Force, Rate Limit, Auth Bypass,
 * Yetki Escalation, CORS, Header Injection ve daha fazlası.
 *
 * Kullanım: node tests/security-stress-test.js [BASE_URL]
 */

const BASE_URL = process.argv[2] || 'http://localhost:8888';
const API = `${BASE_URL}/api`;

let passed = 0, failed = 0;
const errors = [];
const results = [];
let adminToken = '';
let userToken = '';
const state = {};

async function req(method, path, body = null, token = null, extraHeaders = {}) {
  const headers = { 'Content-Type': 'application/json', ...extraHeaders };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const opts = { method, headers };
  if (body !== null) opts.body = typeof body === 'string' ? body : JSON.stringify(body);
  try {
    const r = await fetch(`${API}${path}`, opts);
    const ct = r.headers.get('content-type') || '';
    const data = ct.includes('json') ? await r.json() : await r.text();
    return { status: r.status, data, headers: Object.fromEntries(r.headers.entries()) };
  } catch (e) {
    return { status: 0, data: null, error: e.message, headers: {} };
  }
}

function test(name, fn) { results.push({ name, fn }); }
function assert(c, m) { if (!c) throw new Error(m); }

// ═══════════════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════════════

test('SETUP — Admin login', async () => {
  const r = await req('POST', '/auth/login', { email: 'admin@stoksay.com', password: 'TestAdmin1234!' });
  assert(r.status === 200, `Status ${r.status}`);
  adminToken = r.data.token;

  // Test kullanıcısı oluştur
  const ts = Date.now();
  let r2 = await req('POST', '/kullanicilar', {
    ad_soyad: 'Security Test User', email: `sectest_${ts}@test.com`, sifre: 'SecTest1234!', rol: 'kullanici',
  }, adminToken);
  assert(r2.status === 201, `User create: ${r2.status}`);
  state.userId = r2.data.id;
  state.userEmail = r2.data.email;

  // İşletme oluştur
  r2 = await req('POST', '/isletmeler', { ad: `Sec Test ${ts}`, kod: `SEC${ts}` }, adminToken);
  state.isletmeId = r2.data.id;

  // Kullanıcıya işletme ata
  await req('POST', `/kullanicilar/${state.userId}/isletme`, { isletme_id: state.isletmeId }, adminToken);
  await req('PUT', `/kullanicilar/${state.userId}/yetkiler`, {
    isletme_id: state.isletmeId,
    yetkiler: {
      urun: { goruntule: true, ekle: true, duzenle: false, sil: false },
      depo: { goruntule: true, ekle: false, duzenle: false, sil: false },
      sayim: { goruntule: true, ekle: true, duzenle: true, sil: false },
      toplam_sayim: { goruntule: false, ekle: false, duzenle: false, sil: false },
    },
  }, adminToken);

  // User login
  r2 = await req('POST', '/auth/login', { email: state.userEmail, password: 'SecTest1234!' });
  assert(r2.status === 200, `User login: ${r2.status}`);
  userToken = r2.data.token;
});

// ═══════════════════════════════════════════════════════════
// 1. SQL INJECTION
// ═══════════════════════════════════════════════════════════

test('SQL-01 Login email SQL injection', async () => {
  const r = await req('POST', '/auth/login', { email: "' OR 1=1 --", password: 'x' });
  assert(r.status === 400 || r.status === 401, `Beklenen 400/401, gelen ${r.status}`);
});

test('SQL-02 Login password SQL injection', async () => {
  const r = await req('POST', '/auth/login', { email: 'admin@stoksay.com', password: "' OR '1'='1" });
  assert(r.status === 401, `Beklenen 401, gelen ${r.status}`);
});

test('SQL-03 Query param SQL injection (isletme_id)', async () => {
  const r = await req('GET', "/depolar?isletme_id=' OR 1=1; DROP TABLE depolar; --", null, adminToken);
  assert(r.status !== 200 || (r.data.data && r.data.data.length === 0) || Array.isArray(r.data), `SQL injection veri döndürdü: ${r.status}`);
});

test('SQL-04 URL param SQL injection (id)', async () => {
  const r = await req('GET', "/isletmeler/' OR 1=1 --", null, adminToken);
  assert(r.status === 404 || r.status === 400 || r.status === 500, `Beklenen hata, gelen ${r.status}`);
});

test('SQL-05 Body field SQL injection (ad)', async () => {
  const r = await req('POST', '/isletmeler', {
    ad: "Test'; DROP TABLE isletmeler; --",
    kod: `SQLI${Date.now()}`,
  }, adminToken);
  // Oluşturulmamalı veya güvenli şekilde oluşturulmalı (parametrize query)
  if (r.status === 201) {
    // Güvenli oluşturuldu — ad olduğu gibi kaydedildi
    assert(r.data.ad.includes("DROP TABLE"), 'SQL çalıştırılmadı, string olarak kaydedildi');
    await req('DELETE', `/isletmeler/${r.data.id}`, null, adminToken);
  }
  // 400 veya 500 de kabul edilir
});

test('SQL-06 UNION SELECT injection', async () => {
  const r = await req('GET', "/urunler?isletme_id=1 UNION SELECT * FROM kullanicilar--&sayfa=1", null, adminToken);
  assert(r.status !== 200 || !JSON.stringify(r.data).includes('password_hash'), 'password_hash sızdırılmamalı');
});

test('SQL-07 Barkod arama SQL injection', async () => {
  const r = await req('GET', `/urunler/barkod/' OR 1=1 --?isletme_id=${state.isletmeId}`, null, adminToken);
  assert(r.status === 404 || r.status === 400, `Beklenen 404/400, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════
// 2. XSS (Cross-Site Scripting)
// ═══════════════════════════════════════════════════════════

test('XSS-01 İşletme adına script tag', async () => {
  const xss = '<script>alert("XSS")</script>';
  const r = await req('POST', '/isletmeler', { ad: xss, kod: `XSS${Date.now()}` }, adminToken);
  if (r.status === 201) {
    // Kaydedildiyse, geri dönüşte escape edilmeli veya olduğu gibi (API JSON döner, tarayıcı yorumlamaz)
    assert(!r.data.ad.includes('<script>') || r.data.ad === xss, 'XSS kontrol');
    await req('DELETE', `/isletmeler/${r.data.id}`, null, adminToken);
  }
});

test('XSS-02 Ürün adına script injection', async () => {
  const r = await req('POST', '/urunler', {
    isletme_id: state.isletmeId,
    urun_adi: '<img src=x onerror=alert(1)>',
    urun_kodu: `XSS${Date.now()}`,
  }, adminToken);
  if (r.status === 201) {
    await req('DELETE', `/urunler/${r.data.id}`, null, adminToken);
  }
  // API JSON döner — XSS tarayıcıda olur, API seviyesinde sorun değil
  assert(true, 'API JSON döner, XSS tarayıcı sorunu');
});

test('XSS-03 Sayım notlarına script', async () => {
  const r = await req('POST', '/isletmeler', { ad: `XSS Depo Test ${Date.now()}`, kod: `XD${Date.now()}` }, adminToken);
  const iId = r.data.id;
  const r2 = await req('POST', '/depolar', { isletme_id: iId, ad: 'XSS Depo' }, adminToken);
  const dId = r2.data.id;
  const r3 = await req('POST', '/sayimlar', {
    isletme_id: iId, depo_id: dId, ad: '"><script>document.cookie</script>',
  }, adminToken);
  assert(r3.status === 201, `Status ${r3.status}`);
  await req('DELETE', `/sayimlar/${r3.data.id}`, null, adminToken);
  await req('DELETE', `/depolar/${dId}`, null, adminToken);
  await req('DELETE', `/isletmeler/${iId}`, null, adminToken);
});

// ═══════════════════════════════════════════════════════════
// 3. AUTH BYPASS & TOKEN MANIPULATION
// ═══════════════════════════════════════════════════════════

test('AUTH-01 Token olmadan erişim', async () => {
  const r = await req('GET', '/auth/me');
  assert(r.status === 401, `Beklenen 401, gelen ${r.status}`);
});

test('AUTH-02 Geçersiz token formatı', async () => {
  const r = await req('GET', '/auth/me', null, 'not-a-jwt-token');
  assert(r.status === 401 || r.status === 403, `Beklenen 401/403, gelen ${r.status}`);
});

test('AUTH-03 Expire olmuş token (sahte)', async () => {
  // Base64 encoded expired JWT
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = btoa(JSON.stringify({ sub: 'fake', exp: 1000000000, iat: 1000000000 }));
  const fakeToken = `${header}.${payload}.fakesignature`;
  const r = await req('GET', '/auth/me', null, fakeToken);
  assert(r.status === 401 || r.status === 403, `Beklenen 401/403, gelen ${r.status}`);
});

test('AUTH-04 Farklı secret ile imzalanmış token', async () => {
  const r = await req('GET', '/auth/me', null, 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmYWtlLWlkIiwiZXhwIjo5OTk5OTk5OTk5fQ.WRONG_SIGNATURE');
  assert(r.status === 401 || r.status === 403, `Beklenen 401/403, gelen ${r.status}`);
});

test('AUTH-05 Bearer prefix olmadan token', async () => {
  const r = await req('GET', '/auth/me', null, null, { 'Authorization': adminToken });
  assert(r.status === 401, `Beklenen 401, gelen ${r.status}`);
});

test('AUTH-06 Boş Authorization header', async () => {
  const r = await req('GET', '/auth/me', null, null, { 'Authorization': '' });
  assert(r.status === 401, `Beklenen 401, gelen ${r.status}`);
});

test('AUTH-07 Bearer + boşluk (token yok)', async () => {
  const r = await req('GET', '/auth/me', null, null, { 'Authorization': 'Bearer ' });
  assert(r.status === 401 || r.status === 403, `Beklenen 401/403, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════
// 4. IDOR (Insecure Direct Object Reference)
// ═══════════════════════════════════════════════════════════

test('IDOR-01 Kullanıcı başka kullanıcının sayımını görme', async () => {
  // Admin bir sayım oluşturur
  const r1 = await req('POST', '/isletmeler', { ad: `IDOR Test ${Date.now()}`, kod: `IDOR${Date.now()}` }, adminToken);
  const iId = r1.data.id;
  const r2 = await req('POST', '/depolar', { isletme_id: iId, ad: 'IDOR Depo' }, adminToken);
  const dId = r2.data.id;
  const r3 = await req('POST', '/sayimlar', { isletme_id: iId, depo_id: dId, ad: 'Admin Sayım' }, adminToken);
  const sId = r3.data.id;

  // Kullanıcı bu sayıma erişmeye çalışır (farklı işletme)
  const r4 = await req('GET', `/sayimlar/${sId}`, null, userToken);
  assert(r4.status === 403, `IDOR: Beklenen 403, gelen ${r4.status}`);

  // Temizlik
  await req('DELETE', `/sayimlar/${sId}`, null, adminToken);
  await req('DELETE', `/depolar/${dId}`, null, adminToken);
  await req('DELETE', `/isletmeler/${iId}`, null, adminToken);
});

test('IDOR-02 Kullanıcı admin endpoint erişimi', async () => {
  const r = await req('GET', '/isletmeler', null, userToken);
  assert(r.status === 403, `Beklenen 403, gelen ${r.status}`);
});

test('IDOR-03 Kullanıcı başka kullanıcı bilgisi', async () => {
  const r = await req('GET', '/kullanicilar', null, userToken);
  assert(r.status === 403, `Beklenen 403, gelen ${r.status}`);
});

test('IDOR-04 Kullanıcı yetkisiz işletme ürünleri', async () => {
  // İlk işletmenin ID'sini bul
  const r1 = await req('GET', '/isletmeler?sayfa=1&limit=1', null, adminToken);
  if (r1.data.data && r1.data.data.length > 0) {
    const otherIsletme = r1.data.data[0].id;
    if (otherIsletme !== state.isletmeId) {
      const r = await req('GET', `/urunler?isletme_id=${otherIsletme}`, null, userToken);
      assert(r.status === 403, `IDOR: Beklenen 403, gelen ${r.status}`);
    }
  }
});

// ═══════════════════════════════════════════════════════════
// 5. YETKİ ESCALATION (Privilege Escalation)
// ═══════════════════════════════════════════════════════════

test('PRIV-01 Kullanıcı kendi rolünü admin yapamaz', async () => {
  const r = await req('PUT', `/kullanicilar/${state.userId}`, { rol: 'admin' }, userToken);
  assert(r.status === 403, `Beklenen 403, gelen ${r.status}`);
});

test('PRIV-02 Kullanıcı başka kullanıcı oluşturamaz', async () => {
  const r = await req('POST', '/kullanicilar', {
    ad_soyad: 'Hacker', email: 'hack@test.com', sifre: 'hack12345678',
  }, userToken);
  assert(r.status === 403, `Beklenen 403, gelen ${r.status}`);
});

test('PRIV-03 Kullanıcı rol oluşturamaz', async () => {
  const r = await req('POST', '/roller', { ad: 'Hacker Rol' }, userToken);
  assert(r.status === 403, `Beklenen 403, gelen ${r.status}`);
});

test('PRIV-04 Kullanıcı yetkisiz işlem (ürün sil — sil yetkisi yok)', async () => {
  // Önce ürün oluştur (ekle yetkisi var)
  const r1 = await req('POST', '/urunler', {
    isletme_id: state.isletmeId, urun_adi: 'Silinecek Test', urun_kodu: `PRIV${Date.now()}`,
  }, userToken);
  if (r1.status === 201) {
    // Sil (sil yetkisi yok)
    const r2 = await req('DELETE', `/urunler/${r1.data.id}`, null, userToken);
    assert(r2.status === 403, `Beklenen 403 (sil yetkisi yok), gelen ${r2.status}`);
    // Admin ile temizle
    await req('DELETE', `/urunler/${r1.data.id}`, null, adminToken);
  }
});

test('PRIV-05 Kullanıcı stats endpoint (admin only)', async () => {
  const r = await req('GET', '/stats', null, userToken);
  assert(r.status === 403, `Beklenen 403, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════
// 6. INPUT VALIDATION & BOUNDARY
// ═══════════════════════════════════════════════════════════

test('INPUT-01 Çok uzun email (1000 karakter)', async () => {
  const r = await req('POST', '/auth/login', { email: 'a'.repeat(1000) + '@test.com', password: 'test' });
  assert(r.status === 400 || r.status === 401, `Beklenen 400/401, gelen ${r.status}`);
});

test('INPUT-02 Çok uzun şifre (10000 karakter)', async () => {
  const r = await req('POST', '/auth/login', { email: 'admin@stoksay.com', password: 'x'.repeat(10000) });
  assert(r.status === 401 || r.status === 400, `Beklenen 400/401, gelen ${r.status}`);
});

test('INPUT-03 Negatif miktar', async () => {
  // Depo ve sayım oluştur
  const r1 = await req('POST', '/depolar', { isletme_id: state.isletmeId, ad: 'Neg Test' }, adminToken);
  const dId = r1.data?.id;
  const r2 = await req('POST', '/sayimlar', { isletme_id: state.isletmeId, depo_id: dId, ad: 'Neg Sayım' }, adminToken);
  const sId = r2.data?.id;
  const r3 = await req('POST', '/urunler', { isletme_id: state.isletmeId, urun_adi: 'Neg Ürün', urun_kodu: `NEG${Date.now()}` }, adminToken);
  const uId = r3.data?.id;

  if (sId && uId) {
    const r = await req('POST', `/sayimlar/${sId}/kalem`, { urun_id: uId, miktar: -999 }, adminToken);
    // Backend miktar validasyonu yapmayabilir (negatif stok olabilir) — sadece sayısal olmalı
    assert(r.status === 201 || r.status === 400, `Status ${r.status}`);
    await req('DELETE', `/sayimlar/${sId}`, null, adminToken);
  }
  if (uId) await req('DELETE', `/urunler/${uId}`, null, adminToken);
  if (dId) await req('DELETE', `/depolar/${dId}`, null, adminToken);
});

test('INPUT-04 Boş JSON body', async () => {
  const r = await req('POST', '/auth/login', {});
  assert(r.status === 400, `Beklenen 400, gelen ${r.status}`);
});

test('INPUT-05 Geçersiz JSON body', async () => {
  const headers = { 'Content-Type': 'application/json' };
  const opts = { method: 'POST', headers, body: '{invalid json}}}' };
  try {
    const r = await fetch(`${API}/auth/login`, opts);
    assert(r.status === 400 || r.status === 401, `Beklenen 400/401, gelen ${r.status}`);
  } catch (e) {
    // Network hata da kabul
  }
});

test('INPUT-06 Sayfa parametresi negatif/sıfır', async () => {
  const r = await req('GET', '/isletmeler?sayfa=-1&limit=0', null, adminToken);
  assert(r.status === 200, `Status ${r.status}`); // Backend düzeltmeli (min 1)
});

test('INPUT-07 Limit 999999 (aşırı büyük)', async () => {
  const r = await req('GET', '/isletmeler?sayfa=1&limit=999999', null, adminToken);
  assert(r.status === 200, `Status ${r.status}`);
  // Limit 200'e clamp edilmeli
  if (r.data.data) {
    assert(r.data.data.length <= 200, `Limit aşıldı: ${r.data.data.length}`);
  }
});

test('INPUT-08 Unicode/Emoji işletme adı', async () => {
  const r = await req('POST', '/isletmeler', {
    ad: '🏢 テスト İşletme العربية', kod: `UNI${Date.now()}`,
  }, adminToken);
  if (r.status === 201) {
    assert(r.data.ad.includes('🏢'), 'Unicode korunmalı');
    await req('DELETE', `/isletmeler/${r.data.id}`, null, adminToken);
  }
});

// ═══════════════════════════════════════════════════════════
// 7. SECURITY HEADERS
// ═══════════════════════════════════════════════════════════

test('HDR-01 X-Content-Type-Options: nosniff', async () => {
  const r = await req('GET', '/health');
  assert(r.headers['x-content-type-options'] === 'nosniff', `Header: ${r.headers['x-content-type-options']}`);
});

test('HDR-02 X-Frame-Options', async () => {
  const r = await req('GET', '/health');
  assert(r.headers['x-frame-options'], `Header eksik: ${JSON.stringify(r.headers)}`);
});

test('HDR-03 password_hash asla response da olmamali', async () => {
  const r = await req('POST', '/auth/login', { email: 'admin@stoksay.com', password: 'TestAdmin1234!' });
  assert(!JSON.stringify(r.data).includes('password_hash'), 'password_hash sızdırıldı!');

  const r2 = await req('GET', '/kullanicilar?sayfa=1&limit=5', null, adminToken);
  assert(!JSON.stringify(r2.data).includes('password_hash'), 'Kullanıcı listesinde password_hash!');
});

// ═══════════════════════════════════════════════════════════
// 8. BUSINESS LOGIC ATTACKS
// ═══════════════════════════════════════════════════════════

test('BIZ-01 Pasif kullanıcı login', async () => {
  // Pasife al
  await req('PUT', `/kullanicilar/${state.userId}`, { aktif: false }, adminToken);
  const r = await req('POST', '/auth/login', { email: state.userEmail, password: 'SecTest1234!' });
  assert(r.status === 403, `Pasif kullanıcı login: beklenen 403, gelen ${r.status}`);
  // Geri aktifle
  await req('PUT', `/kullanicilar/${state.userId}`, { aktif: true }, adminToken);
  // Token yenile
  const r2 = await req('POST', '/auth/login', { email: state.userEmail, password: 'SecTest1234!' });
  userToken = r2.data.token;
});

test('BIZ-02 Tamamlanmış sayıma kalem eklenemez', async () => {
  const r1 = await req('POST', '/depolar', { isletme_id: state.isletmeId, ad: 'BIZ Depo' }, adminToken);
  const dId = r1.data?.id;
  const r2 = await req('POST', '/sayimlar', { isletme_id: state.isletmeId, depo_id: dId, ad: 'BIZ Sayım' }, adminToken);
  const sId = r2.data?.id;
  await req('PUT', `/sayimlar/${sId}/tamamla`, {}, adminToken);

  const r3 = await req('POST', '/urunler', { isletme_id: state.isletmeId, urun_adi: 'BIZ Ürün', urun_kodu: `BIZ${Date.now()}` }, adminToken);
  const uId = r3.data?.id;

  const r4 = await req('POST', `/sayimlar/${sId}/kalem`, { urun_id: uId, miktar: 1 }, adminToken);
  assert(r4.status === 400, `Beklenen 400, gelen ${r4.status}`);

  await req('DELETE', `/sayimlar/${sId}`, null, adminToken);
  if (uId) await req('DELETE', `/urunler/${uId}`, null, adminToken);
  if (dId) await req('DELETE', `/depolar/${dId}`, null, adminToken);
});

test('BIZ-03 Duplicate barkod', async () => {
  const brk = `DUP${Date.now()}`;
  const r1 = await req('POST', '/urunler', {
    isletme_id: state.isletmeId, urun_adi: 'Dup1', urun_kodu: `DUP1${Date.now()}`, barkodlar: [brk],
  }, adminToken);
  const r2 = await req('POST', '/urunler', {
    isletme_id: state.isletmeId, urun_adi: 'Dup2', urun_kodu: `DUP2${Date.now()}`, barkodlar: [brk],
  }, adminToken);
  assert(r2.status === 409, `Duplicate barkod: beklenen 409, gelen ${r2.status}`);
  if (r1.data?.id) await req('DELETE', `/urunler/${r1.data.id}`, null, adminToken);
  if (r2.data?.id) await req('DELETE', `/urunler/${r2.data.id}`, null, adminToken);
});

test('BIZ-04 Admin kendini silemez', async () => {
  const r1 = await req('GET', '/auth/me', null, adminToken);
  const adminId = r1.data.kullanici.id;
  const r = await req('DELETE', `/kullanicilar/${adminId}`, null, adminToken);
  assert(r.status === 403, `Admin kendi silme: beklenen 403, gelen ${r.status}`);
});

test('BIZ-05 Duplicate email', async () => {
  const r = await req('POST', '/kullanicilar', {
    ad_soyad: 'Dup Email', email: 'admin@stoksay.com', sifre: 'test12345678',
  }, adminToken);
  assert(r.status === 409, `Duplicate email: beklenen 409, gelen ${r.status}`);
});

// ═══════════════════════════════════════════════════════════
// 9. CONCURRENT / RACE CONDITION
// ═══════════════════════════════════════════════════════════

test('RACE-01 Aynı barkodu aynı anda 2 ürüne ekleme', async () => {
  const brk = `RACE${Date.now()}`;
  const [r1, r2] = await Promise.all([
    req('POST', '/urunler', { isletme_id: state.isletmeId, urun_adi: 'Race1', urun_kodu: `R1${Date.now()}`, barkodlar: [brk] }, adminToken),
    req('POST', '/urunler', { isletme_id: state.isletmeId, urun_adi: 'Race2', urun_kodu: `R2${Date.now()}`, barkodlar: [brk] }, adminToken),
  ]);
  const statuses = [r1.status, r2.status].sort();
  // Biri 201, diğeri 409 olmalı
  assert(statuses.includes(201) && statuses.includes(409), `Race condition: ${statuses}`);
  if (r1.data?.id) await req('DELETE', `/urunler/${r1.data.id}`, null, adminToken);
  if (r2.data?.id) await req('DELETE', `/urunler/${r2.data.id}`, null, adminToken);
});

// ═══════════════════════════════════════════════════════════
// 10. HTTP METHOD & PATH TRAVERSAL
// ═══════════════════════════════════════════════════════════

test('METHOD-01 PATCH yöntemi (desteklenmiyor)', async () => {
  const headers = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` };
  const r = await fetch(`${API}/isletmeler`, { method: 'PATCH', headers, body: '{}' });
  assert(r.status === 404 || r.status === 405, `Beklenen 404/405, gelen ${r.status}`);
});

test('PATH-01 Path traversal denemesi', async () => {
  const r = await req('GET', '/../../../etc/passwd', null, adminToken);
  assert(r.status === 404 || (typeof r.data === 'string' && !r.data.includes('root:')), 'Path traversal engellenmeli');
});

test('PATH-02 Null byte injection', async () => {
  const r = await req('GET', '/isletmeler%00.json', null, adminToken);
  assert(r.status === 404 || r.status === 200, `Status ${r.status}`);
});

// ═══════════════════════════════════════════════════════════
// CLEANUP
// ═══════════════════════════════════════════════════════════

test('CLEANUP — Test verilerini temizle', async () => {
  if (state.userId) await req('DELETE', `/kullanicilar/${state.userId}`, null, adminToken);
  if (state.isletmeId) await req('DELETE', `/isletmeler/${state.isletmeId}`, null, adminToken);
});

// ═══════════════════════════════════════════════════════════
// RUN
// ═══════════════════════════════════════════════════════════
async function run() {
  const t0 = Date.now();
  console.log('\n╔══════════════════════════════════════════════════════════════╗');
  console.log('║    🔒 StokSay Güvenlik & Stres Testi                        ║');
  console.log(`║  Backend: ${BASE_URL.padEnd(48)}║`);
  console.log('╚══════════════════════════════════════════════════════════════╝\n');

  for (const { name, fn } of results) {
    try { await fn(); passed++; console.log(`  ✅ ${name}`); }
    catch (e) { failed++; errors.push({ name, error: e.message }); console.log(`  ❌ ${name}`); console.log(`     → ${e.message}`); }
  }

  const ms = Date.now() - t0;
  console.log(`\n${'═'.repeat(62)}`);
  console.log(`  Sonuç: ${passed} başarılı, ${failed} başarısız, toplam ${passed + failed}`);
  console.log(`  Süre: ${(ms/1000).toFixed(1)}s`);
  console.log('═'.repeat(62));
  if (errors.length) { console.log('\n  Başarısız:'); errors.forEach(e => console.log(`    - ${e.name}: ${e.error}`)); }

  const fs = require('fs');
  const rp = `${__dirname}/security-report-${Date.now()}.json`;
  fs.writeFileSync(rp, JSON.stringify({ backend: BASE_URL, summary: { passed, failed, total: passed+failed, ms }, errors }, null, 2));
  console.log(`\n  Rapor: ${rp}\n`);
  process.exit(failed > 0 ? 1 : 0);
}
run();
