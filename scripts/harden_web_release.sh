#!/usr/bin/env bash
set -euo pipefail

build_dir="${1:-build/web}"
bootstrap="$build_dir/flutter_bootstrap.js"

echo "[web-harden] validate web release artifact inputs"
test -d "$build_dir"
test -f "$build_dir/main.dart.wasm"
test -f "$build_dir/main.dart.mjs"
test -f "$bootstrap"

required_files=(
  "$build_dir/flutter_bootstrap.js"
  "$build_dir/main.dart.mjs"
  "$build_dir/flutter_service_worker.js"
  "$build_dir/pwa_install.js"
  "$build_dir/webauthn_quick_unlock.js"
  "$build_dir/nija_browser_bridge.js"
  "$build_dir/canvaskit/skwasm.js"
  "$build_dir/canvaskit/skwasm.wasm"
)
for required_file in "${required_files[@]}"; do
  if [ ! -f "$required_file" ]; then
    echo "ERROR: Required web runtime file is missing: $required_file"
    exit 1
  fi
done

if find "$build_dir" -type f -name '*.map' | rg . >/dev/null; then
  echo "ERROR: Source maps are present in $build_dir."
  exit 1
fi

echo "[web-harden] remove Dart-to-JS fallback bundle"
rm -f "$build_dir/main.dart.js"

if [ -f "web/.htaccess" ]; then
  echo "[web-harden] copy Apache/cPanel hosting rules"
  cp "web/.htaccess" "$build_dir/.htaccess"
fi

echo "[web-harden] keep only dart2wasm build config and add unsupported-browser message"
python3 - "$bootstrap" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

config_match = re.search(
    r"(_flutter\.buildConfig\s*=\s*)(\{.*?\})(;)",
    text,
    flags=re.S,
)
if not config_match:
    raise SystemExit("ERROR: Could not find _flutter.buildConfig in flutter_bootstrap.js.")

config = json.loads(config_match.group(2))
builds = config.get("builds")
if not isinstance(builds, list):
    raise SystemExit("ERROR: Flutter build config has no builds list.")

wasm_builds = [build for build in builds if build.get("compileTarget") == "dart2wasm"]
if not wasm_builds:
    raise SystemExit("ERROR: Flutter build config has no dart2wasm build.")

config["builds"] = wasm_builds
config_json = json.dumps(config, separators=(",", ":"))
text = (
    text[: config_match.start()]
    + config_match.group(1)
    + config_json
    + ";"
    + text[config_match.end() :]
)

if "var nijaFlutterLoad = _flutter.loader.load" not in text:
    loader_match = re.search(r"_flutter\.loader\.load\(\{.*?\n\}\);", text, flags=re.S)
    if not loader_match:
        raise SystemExit("ERROR: Could not find _flutter.loader.load call in flutter_bootstrap.js.")

    loader_call = loader_match.group(0)
    fallback = """(function () {
  function showUnsupportedBrowser(error) {
    console.error("Nija WebAssembly startup failed.", error);
    document.body.innerHTML = '<main style="min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;font-family:system-ui,-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;background:#f4f4f5;color:#18181b;"><section style="max-width:520px;"><h1 style="font-size:24px;line-height:1.2;margin:0 0 12px;">Upgrade your browser to use Nija</h1><p style="font-size:16px;line-height:1.5;margin:0;">This Nija release runs the app core with WebAssembly. Your browser does not support the required WebAssembly features. Update your browser, then reload this page.</p></section></main>';
  }

  try {
    var nijaFlutterLoad = __LOADER_CALL__;
    if (nijaFlutterLoad && typeof nijaFlutterLoad.catch === "function") {
      nijaFlutterLoad.catch(showUnsupportedBrowser);
    }
  } catch (error) {
    showUnsupportedBrowser(error);
  }
})();""".replace("__LOADER_CALL__", loader_call)
    text = text[: loader_match.start()] + fallback + text[loader_match.end() :]

text = text.replace("main.dart.js", "main.dart.unavailable")
text = text.replace("dart2js", "removed-dart-js")

path.write_text(text, encoding="utf-8")
PY

echo "[web-harden] validate hardened web release artifact"
test ! -f "$build_dir/main.dart.js"
test -f "$build_dir/main.dart.wasm"
test -f "$build_dir/main.dart.mjs"

if rg -n "dart2js|main\\.dart\\.js" "$bootstrap" >/dev/null; then
  echo "ERROR: Dart-to-JS fallback still referenced by $bootstrap."
  exit 1
fi

if ! rg -n "Upgrade your browser to use Nija" "$bootstrap" >/dev/null; then
  echo "ERROR: Unsupported-browser message was not added to $bootstrap."
  exit 1
fi

echo "Wasm-only web release hardening passed."
