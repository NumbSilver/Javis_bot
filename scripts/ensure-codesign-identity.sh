#!/bin/zsh
# Ensure a stable local codesigning identity "Jarvis Local" exists in the
# login keychain. TCC (Full Disk Access / Photos / …) keys off this identity
# across rebuilds — without it, every `go build` looks like a new binary.
set -euo pipefail

identity=${JARVIS_CODESIGN_IDENTITY:-Jarvis Local}
script_dir=${0:A:h}
repo_dir=${script_dir:h}
material_dir=${JARVIS_CODESIGN_DIR:-$repo_dir/var/codesign}
cnf=$script_dir/codesign/openssl-codesign.cnf
keychain=${JARVIS_CODESIGN_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}
p12_pass=${JARVIS_CODESIGN_P12_PASS:-jarvis-local-codesign}

usage() {
  cat >&2 <<'EOF'
Usage: ./scripts/ensure-codesign-identity.sh [--authorize]

Without flags, ensure the stable local signing identity exists.
--authorize updates that identity's private-key ACL once so /usr/bin/codesign
can reuse it without showing a Keychain password dialog on every rebuild.
EOF
}

identity_exists() {
  security find-identity -v -p codesigning "$keychain" 2>/dev/null |
    grep -F "\"$identity\"" >/dev/null
}

authorize_codesign() {
  identity_exists || {
    echo "codesign identity is missing: $identity" >&2
    echo "run this script without flags first" >&2
    exit 1
  }

  local keychain_password test_binary
  read -r -s "keychain_password?Mac login keychain password: "
  echo
  [[ -n $keychain_password ]] || {
    echo "keychain password must not be empty" >&2
    exit 1
  }

  if ! security set-key-partition-list \
      -S apple-tool:,apple:,codesign: \
      -s \
      -l "$identity" \
      -k "$keychain_password" \
      "$keychain" >/dev/null; then
    keychain_password=""
    echo "failed to authorize codesign key access" >&2
    exit 1
  fi
  keychain_password=""

  test_binary=$(mktemp "${TMPDIR:-/tmp}/jarvis-codesign-check.XXXXXX")
  trap 'rm -f "${test_binary:-}"' EXIT
  cp /usr/bin/true "$test_binary"
  chmod 0755 "$test_binary"
  codesign \
    --force \
    --sign "$identity" \
    --identifier com.bytedance.jarvis.codesign-check \
    "$test_binary"
  codesign --verify --strict "$test_binary"
  rm -f "$test_binary"
  trap - EXIT
  echo "codesign key access authorized; future rebuilds should not prompt"
}

case ${1:-} in
  "")
    ;;
  --authorize)
    authorize_codesign
    exit 0
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

if identity_exists; then
  echo "codesign identity already present: $identity"
  security find-identity -v -p codesigning "$keychain" | grep -F "\"$identity\"" || true
  exit 0
fi

if [[ ! -f $cnf ]]; then
  echo "missing openssl config: $cnf" >&2
  exit 1
fi

mkdir -p "$material_dir"
key=$material_dir/jarvis-local.key
crt=$material_dir/jarvis-local.crt
p12=$material_dir/jarvis-local.p12

echo "creating self-signed codesign certificate: $identity"
openssl genrsa -out "$key" 2048
openssl req -new -x509 \
  -key "$key" \
  -out "$crt" \
  -days 3650 \
  -config "$cnf" \
  -extensions v3_codesign
openssl pkcs12 -export \
  -inkey "$key" \
  -in "$crt" \
  -out "$p12" \
  -passout "pass:$p12_pass" \
  -name "$identity" \
  -certpbe PBE-SHA1-3DES \
  -keypbe PBE-SHA1-3DES \
  -macalg sha1 \
  2>/dev/null \
  || openssl pkcs12 -export -legacy \
    -inkey "$key" \
    -in "$crt" \
    -out "$p12" \
    -passout "pass:$p12_pass" \
    -name "$identity"

# Allow codesign to use the key without interactive ACL prompts.
security import "$p12" \
  -k "$keychain" \
  -P "$p12_pass" \
  -A \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  >/dev/null

# Prefer code-signing trust for this cert (best-effort; some macOS versions differ).
security add-trusted-cert -d -r trustAsRoot -p codeSign -k "$keychain" "$crt" 2>/dev/null \
  || security add-trusted-cert -d -r trustRoot -k "$keychain" "$crt" 2>/dev/null \
  || true

if ! identity_exists; then
  echo "failed to install codesign identity \"$identity\"" >&2
  echo "open Keychain Access, import $p12, set Trust→Code Signing to Always Trust, then re-run." >&2
  exit 1
fi

echo "codesign identity ready: $identity"
echo "materials kept under $material_dir (gitignored via /var/)"
echo "run \"$0 --authorize\" once to suppress future Keychain access prompts"
security find-identity -v -p codesigning "$keychain" | grep -F "\"$identity\"" || true
