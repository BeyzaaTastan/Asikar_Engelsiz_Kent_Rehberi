import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kayıt anketinde (accessibility_prefs_screen) seçilen **görme desteği**
/// tercihinin tam değeri. `accessibilityPrefs` listesinde bu string varsa
/// kullanıcı görme desteğine ihtiyaç duyuyordur.
const String kVisualSupportPref = 'Görme Desteği';

/// Mevcut kullanıcının **görme desteğine** ihtiyacı var mı? (`users/{uid}`
/// belgesindeki `accessibilityPrefs` içinde [kVisualSupportPref]).
///
/// Yalnızca görme engelli kullanıcıya yönelik davranışları koşullamak için
/// kullanılır (örn. sesli arama panelinde TTS yönergesini yalnız onlara okumak —
/// bkz. `lib/screens/map/voice_search_sheet.dart`). Giriş yoksa / veri yoksa /
/// tercih seçili değilse `false`.
final visualSupportProvider = StreamProvider<bool>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
    final prefs = doc.data()?['accessibilityPrefs'];
    return prefs is List && prefs.contains(kVisualSupportPref);
  });
});
