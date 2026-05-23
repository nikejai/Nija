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

echo "Release hardening gate passed."

