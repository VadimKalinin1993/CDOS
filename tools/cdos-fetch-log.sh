#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# CDOS: copy the player's UI log (read-only) over Debug Mode SSH. Usage: tools/cdos-fetch-log.sh <player-ip> [out.log]
set -eu
IP=${1:?usage: cdos-fetch-log.sh <player-ip> [out.log]}; OUT=${2:-cdos-player.log}
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@"$IP" \
    'cat /usr/data/diskos_boot.log; echo "=== updates ==="; ls -la /usr/data/updates 2>&1; cat /usr/data/updates/accepted 2>&1' > "$OUT"
echo "saved $(wc -l < "$OUT" | tr -d ' ') lines to $OUT"
