-- Indexed facts for server-side hand browsing. Canonical JSON remains the
-- source of truth for replay; these values are copied from validated hands.
ALTER TABLE imported_hands ADD COLUMN currency TEXT NOT NULL DEFAULT '';
ALTER TABLE imported_hands ADD COLUMN currency_scale INTEGER NOT NULL DEFAULT 0;
ALTER TABLE imported_hands ADD COLUMN small_blind_units INTEGER NOT NULL DEFAULT 0;
ALTER TABLE imported_hands ADD COLUMN big_blind_units INTEGER NOT NULL DEFAULT 0;
ALTER TABLE imported_hands ADD COLUMN player_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE imported_hands ADD COLUMN players_text TEXT NOT NULL DEFAULT '';

UPDATE imported_hands SET
    currency = json_extract(canonical_json, '$.game.currency'),
    currency_scale = json_extract(canonical_json, '$.game.currency_scale'),
    small_blind_units = json_extract(canonical_json, '$.game.small_blind'),
    big_blind_units = json_extract(canonical_json, '$.game.big_blind'),
    player_count = json_array_length(canonical_json, '$.players'),
    players_text = COALESCE((
        SELECT group_concat(json_extract(value, '$.name'), ' ')
        FROM json_each(imported_hands.canonical_json, '$.players')
    ), '');

CREATE INDEX imported_hands_room ON imported_hands(room);
CREATE INDEX imported_hands_currency ON imported_hands(currency);
CREATE INDEX imported_hands_big_blind ON imported_hands(big_blind_units);
CREATE INDEX imported_hands_player_count ON imported_hands(player_count);
CREATE INDEX imported_hands_pot ON imported_hands(total_pot_units);
CREATE INDEX imported_hands_table_name ON imported_hands(table_name);

CREATE VIRTUAL TABLE imported_hands_fts USING fts5(
    room, external_hand_id, table_name, players_text,
    content='imported_hands', content_rowid='id', tokenize='unicode61'
);
INSERT INTO imported_hands_fts(imported_hands_fts) VALUES ('rebuild');

CREATE TRIGGER imported_hands_fts_insert AFTER INSERT ON imported_hands BEGIN
    INSERT INTO imported_hands_fts(rowid, room, external_hand_id, table_name, players_text)
    VALUES (new.id, new.room, new.external_hand_id, new.table_name, new.players_text);
END;
CREATE TRIGGER imported_hands_fts_delete AFTER DELETE ON imported_hands BEGIN
    INSERT INTO imported_hands_fts(imported_hands_fts, rowid, room, external_hand_id, table_name, players_text)
    VALUES ('delete', old.id, old.room, old.external_hand_id, old.table_name, old.players_text);
END;
CREATE TRIGGER imported_hands_fts_update AFTER UPDATE ON imported_hands BEGIN
    INSERT INTO imported_hands_fts(imported_hands_fts, rowid, room, external_hand_id, table_name, players_text)
    VALUES ('delete', old.id, old.room, old.external_hand_id, old.table_name, old.players_text);
    INSERT INTO imported_hands_fts(rowid, room, external_hand_id, table_name, players_text)
    VALUES (new.id, new.room, new.external_hand_id, new.table_name, new.players_text);
END;

UPDATE library_metadata SET value = '3' WHERE key = 'schema_version';
