class UserModel {
  // Kullanıcının kayıt olduktan sonra Firebase tarafından atanan şifreli ve benzersiz kimlik numarası.
  final String uid;

  // Kullanıcının ad ve soyadını tutar. Firebase Authentication'daki displayName'den alınır.
  final String? fullName;

  // Kullanıcının e-posta adresi. Firebase Authentication'daki email'den alınır.
  final String? email;

  // Kullanıcının rolünü belirtir ("Turist", "Sakin", veya "Özel Gereksinimli" gibi).
  final String userType;

  // Eğer kullanıcı 'Turist' ise, ne tarz yerler (doğa, tarihi vb.) görmek istediğini tutan liste.
  final List<String>? touristInterests;

  // Şehir sakinleri için gönüllü olup olmadığını (evet/hayır) belirten değişken.
  final bool? isVolunteer;

  // Gönüllü olan kullanıcının hangi konularda yardım edebileceğini (Örn: işaret dili) tutan liste.
  final List<String>? volunteerSkills;

  // Özel gereksinimli bireyler için uygulamanın erişilebilirlik beklentilerini (Görme Desteği vb.) tutan liste.
  final List<String>? accessibilityPrefs;

  // Kurucu Metot (Constructor): Uygulamada yeni bir kullanıcı objesi oluşturulduğunda çalışır.
  // 'uid' ve 'userType' özellikleri zorunludur ('required'), diğerleri isteğe bağlıdır.
  UserModel({
    required this.uid,
    this.fullName,
    this.email,
    required this.userType,
    this.touristInterests,
    this.isVolunteer,
    this.volunteerSkills,
    this.accessibilityPrefs,
  });

  // copyWith: Mevcut objenin bir kopyasını oluşturur; sadece belirtilen alanları değiştirir.
  // Bu metot sayesinde database_service.dart içinde geçici UID'yi gerçek Firebase UID'si ile
  // değiştirip, ayrıca fullName ve email bilgilerini de ekleyebiliyoruz.
  // Örnek: user.copyWith(uid: gercekUid, fullName: "Ali Yılmaz", email: "ali@mail.com")
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? userType,
    List<String>? touristInterests,
    bool? isVolunteer,
    List<String>? volunteerSkills,
    List<String>? accessibilityPrefs,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      touristInterests: touristInterests ?? this.touristInterests,
      isVolunteer: isVolunteer ?? this.isVolunteer,
      volunteerSkills: volunteerSkills ?? this.volunteerSkills,
      accessibilityPrefs: accessibilityPrefs ?? this.accessibilityPrefs,
    );
  }

  // toJson: Uygulama içindeki Dart objesini, Firebase (Firestore) veritabanına
  // kaydedilebilmesi için Map (JSON benzeri sözlük) formatına çevirir (Paketleme işlemi).
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'userType': userType,
      'touristInterests': touristInterests,
      'isVolunteer': isVolunteer ?? false,
      'volunteerSkills': volunteerSkills,
      'accessibilityPrefs': accessibilityPrefs,
    };
  }

  // fromJson: Firestore'dan (veritabanından) gelen Map tipindeki veriyi (JSON) okuyup,
  // uygulama içinde kullanılabilecek 'UserModel' objesine geri çevirir (Paketten çıkarma işlemi).
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      fullName: json['fullName'],
      email: json['email'],
      userType: json['userType'] ?? 'Sakin',

      // Veritabanından gelen verinin boş (null) olup olmadığı kontrol ediliyor,
      // Eğer doluysa Dart Listesine (List<String>) dönüştürülüyor.
      touristInterests: json['touristInterests'] != null
          ? List<String>.from(json['touristInterests'])
          : null,

      isVolunteer: json['isVolunteer'] ?? false,

      volunteerSkills: json['volunteerSkills'] != null
          ? List<String>.from(json['volunteerSkills'])
          : null,

      accessibilityPrefs: json['accessibilityPrefs'] != null
          ? List<String>.from(json['accessibilityPrefs'])
          : null,
    );
  }
}
