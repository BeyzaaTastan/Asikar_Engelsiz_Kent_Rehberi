import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Giriş yapan kullanıcının gerçek bilgilerini almak için
import 'package:flutter/foundation.dart'; // debugPrint için
import '../models/user_model.dart'; // Bir önceki adımda yazdığımız model

class DatabaseService {
  // Firestore veritabanı bağlantımızı başlatıyoruz (_db üzerinden buluta ulaşacağız)
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Kullanıcı anketini veritabanına kaydetme fonksiyonu.
  // İşlem internet üzerinden yapıldığı için Future ve async kullanılır.
  //
  // MİMARİ AÇIKLAMA:
  // Firebase'de iki ayrı "ev" (veritabanı) vardır:
  //   1. Authentication (Kimlik Doğrulama) → E-posta, şifre ve isim burada tutulur.
  //   2. Firestore (Veri Deposu) → Anket sonuçları, ilgi alanları, rotalar burada tutulur.
  //
  // Bu fonksiyon, Authentication tarafındaki gerçek kullanıcı bilgilerini (UID, İsim, E-posta)
  // alıp Firestore'a yazarak bu iki evi birbirine bağlar. Böylece Firestore'daki kayıtlar
  // gerçek kullanıcıya ait olur, geçici/sahte bir ID ile değil.
  Future<void> saveUserSurvey(UserModel user) async {
    try {
      // 1. O an uygulamaya giriş yapmış GERÇEK kullanıcıyı Firebase Authentication'dan al
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // 2. Kullanıcı giriş yapmışsa: Geçici bilgileri iptal edip gerçek bilgileri yükle
        //    copyWith ile mevcut anket verisinin (ilgi alanları, tercihler vb.) üzerine
        //    Authentication'dan gelen gerçek kimlik bilgilerini ekliyoruz.
        final updatedUser = user.copyWith(
          uid: currentUser.uid, // Geçici "gecici_kullanici_id_123" yerine gerçek UID
          email: currentUser.email, // Authentication'daki e-posta
          fullName: currentUser.displayName ?? 'İsimsiz Kullanıcı', // İsim varsa al, yoksa varsayılan ata
        );

        // 3. Güncellenen (gerçek) kullanıcı verisini Firestore'a kaydet
        //    doc(currentUser.uid) → Her kullanıcıya özel, benzersiz bir belge (document) oluşturur
        await _db.collection('users').doc(currentUser.uid).set(updatedUser.toJson());

        debugPrint("Başarılı: Gerçek kullanıcı (${currentUser.email}) verisi kaydedildi!");
      } else {
        // 4. Eğer kullanıcı henüz giriş yapmadan formu doldurursa (edge case),
        //    eski yöntemle geçici ID üzerinden kaydet. Bu durum normalde oluşmamalı,
        //    çünkü kullanıcı Login/Register ekranlarından geçmeden ankete ulaşamaz.
        await _db.collection('users').doc(user.uid).set(user.toJson());

        debugPrint("Uyarı: Giriş yapılmamış, geçici ID ile kaydedildi.");
      }
    } catch (e) {
      debugPrint("Veritabanı kayıt hatası: $e");
      throw Exception("Beklenmeyen bir hata oluştu.");
    }
  }
}
