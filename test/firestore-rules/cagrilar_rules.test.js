// Firestore güvenlik kuralı testleri — çağrı durum makinesi regresyonu.
// Odak: çağrı kapma yarışı (isCagriClaim) + 45 sn zaman aşımı (isCagriTimeout).
// Kurallar kök firestore.rules'tan okunur (tek kaynak).
// (bkz. vault/03-Data/03-Veritabani.md "Çağrı durum makinesi",
//  vault/06-Security/08-Guvenlik.md, vault/02-Backend/02-API-Arka-Uc.md)
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');

const CALLER = 'caller-uid-1';   // çağrıyı açan
const VOL_B = 'volunteer-uid-B'; // ilk üstlenen gönüllü
const VOL_C = 'volunteer-uid-C'; // yarışı kaybeden ikinci gönüllü
const CALL_ID = 'call-1';

let testEnv;

// Her testten önce 'bekliyor' bir çağrı seed'le (kuralları baypas ederek).
async function seedBekliyorCall() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'cagrilar', CALL_ID), {
      callId: CALL_ID,
      kanal_adi: CALL_ID,
      cagri_durumu: 'bekliyor',
      zaman: new Date(),
      caller_name: 'Test Arayan',
      caller_uid: CALLER,
    });
  });
}

function callRef(ctx) {
  return doc(ctx.firestore(), 'cagrilar', CALL_ID);
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-asikar',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seedBekliyorCall();
});

describe('isCagriClaim — çağrı kapma yarışı', () => {
  it('KABUL: gönüllü bekliyor→cevaplandi + volunteer_uid=self', async () => {
    const ctx = testEnv.authenticatedContext(VOL_B);
    await assertSucceeds(updateDoc(callRef(ctx), {
      cagri_durumu: 'cevaplandi', volunteer_uid: VOL_B,
    }));
  });

  it('RED: ikinci gönüllü zaten cevaplandi olan çağrıyı kapamaz (yarış kilidi)', async () => {
    const ctxB = testEnv.authenticatedContext(VOL_B);
    await assertSucceeds(updateDoc(callRef(ctxB), {
      cagri_durumu: 'cevaplandi', volunteer_uid: VOL_B,
    }));
    const ctxC = testEnv.authenticatedContext(VOL_C);
    await assertFails(updateDoc(callRef(ctxC), {
      cagri_durumu: 'cevaplandi', volunteer_uid: VOL_C,
    }));
  });

  it('RED: arayan kendi çağrısını üstlenemez', async () => {
    const ctx = testEnv.authenticatedContext(CALLER);
    await assertFails(updateDoc(callRef(ctx), {
      cagri_durumu: 'cevaplandi', volunteer_uid: CALLER,
    }));
  });

  it('RED: volunteer_uid != auth.uid (başkası adına üstlenme)', async () => {
    const ctx = testEnv.authenticatedContext(VOL_B);
    await assertFails(updateDoc(callRef(ctx), {
      cagri_durumu: 'cevaplandi', volunteer_uid: VOL_C,
    }));
  });

  it('RED: izinli alanlar dışında değişiklik (caller_name) → hasOnly ihlali', async () => {
    const ctx = testEnv.authenticatedContext(VOL_B);
    await assertFails(updateDoc(callRef(ctx), {
      cagri_durumu: 'cevaplandi', volunteer_uid: VOL_B, caller_name: 'Hacklendi',
    }));
  });
});

describe('isCagriTimeout — 45 sn zaman aşımı', () => {
  it('KABUL: arayan bekliyor→zaman_asimi', async () => {
    const ctx = testEnv.authenticatedContext(CALLER);
    await assertSucceeds(updateDoc(callRef(ctx), { cagri_durumu: 'zaman_asimi' }));
  });

  it('RED: arayan olmayan (gönüllü) zaman aşımı tetikleyemez', async () => {
    const ctx = testEnv.authenticatedContext(VOL_B);
    await assertFails(updateDoc(callRef(ctx), { cagri_durumu: 'zaman_asimi' }));
  });

  it('RED: cevaplandi→zaman_asimi (önkoşul bekliyor değil)', async () => {
    const ctxB = testEnv.authenticatedContext(VOL_B);
    await updateDoc(callRef(ctxB), { cagri_durumu: 'cevaplandi', volunteer_uid: VOL_B });
    const ctxCaller = testEnv.authenticatedContext(CALLER);
    await assertFails(updateDoc(callRef(ctxCaller), { cagri_durumu: 'zaman_asimi' }));
  });
});

describe('isValidNewCagri — çağrı tipi + şehir yönlendirme', () => {
  const NEW_ID = 'call-new';
  function newCallRef(ctx) {
    return doc(ctx.firestore(), 'cagrilar', NEW_ID);
  }
  const base = (extra) => ({
    callId: NEW_ID,
    kanal_adi: NEW_ID,
    cagri_durumu: 'bekliyor',
    zaman: new Date(),
    caller_name: 'Test Arayan',
    caller_uid: CALLER,
    ...extra,
  });

  it('KABUL: uzaktan çağrı (sehir yok)', async () => {
    const ctx = testEnv.authenticatedContext(CALLER);
    await assertSucceeds(setDoc(newCallRef(ctx), base({ cagri_tipi: 'uzaktan' })));
  });

  it('KABUL: fiziksel çağrı + geçerli sehir slug', async () => {
    const ctx = testEnv.authenticatedContext(CALLER);
    await assertSucceeds(setDoc(newCallRef(ctx), base({ cagri_tipi: 'fiziksel', sehir: 'sakarya' })));
  });

  it('KABUL: cagri_tipi/sehir olmadan (geriye dönük uyum)', async () => {
    const ctx = testEnv.authenticatedContext(CALLER);
    await assertSucceeds(setDoc(newCallRef(ctx), base({})));
  });

  it('RED: geçersiz cagri_tipi', async () => {
    const ctx = testEnv.authenticatedContext(CALLER);
    await assertFails(setDoc(newCallRef(ctx), base({ cagri_tipi: 'acil' })));
  });

  it('RED: geçersiz sehir slug (büyük harf/boşluk)', async () => {
    const ctx = testEnv.authenticatedContext(CALLER);
    await assertFails(setDoc(newCallRef(ctx), base({ cagri_tipi: 'fiziksel', sehir: 'Sakarya İli' })));
  });
});

describe('guards — geri dönüş ve silme', () => {
  it('RED: delete her zaman reddedilir', async () => {
    const ctx = testEnv.authenticatedContext(CALLER);
    await assertFails(deleteDoc(callRef(ctx)));
  });

  it('RED: geri geçiş cevaplandi→bekliyor', async () => {
    const ctxB = testEnv.authenticatedContext(VOL_B);
    await updateDoc(callRef(ctxB), { cagri_durumu: 'cevaplandi', volunteer_uid: VOL_B });
    await assertFails(updateDoc(callRef(ctxB), { cagri_durumu: 'bekliyor', volunteer_uid: VOL_B }));
  });
});
