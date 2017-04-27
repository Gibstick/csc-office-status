#! /bin/sh

set -u

WORKER_SLEEP=${WORKER_SLEEP:-30}
WORKER_TIMEOUT=${WORKER_TIMEOUT:-"4.0s"}
WORKER_SCRIPT=${WORKER_SCRIPT:-"./openoffice.sh"}


while true; do
    timeout "$WORKER_TIMEOUT" "$WORKER_SCRIPT"
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
