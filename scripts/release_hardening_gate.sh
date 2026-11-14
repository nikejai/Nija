#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release_hardening_gate.sh [--web-flavor=wasm-only|compat-js] [--web-build-dir=build/web] [--skip-flutter-checks]

Defaults:
  --web-flavor=wasm-only
  --web-build-dir=build/web
EOF
}

web_flavor="wasm-only"
web_build_dir="build/web"
skip_flutter_checks=false
for arg in "$@"; do
  case "$arg" in
    --web-flavor=*)
      web_flavor="${arg#*=}"
      ;;
    --web-build-dir=*)
      web_build_dir="${arg#*=}"
      ;;
    --skip-flutter-checks)
      skip_flutter_checks=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $arg"
      exit 64
      ;;
  esac
done

if [ "$web_flavor" != "wasm-only" ] && [ "$web_flavor" != "compat-js" ]; then
  echo "ERROR: Unsupported web flavor: $web_flavor"
  exit 64
fi

if [ "$skip_flutter_checks" = false ]; then
  echo "[gate] flutter analyze"
  flutter analyze

  echo "[gate] flutter test"
  flutter test
else
  echo "[gate] skip flutter analyze/test"
fi

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
if [ -d "$web_build_dir" ]; then
  test -f "$web_build_dir/main.dart.wasm"
  test -f "$web_build_dir/main.dart.mjs"
  test -f "$web_build_dir/flutter_bootstrap.js"
  test -f "$web_build_dir/flutter_service_worker.js"
  test -f "$web_build_dir/pwa_install.js"
  test -f "$web_build_dir/webauthn_quick_unlock.js"
  test -f "$web_build_dir/nija_browser_bridge.js"
  test -f "$web_build_dir/canvaskit/skwasm.js"
  test -f "$web_build_dir/canvaskit/skwasm.wasm"
  if [ "$web_flavor" = "wasm-only" ]; then
    if [ -f "$web_build_dir/main.dart.js" ]; then
      echo "ERROR: $web_build_dir/main.dart.js is present. Run ./scripts/harden_web_release.sh after the wasm web build."
      exit 1
    fi
    if rg -n "dart2js|main\\.dart\\.js" "$web_build_dir/flutter_bootstrap.js" >/dev/null; then
      echo "ERROR: $web_build_dir/flutter_bootstrap.js still references the Dart-to-JS fallback."
      exit 1
    fi
    if ! rg -n "Upgrade your browser to use Nija" "$web_build_dir/flutter_bootstrap.js" >/dev/null; then
      echo "ERROR: $web_build_dir/flutter_bootstrap.js does not include the unsupported-browser message."
      exit 1
    fi
  else
    test -f "$web_build_dir/main.dart.js"
    test -f "$web_build_dir/nija_integrity_manifest.json"
    test -f "$web_build_dir/nija_integrity_manifest.sig"
    dart tool/web_integrity.dart verify \
      --build-dir "$web_build_dir" \
      --flavor compat-js \
      --require-runtime-markers
  fi
  if find "$web_build_dir" -type f -name '*.map' | rg . >/dev/null; then
    echo "ERROR: $web_build_dir contains source maps."
    exit 1
  fi
  if find "$web_build_dir" -type f ! -perm -004 | rg . >/dev/null; then
    echo "ERROR: $web_build_dir contains files that are not world-readable for static hosting."
    exit 1
  fi
  if find "$web_build_dir" -type d ! -perm -005 | rg . >/dev/null; then
    echo "ERROR: $web_build_dir contains directories that are not world-readable/executable for static hosting."
    exit 1
  fi
fi

echo "Release hardening gate passed."
