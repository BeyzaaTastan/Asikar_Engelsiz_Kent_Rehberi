import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/utils/city_slug.dart';

// Kritik akış koruması: fiziksel çağrının şehir bazlı FCM topic'i.
// İstemcinin iki tarafı (arayan + gönüllü aboneliği) AYNI slug'ı üretmeli;
// aksi halde aynı şehirdekiler farklı topic'lere düşer ve çağrı ulaşmaz.
// (bkz. vault/07-Performance/11-Olcekleme.md, vault/02-Backend/02-API-Arka-Uc.md)
void main() {
  group('citySlug', () {
    test('sade ASCII il adını küçük harfe indirir', () {
      expect(citySlug('Sakarya'), 'sakarya');
    });

    test('Türkçe karakterleri ASCII\'ye foldlar', () {
      expect(citySlug('İstanbul'), 'istanbul');
      expect(citySlug('Şanlıurfa'), 'sanliurfa');
      expect(citySlug('Kahramanmaraş'), 'kahramanmaras');
      expect(citySlug('Çanakkale'), 'canakkale');
      expect(citySlug('Muğla'), 'mugla');
      expect(citySlug('Nevşehir'), 'nevsehir');
    });

    test('boşluk ve harf/rakam dışı karakterleri atar', () {
      expect(citySlug('Afyon Karahisar'), 'afyonkarahisar');
      expect(citySlug('  Sakarya  '), 'sakarya');
      expect(citySlug('Sakarya İli'), 'sakaryaili');
    });

    test('null / boş / yalnızca boşluk → null', () {
      expect(citySlug(null), isNull);
      expect(citySlug(''), isNull);
      expect(citySlug('   '), isNull);
    });

    test('yalnızca sembollerden oluşan girdi → null', () {
      expect(citySlug('- . /'), isNull);
    });

    test('üretilen slug yalnızca [a-z0-9] içerir (FCM topic-güvenli)', () {
      final slug = citySlug('İzmir-3 . Bölge')!;
      expect(RegExp(r'^[a-z0-9]+$').hasMatch(slug), isTrue);
    });
  });
}
