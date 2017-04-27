#! /bin/sh

set -u

WORKER_SLEEP=${WORKER_SLEEP:-30}
WORKER_TIMEOUT=${WORKER_TIMEOUT:-"2.0s"}


while true; do
    timeout "$WORKER_TIMEOUT" ./openoffice.sh
    retval="$?"
    timestamp=$(date +%s)
    if [ "$retval" -eq 124 ]; then
        status=2
    else
        status="$retval"
    fi
    sqlite3 office_status.db \
        "insert into office_statuses (status, ts) values ($retval, $timestamp)" \
    && printf "inserted (%s, %s)\n" "$retval" "$timestamp"
    sleep "$WORKER_SLEEP"
done
