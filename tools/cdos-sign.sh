#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# CDOS: sign a built mq_ui as an over-the-air update bundle (the six release assets diskOS ui/ota.c downloads).
#
# Chain (checked on the player by payload/diskos-verify.sh against the root key baked into the flashed image):
#   root key (offline, ~/.snowsky-keys/ota-root.key.pem) signs keyauthz -> authorizes the leaf key
#   leaf key (~/.snowsky-keys/ota-leaf.key.pem, made on first run)   signs update.manifest -> authorizes mq_ui
#
# Usage: tools/cdos-sign.sh <mq_ui> <version N.N.N> <epoch> <out_dir>
#   epoch: a whole number, higher for every release (the player refuses an epoch it has already accepted, and
#   anything below the floor baked into the image: MIN_UI_EPOCH=8). Releases: 1.3.0 = 9, then +1 each time.
# The bundle is verified with the device's own verifier before the script reports success.
set -eu
KEYS=${CDOS_KEYS:-"$HOME/.snowsky-keys"}
OPENSSL=${OPENSSL:-/opt/homebrew/opt/openssl@3/bin/openssl}
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
UI=${1:?usage: cdos-sign.sh <mq_ui> <version> <epoch> <out_dir>}; VER=${2:?version}; EPOCH=${3:?epoch}; OUT=${4:?out_dir}
case "$VER" in [0-9]*.[0-9]*.[0-9]*) ;; *) echo "version must be N.N.N" >&2; exit 1;; esac
case "$EPOCH" in ''|*[!0-9]*) echo "epoch must be a number" >&2; exit 1;; esac
[ "$EPOCH" -ge 8 ] || { echo "epoch must be >= 8 (the image's floor)" >&2; exit 1; }
[ -f "$KEYS/ota-root.key.pem" ] || { echo "no root key in $KEYS" >&2; exit 1; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

# one-time: the leaf key and its root-signed authorization
if [ ! -f "$KEYS/ota-leaf.key.pem" ]; then
    (umask 077; "$OPENSSL" ecparam -name prime256v1 -genkey -noout -out "$KEYS/ota-leaf.key.pem")
    "$OPENSSL" ec -in "$KEYS/ota-leaf.key.pem" -pubout -out "$KEYS/ota-leaf.pub.pem" 2>/dev/null
    printf 'diskos-keyauthz-v1\nkeyid=cdos-leaf-1\nkeyepoch=1\nrole=tier-a\npubkey_sha256=%s\n' \
        "$(sha "$KEYS/ota-leaf.pub.pem")" > "$KEYS/ota-leaf.keyauthz"
    "$OPENSSL" dgst -sha256 -sign "$KEYS/ota-root.key.pem" -out "$KEYS/ota-leaf.keyauthz.sig" "$KEYS/ota-leaf.keyauthz"
    echo "made leaf key + authorization in $KEYS"
fi

mkdir -p "$OUT"
cp "$KEYS/ota-leaf.keyauthz"     "$OUT/diskos-ota-keyauthz"
cp "$KEYS/ota-leaf.keyauthz.sig" "$OUT/diskos-ota-keyauthz.sig"
cp "$KEYS/ota-leaf.pub.pem"      "$OUT/diskos-ota-leafpub.pem"
cp "$UI"                         "$OUT/diskos-ota-mq_ui"
SIZE=$(wc -c < "$UI" | tr -d ' ')
printf 'diskos-update-v1\ncomponent=mq_ui\nepoch=%s\nversion=%s\nsize=%s\nsha256=%s\nchannel=stable\n' \
    "$EPOCH" "$VER" "$SIZE" "$(sha "$UI")" > "$OUT/diskos-ota-update.manifest"
"$OPENSSL" dgst -sha256 -sign "$KEYS/ota-leaf.key.pem" -out "$OUT/diskos-ota-update.manifest.sig" "$OUT/diskos-ota-update.manifest"

# self-check with the device verifier (local names, as the player stores them)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
for f in keyauthz keyauthz.sig leafpub.pem update.manifest update.manifest.sig; do cp "$OUT/diskos-ota-$f" "$T/$f"; done
PATH="$(dirname "$OPENSSL"):$PATH" sh "$HERE/payload/diskos-verify.sh" "$KEYS/ota-root.pub.pem" 1 8 "$T" "$OUT/diskos-ota-mq_ui"
echo "bundle ready in $OUT"
