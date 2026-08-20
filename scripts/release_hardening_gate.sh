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

echo "Release hardening gate passed."
