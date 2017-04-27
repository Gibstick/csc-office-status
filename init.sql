BEGIN;

CREATE TABLE IF NOT EXISTS office_statuses (
    status INTEGER NOT NULL,
    ts INTEGER PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS office_status_deltas (
    status INTEGER NOT NULL,
    ts INTEGER REFERENCES office_stauses
);


CREATE UNIQUE INDEX IF NOT EXISTS ts_index on office_statuses(ts);
CREATE UNIQUE INDEX IF NOT EXISTS ts_index_deltas on office_status_deltas(ts);

-- this database is pretty much append-only
-- but it doesn't matter, because no one cares about historical blips in the data

CREATE TRIGGER IF NOT EXISTS delta_trigger BEFORE INSERT
ON office_statuses
WHEN
    NEW.status != (
        SELECT status FROM office_statuses WHERE ts = (SELECT max(ts) FROM office_statuses)
    )
    OR (SELECT count(*) FROM office_statuses) = 0
BEGIN
INSERT INTO office_status_deltas (status, ts) values (NEW.status, NEW.ts);
END;

COMMIT;
