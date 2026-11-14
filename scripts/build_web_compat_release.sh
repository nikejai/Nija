#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/build_web_compat_release.sh [--key-dir .release/web_integrity/<name>] [--zip-path .release/web/<name>/web.zip] [--no-zip]

Creates a new web integrity keypair in a timestamped local folder, builds the
JS-compatible Flutter web release with the public key, hardens/signs the
artifact with the private key, runs the compat-js release gate, then writes a
validated upload archive.

The key folder is ignored by git through .release/.
EOF
}

key_dir=""
zip_path=""
create_zip=true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --key-dir)
      key_dir="${2:-}"
      shift 2
      ;;
    --zip-path)
      zip_path="${2:-}"
      shift 2
      ;;
    --no-zip)
      create_zip=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1"
      usage
      exit 64
      ;;
  esac
done

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
key_dir="${key_dir:-.release/web_integrity/$timestamp}"
zip_path="${zip_path:-.release/web/$timestamp/web.zip}"
build_id="nija-web-compat-$timestamp"

echo "[web-compat-release] create web integrity keypair: $key_dir"
(
  umask 077
  dart tool/web_integrity.dart create-key --output-dir "$key_dir"
)
chmod 600 "$key_dir/private_seed.b64" "$key_dir/public_key.b64"
echo "[web-compat-release] key permissions restricted"

private_key="$(tr -d '\n\r' < "$key_dir/private_seed.b64")"
public_key="$(tr -d '\n\r' < "$key_dir/public_key.b64")"
echo "[web-compat-release] loaded public key for dart-define"
echo "[web-compat-release] build id: $build_id"
echo "[web-compat-release] private seed will be used only for manifest signing"

echo "[web-compat-release] flutter build web compat-js"
flutter build web --release --wasm -O4 --no-source-maps --csp \
  --dart-define=NIJA_WEB_INTEGRITY_ENABLED=true \
  --dart-define=NIJA_WEB_INTEGRITY_PUBLIC_KEY_B64="$public_key" \
  --dart-define=NIJA_WEB_INTEGRITY_BUILD_ID="$build_id"
echo "[web-compat-release] flutter build completed: build/web"

echo "[web-compat-release] harden and sign compat-js artifact"
NIJA_WEB_INTEGRITY_PRIVATE_KEY_B64="$private_key" \
NIJA_WEB_INTEGRITY_BUILD_ID="$build_id" \
  ./scripts/harden_web_release.sh --compat-js
echo "[web-compat-release] hardening completed"

echo "[web-compat-release] run compat-js release gate"
./scripts/release_hardening_gate.sh --web-flavor=compat-js
echo "[web-compat-release] release gate passed"

if [ "$create_zip" = true ]; then
  if ! command -v zip >/dev/null 2>&1; then
    echo "ERROR: zip command is required to create $zip_path"
    exit 1
  fi
  archive_parent="$(dirname "$zip_path")"
  archive_name="$(basename "$zip_path")"
  mkdir -p "$archive_parent"
  archive_abs="$(cd "$archive_parent" && pwd)/$archive_name"
  rm -f "$archive_abs"
  echo "[web-compat-release] create upload archive: $zip_path"
  (
    cd build/web
    zip -qry "$archive_abs" . -x "*.DS_Store" "__MACOSX/*"
  )
  echo "[web-compat-release] archive completed: $zip_path"
else
  echo "[web-compat-release] archive creation skipped"
fi

echo "[web-compat-release] done"
echo "Key folder: $key_dir"
echo "Private seed file: $key_dir/private_seed.b64"
echo "Public key file: $key_dir/public_key.b64"
echo "Deployable artifact: build/web"
if [ "$create_zip" = true ]; then
  echo "Upload archive: $zip_path"
fi
