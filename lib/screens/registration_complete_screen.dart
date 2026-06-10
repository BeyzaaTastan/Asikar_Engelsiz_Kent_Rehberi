import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../main_wrapper.dart'; // Ana sayfa yönlendirmesi için

/// Kayıt işlemlerinin tamamlandığını belirten "Tebrikler" / "Başarılı" ekranı.
class RegistrationCompleteScreen extends StatelessWidget {
  // MİMARİ EKLEME: Sayfa açılırken kullanıcının gönüllü olup olmadığını soruyoruz
  final bool isVolunteer;

  const RegistrationCompleteScreen({
    super.key,
    required this.isVolunteer, // Bu parametre artık zorunlu
  });

  @override
  Widget build(BuildContext context) {
    // Tasarıma uygun renk tanımlamaları
    const Color checkBgColor = Color(0xFF1A4F00);

    // KULLANICI TİPİNE GÖRE DİNAMİK METİN BELİRLEME
    final String dynamicText = isVolunteer
        ? 'Sayende engeller kalkıyor,\ndayanışmanın gücü şimdi Aşikar.'
        : 'Sana en uygun yollar\nşimdi aşikar.';

    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      // Şeffaf, yükseltisiz (gölgelik yok) bir AppBar, sağ üstte kapatma butonu
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading:
            false, // Sol taraftaki varsayılan "Geri Git" butonunu gizler
        title: Text(
          'Aşikar',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: AppColors.primary),
            onPressed: () {
              // Uygulamayı kapatma ya da ana sayfaya geçme işlemi
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MainWrapper()),
                (route) => false,
              );            },
            tooltip: 'Kapat',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Üst Kısım: Amblem, Başlık ve Tebrik Metni (Ekran ortasına hizalanır)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logolu ve Başarılı Rozetli (Check işaretli) Dairesel Alan
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // En dıştaki gölgeli beyaz daire
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  // Linter uyarılarına karşı withOpacity yerine withValues kullanıldı
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.06),
                                    blurRadius: 40,
                                    spreadRadius: 12,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                            ),
                            // Logoyu saracak olan çizgili çember tabanı
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                            // Uygulamanın Logosu
                            // NOT: Projenizde asikar_logo.png olmadığı için en uygun mevcut olan asikar_yazisiz_logo.png ile değiştirildi.
                            Semantics(
                              label: "Aşikar Engelsiz Kent Rehberi Logosu",
                              child: Image.asset(
                                'assets/images/asikar_yazisiz_logo.png',
                                width: 160,
                                height: 160,
                                fit: BoxFit.contain,
                              ),
                            ),
                            // Sağ üst köşedeki yeşil onay(check) rozeti
                            Positioned(
                              top: 20,
                              right: 20,
                              child: Semantics(
                                label: "Kayıt Başarılı Rozeti",
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: checkBgColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFFADF688),
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Sayfa Ana Başlığı
                      Semantics(
                        header: true,
                        child: Text(
                          "Aşikar'a Hoş Geldiniz",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // DİNAMİK METNİN GÖSTERİLDİĞİ YER
                      // Sabit "Kaydın tamamlandı!" mesajı ile yukarıda oluşturduğumuz dinamik mesaj burada birleşiyor
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade800,
                            height: 1.5,
                            fontFamily: 'Roboto',
                          ),
                          children: [
                            const TextSpan(
                              text: 'Kaydın tamamlandı!\n',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text:
                                  dynamicText, // isVolunteer değişkenine göre belirlenen metin
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Alt Kısım: Uygulamayı Başlatma Butonu ve Yardım Metni
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ana Başla Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      onPressed: () {
                        // Anket verileri önceki ekranlarda kaydedildiği için yalnızca yönlendirme yapıyoruz
                        debugPrint(
                          "Uygulama Başlıyor! Ana Sayfaya geçiliyor...",
                        );
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MainWrapper(),
                          ),
                          (route) => false,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Başla',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Yardım / Destek Bağlantısı Metni
                  Text.rich(
                    TextSpan(
                      text: 'Yardıma mı ihtiyacınız var? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: 'Destek Merkezini\nZiyaret Edin',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
