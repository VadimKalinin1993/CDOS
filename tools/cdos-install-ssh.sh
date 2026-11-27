#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# CDOS: hand a signed update bundle (tools/cdos-sign.sh) to a player over Debug Mode SSH, exactly where the in-app
# Wi-Fi update would leave it (/usr/data/updates/pending). Nothing is installed here: on the next restart the
# player's own boot script verifies the bundle against the key baked into its image and starts a trial; a build
# that never proves healthy within two boots is rolled back automatically.
#
# Usage: tools/cdos-install-ssh.sh <player-ip> <bundle_dir>     (asks once for the Debug Mode password)
set -eu
IP=${1:?usage: cdos-install-ssh.sh <player-ip> <bundle_dir>}; B=${2:?bundle_dir}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir "$T/b"
for f in keyauthz keyauthz.sig leafpub.pem update.manifest update.manifest.sig mq_ui; do cp "$B/diskos-ota-$f" "$T/b/$f"; done
VER=$(grep '^version=' "$T/b/update.manifest" | cut -d= -f2); EP=$(grep '^epoch=' "$T/b/update.manifest" | cut -d= -f2)
SHA=$(shasum -a 256 "$T/b/mq_ui" | cut -d' ' -f1)
echo "Sending CDOS $VER (epoch $EP) to $IP ..."
# ready is written on the player, last, after the device verifier has accepted the bundle
COPYFILE_DISABLE=1 tar --format ustar -C "$T/b" -cf - . | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR root@"$IP" "VER='$VER' EP='$EP' SHA='$SHA' sh -c '
set -e
U=/usr/data/updates; I=\$U/incoming
mkdir -p \$U; chmod 700 \$U
rm -rf \$I; mkdir \$I; chmod 700 \$I
tar -xf - -C \$I
[ \"\$(sha256sum \$I/mq_ui | cut -d\" \" -f1)\" = \"\$SHA\" ] || { echo \"FAILED: copy damaged\"; rm -rf \$I; exit 1; }
K=\$(grep ^MIN_KEY_EPOCH= /etc/diskos-ota/epochs | cut -d= -f2); M=\$(grep ^MIN_UI_EPOCH= /etc/diskos-ota/epochs | cut -d= -f2)
if /bin/sh /etc/diskos-ota/diskos-verify.sh /etc/diskos-ota/root.pub.pem \$K \$M \$I \$I/mq_ui; then :; else
    rc=\$?; rm -rf \$I
    [ \$rc = 1 ] && echo \"FAILED: the player rejected the bundle - nothing staged\" || echo \"FAILED: the player could not check the bundle - nothing staged\"
    exit 1
fi
printf \"version=%s\\nepoch=%s\\n\" \"\$VER\" \"\$EP\" > \$I/ready
chmod 700 \$I; chmod 600 \$I/*; sync
rm -rf \$U/pending; mv \$I \$U/pending; sync
echo \"STAGED: CDOS \$VER is waiting in \$U/pending. Restart the player to install it.\"
'"
