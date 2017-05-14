#!/bin/bash

RESULT=$(psql -h localhost -c 'SELECT pg_is_in_recovery();' | grep ' f')

set -e
if [[ $RESULT = ' f' ]]; then
    echo "${HOSTNAME} is currently leader. Attempting wal-e base backup."
    echo "$WALE_ENVDIR"
    envdir "$WALE_ENVDIR" wal-e backup-push "$PG_DATA"

else
    echo "Currently ${HOSTNAME} is a standby. Skipping backup."

fi