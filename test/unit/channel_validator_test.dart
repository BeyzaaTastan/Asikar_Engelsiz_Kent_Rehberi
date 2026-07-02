import 'package:flutter_test/flutter_test.dart';
import 'package:asikar_engelsiz_kent_rehberi/utils/channel_validator.dart';

// Kritik akış koruması: Agora kanal adı doğrulaması.
// Eşzamanlı çağrılarda paylaşılan sabit fallback'i ('yardim_kanali') önler;
// kanal geçersizse çağrı kurulmaz. (bkz. vault/02-Backend/02-API-Arka-Uc.md
// "Kanal güvencesi", vault/01-Frontend/01-On-Yuz.md "validChannelName")
void main() {
  group('validChannelName', () {
    test('geçerli UUID kanal adını aynen döndürür', () {
      const id = '0c57d195-a892-45c6-844a-3ab86b4b6027';
      expect(validChannelName(id), id);
    });

    test('baştaki/sondaki boşlukları temizler', () {
      expect(validChannelName('  kanal-1  '), 'kanal-1');
    });

    test('null girişte null döner', () {
      expect(validChannelName(null), isNull);
    });

    test('boş string null döner', () {
      expect(validChannelName(''), isNull);
    });

    test('yalnızca boşluktan oluşan string null döner', () {
      expect(validChannelName('    '), isNull);
    });

    test('String olmayan giriş (int) null döner', () {
      expect(validChannelName(42), isNull);
    });

    test('String olmayan giriş (Map) null döner', () {
      expect(validChannelName(<String, dynamic>{'x': 1}), isNull);
    });
  });
}
