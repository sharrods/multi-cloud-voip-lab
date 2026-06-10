#!/bin/bash

DB_FILE="/var/lib/opensips/opensips.db"

if [ ! -f "$DB_FILE" ]; then
    echo "Creating OpenSIPS SQLite database..."
    
    sqlite3 $DB_FILE <<EOF
CREATE TABLE version (
    table_name TEXT NOT NULL PRIMARY KEY,
    table_version INTEGER NOT NULL
);

CREATE TABLE subscriber (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    domain TEXT NOT NULL DEFAULT '',
    password TEXT NOT NULL,
    email_address TEXT DEFAULT '',
    ha1 TEXT DEFAULT '',
    UNIQUE(username, domain)
);

INSERT INTO version VALUES ('subscriber', 7);

CREATE TABLE acc (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    method TEXT NOT NULL DEFAULT '',
    from_tag TEXT NOT NULL DEFAULT '',
    to_tag TEXT NOT NULL DEFAULT '',
    callid TEXT NOT NULL DEFAULT '',
    sip_code TEXT NOT NULL DEFAULT '',
    sip_reason TEXT NOT NULL DEFAULT '',
    time DATETIME NOT NULL,
    src_user TEXT DEFAULT '',
    dst_user TEXT DEFAULT '',
    call_id TEXT DEFAULT ''
);

CREATE INDEX acc_callid_idx ON acc(callid);

INSERT INTO version VALUES ('acc', 7);

CREATE TABLE missed_calls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    method TEXT NOT NULL DEFAULT '',
    from_tag TEXT NOT NULL DEFAULT '',
    to_tag TEXT NOT NULL DEFAULT '',
    callid TEXT NOT NULL DEFAULT '',
    sip_code TEXT NOT NULL DEFAULT '',
    sip_reason TEXT NOT NULL DEFAULT '',
    time DATETIME NOT NULL
);

INSERT INTO version VALUES ('missed_calls', 5);

INSERT INTO subscriber (username, domain, password, email_address)
VALUES 
    ('1000', '34.170.209.88', '1234567', 'user1000@example.com'),
    ('1001', '34.170.209.88', '1234567', 'user1001@example.com');

EOF

    echo "Database created successfully!"
    chmod 644 $DB_FILE
fi
