#!/usr/bin/env bash
set -euo pipefail

echo "[gate] flutter analyze"
flutter analyze

echo "[gate] flutter test"
flutter test

echo "[gate] ensure production crypto adapter is wired"
if rg -n "PrototypeCryptoAdapter" lib/app lib/features/onboarding >/dev/null; then
  echo "ERROR: PrototypeCryptoAdapter referenced in production app wiring."
  exit 1
fi

echo "[gate] ensure debug banner disabled"
if ! rg -n "debugShowCheckedModeBanner:\\s*false" lib/app/app.dart >/dev/null; then
  echo "ERROR: debugShowCheckedModeBanner is not disabled in app.dart."
  exit 1
fi

echo "[gate] ensure release hardening checklist exists"
test -f docs/release_hardening_gates.md

echo "[gate] ensure web security headers are configured"
test -f web/_headers
test -f firebase.json
if ! rg -n "Content-Security-Policy" web/index.html web/_headers firebase.json >/dev/null; then
  echo "ERROR: Web Content-Security-Policy is not configured."
  exit 1
fi
if ! rg -n "Strict-Transport-Security" web/_headers firebase.json >/dev/null; then
  echo "ERROR: Web Strict-Transport-Security header is not configured."
  exit 1
fi
if ! rg -n "Permissions-Policy" web/_headers firebase.json >/dev/null; then
  echo "ERROR: Web Permissions-Policy header is not configured."
  exit 1
fi

echo "[gate] validate hardened web release artifact when present"
if [ -d build/web ]; then
  test -f build/web/main.dart.wasm
  test -f build/web/main.dart.mjs
  test -f build/web/flutter_bootstrap.js
  test -f build/web/flutter_service_worker.js
  test -f build/web/pwa_install.js
  test -f build/web/webauthn_quick_unlock.js
  test -f build/web/nija_browser_bridge.js
  test -f build/web/canvaskit/skwasm.js
  test -f build/web/canvaskit/skwasm.wasm
  if [ -f build/web/main.dart.js ]; then
    echo "ERROR: build/web/main.dart.js is present. Run ./scripts/harden_web_release.sh after the wasm web build."
    exit 1
  fi
  if rg -n "dart2js|main\\.dart\\.js" build/web/flutter_bootstrap.js >/dev/null; then
    echo "ERROR: build/web/flutter_bootstrap.js still references the Dart-to-JS fallback."
    exit 1
  fi
  if ! rg -n "Upgrade your browser to use Nija" build/web/flutter_bootstrap.js >/dev/null; then
    echo "ERROR: build/web/flutter_bootstrap.js does not include the unsupported-browser message."
    exit 1
  fi
  if find build/web -type f -name '*.map' | rg . >/dev/null; then
    echo "ERROR: build/web contains source maps."
    exit 1
  fi
fi

echo "Release hardening gate passed."
