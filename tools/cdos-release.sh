#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# CDOS: publish a built mq_ui as a GitHub release that players find with Settings > Device > Check for Updates.
# The player asks api.github.com/repos/<repo>/releases/latest, takes the tag (vN.N.N, must be newer than what it runs)
# and downloads the six signed assets. Draft/pre-releases are invisible to it.
#
# Usage: tools/cdos-release.sh <mq_ui> <version N.N.N> <epoch> ["release notes"]
set -eu
REPO=${CDOS_REPO:-VadimKalinin1993/CDOS}
BRANCH=${CDOS_BRANCH:-redesign}
UI=${1:?usage: cdos-release.sh <mq_ui> <version> <epoch> [notes]}; VER=${2:?version}; EPOCH=${3:?epoch}
NOTES=${4:-"CDOS $VER"}
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=$(mktemp -d); trap 'rm -rf "$OUT"' EXIT
sh "$HERE/cdos-sign.sh" "$UI" "$VER" "$EPOCH" "$OUT"
gh release create "v$VER" --repo "$REPO" --target "$BRANCH" --title "CDOS $VER" --notes "$NOTES" --latest \
    "$OUT/diskos-ota-keyauthz" "$OUT/diskos-ota-keyauthz.sig" "$OUT/diskos-ota-leafpub.pem" \
    "$OUT/diskos-ota-update.manifest" "$OUT/diskos-ota-update.manifest.sig" "$OUT/diskos-ota-mq_ui"
echo "published v$VER to $REPO"
