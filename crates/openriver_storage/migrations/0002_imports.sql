CREATE TABLE import_batches (
    id INTEGER PRIMARY KEY,
    source_sha256 TEXT NOT NULL,
    parser_version TEXT NOT NULL,
    parsed_count INTEGER NOT NULL CHECK (parsed_count >= 0),
    imported_count INTEGER NOT NULL CHECK (imported_count >= 0),
    duplicate_count INTEGER NOT NULL CHECK (duplicate_count >= 0),
    rejected_count INTEGER NOT NULL CHECK (rejected_count >= 0),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE imported_hands (
    id INTEGER PRIMARY KEY,
    batch_id INTEGER NOT NULL REFERENCES import_batches(id),
    room TEXT NOT NULL,
    game_variant TEXT NOT NULL,
    external_hand_id TEXT NOT NULL,
    source_sha256 TEXT NOT NULL,
    source_start_line INTEGER NOT NULL CHECK (source_start_line > 0),
    source_end_line INTEGER NOT NULL CHECK (source_end_line >= source_start_line),
    parser_version TEXT NOT NULL,
    played_at TEXT NOT NULL,
    table_name TEXT NOT NULL,
    canonical_json TEXT NOT NULL,
    total_pot_units INTEGER NOT NULL CHECK (total_pot_units >= 0),
    UNIQUE (room, game_variant, external_hand_id)
);
CREATE INDEX imported_hands_played_at ON imported_hands(played_at, id);

CREATE TABLE import_diagnostics (
    id INTEGER PRIMARY KEY,
    batch_id INTEGER NOT NULL REFERENCES import_batches(id),
    source_hand_id TEXT,
    source_start_line INTEGER NOT NULL,
    source_end_line INTEGER NOT NULL,
    severity TEXT NOT NULL,
    code TEXT NOT NULL,
    parser_version TEXT NOT NULL
);

UPDATE library_metadata SET value = '2' WHERE key = 'schema_version';
