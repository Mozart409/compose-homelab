#!/bin/sh

set -euo pipefail

clear

echo "Cleaning up pinchflat..."

ssh root@homelab "sqlite3 /root/compose-homelab/pinchflat/config/db/pinchflat.db 'PRAGMA wal_checkpoint(TRUNCATE); VACUUM;'"
ssh root@homelab "cd compose-homelab; docker compose restart pinchflat"

exit 0
