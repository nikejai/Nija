#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/browser_agent_integration_test.sh [--all] [--target=integration_test/app_smoke_test.dart] [--port=4444] [--chromedriver=/path/to/chromedriver]

Runs Flutter integration tests in Chrome through ChromeDriver.

Defaults:
  Runs app_smoke_test, onboarding_regressions_test, and e2e_full_flow_test.
  Uses port 4444.
  Uses CHROMEDRIVER, PATH chromedriver, or the vendored macOS ARM chromedriver.

Examples:
  ./scripts/browser_agent_integration_test.sh
  ./scripts/browser_agent_integration_test.sh --all
  ./scripts/browser_agent_integration_test.sh --target=integration_test/app_smoke_test.dart
EOF
}

port="4444"
chromedriver_path="${CHROMEDRIVER:-}"
run_all=false
targets=()

for arg in "$@"; do
  case "$arg" in
    --all)
      run_all=true
      ;;
    --target=*)
      targets+=("${arg#*=}")
      ;;
    --port=*)
      port="${arg#*=}"
      ;;
    --chromedriver=*)
      chromedriver_path="${arg#*=}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $arg" >&2
      exit 64
      ;;
  esac
done

if [ "$run_all" = true ] && [ "${#targets[@]}" -gt 0 ]; then
  echo "ERROR: Use either --all or --target, not both." >&2
  exit 64
fi

if [ "$run_all" = true ]; then
  while IFS= read -r target; do
    targets+=("$target")
  done < <(find integration_test -maxdepth 1 -name '*_test.dart' | sort)
fi

if [ "${#targets[@]}" -eq 0 ]; then
  targets=(
    "integration_test/app_smoke_test.dart"
    "integration_test/onboarding_regressions_test.dart"
    "integration_test/e2e_full_flow_test.dart"
  )
fi

if [ -z "$chromedriver_path" ]; then
  if command -v chromedriver >/dev/null 2>&1; then
    chromedriver_path="$(command -v chromedriver)"
  else
    chromedriver_path="chromedriver/mac_arm-148.0.7778.97/chromedriver-mac-arm64/chromedriver"
  fi
fi

if [ ! -x "$chromedriver_path" ]; then
  echo "ERROR: ChromeDriver is not executable: $chromedriver_path" >&2
  exit 1
fi

chrome_binary="${CHROME_EXECUTABLE:-}"
if [ -z "$chrome_binary" ]; then
  if command -v google-chrome >/dev/null 2>&1; then
    chrome_binary="$(command -v google-chrome)"
  elif command -v google-chrome-stable >/dev/null 2>&1; then
    chrome_binary="$(command -v google-chrome-stable)"
  elif command -v chromium >/dev/null 2>&1; then
    chrome_binary="$(command -v chromium)"
  elif [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    chrome_binary="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  fi
fi

version_major() {
  awk '{
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^[0-9]+\./) {
        split($i, version, ".")
        print version[1]
        exit
      }
    }
  }'
}

if [ -n "$chrome_binary" ] && [ -x "$chrome_binary" ]; then
  chrome_version="$("$chrome_binary" --version 2>/dev/null || true)"
  driver_version="$("$chromedriver_path" --version 2>/dev/null || true)"
  chrome_major="$(printf '%s\n' "$chrome_version" | version_major)"
  driver_major="$(printf '%s\n' "$driver_version" | version_major)"
  if [ -n "$chrome_major" ] && [ -n "$driver_major" ] && [ "$chrome_major" != "$driver_major" ]; then
    echo "ERROR: ChromeDriver major version does not match Chrome." >&2
    echo "Chrome:       $chrome_version" >&2
    echo "ChromeDriver: $driver_version" >&2
    echo "Fix: update Chrome, or pass --chromedriver=/path/to/a ChromeDriver $chrome_major binary." >&2
    exit 1
  fi
fi

driver_started=false
driver_pid=""

cleanup() {
  if [ "$driver_started" = true ] && [ -n "$driver_pid" ]; then
    kill "$driver_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if curl -fsS "http://127.0.0.1:$port/status" >/dev/null 2>&1; then
  echo "[browser-agent] using existing ChromeDriver on port $port"
else
  echo "[browser-agent] starting ChromeDriver on port $port"
  "$chromedriver_path" --port="$port" >/tmp/nija_chromedriver_"$port".log 2>&1 &
  driver_pid="$!"
  driver_started=true
  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$port/status" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  if ! curl -fsS "http://127.0.0.1:$port/status" >/dev/null 2>&1; then
    echo "ERROR: ChromeDriver did not start on port $port." >&2
    echo "See /tmp/nija_chromedriver_$port.log" >&2
    exit 1
  fi
fi

for target in "${targets[@]}"; do
  if [ ! -f "$target" ]; then
    echo "ERROR: Integration target not found: $target" >&2
    exit 1
  fi
  echo "[browser-agent] flutter drive $target"
  flutter drive \
    -d chrome \
    --driver=test_driver/integration_test.dart \
    --target="$target"
done

echo "[browser-agent] all browser integration targets passed"
