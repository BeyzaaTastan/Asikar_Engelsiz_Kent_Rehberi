#!/usr/bin/env bash
# Firestore güvenlik kuralı testlerini emulator içinde tek komutla çalıştırır.
# Odak: çağrı kapma yarışı (isCagriClaim) + zaman aşımı (isCagriTimeout) regresyonu.
# (bkz. vault/05-Infrastructure/07-CI-CD.md "Test Kapsamı")
#
# Kullanım:  bash tool/run_rules_tests.sh
# Ön koşul:  Firestore emulator JDK gerektirir. java PATH'te değilse, Android
#            Studio'nun gömülü JBR'ı (JAVA_HOME) otomatik kullanılır.
set -euo pipefail

# Proje kökü (bu script tool/ altında)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# JDK: java yoksa Android Studio JBR'ı dene
if ! command -v java >/dev/null 2>&1; then
  CANDIDATE="${JAVA_HOME:-/c/Program Files/Android/Android Studio/jbr}"
  if [ -x "$CANDIDATE/bin/java.exe" ] || [ -x "$CANDIDATE/bin/java" ]; then
    export JAVA_HOME="$CANDIDATE"
    export PATH="$JAVA_HOME/bin:$PATH"
  else
    echo "HATA: java bulunamadı ve Android Studio JBR yok. JAVA_HOME ayarlayın." >&2
    exit 1
  fi
fi

# Runner bağımlılıkları kurulu değilse kur
if [ ! -d "test/firestore-rules/node_modules" ]; then
  echo "Runner bağımlılıkları kuruluyor..."
  npm --prefix test/firestore-rules install
fi

# Emulator'ü başlat, testleri koş, kapat (demo proje → kimlik gerekmez)
exec npx firebase-tools emulators:exec --only firestore --project demo-asikar \
  "npm --prefix test/firestore-rules test"
