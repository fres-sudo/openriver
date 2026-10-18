-- Foundation schema only. Hand/import tables arrive with the canonical importer.
CREATE TABLE library_metadata (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
);

INSERT INTO library_metadata (key, value) VALUES ('schema_version', '1');

