//! The sole owner of local SQLite connections and migrations.

use openriver_domain::validate_hand;
use openriver_parser::{ParseDiagnostic, ParseResult};
use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions},
    SqlitePool,
};
use std::path::Path;

pub const SCHEMA_VERSION: u32 = 2;
static MIGRATOR: sqlx::migrate::Migrator = sqlx::migrate!("./migrations");

#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("could not open the local database")]
    Database(#[from] sqlx::Error),
    #[error("could not migrate the local database")]
    Migration(#[from] sqlx::migrate::MigrateError),
    #[error("the local database schema is incompatible")]
    IncompatibleSchema,
    #[error("could not serialize a validated hand")]
    Serialization(#[from] serde_json::Error),
    #[error("the hand failed canonical validation")]
    InvalidHand,
}

pub struct Library {
    pool: SqlitePool,
}

impl Library {
    pub async fn open(path: &Path) -> Result<Self, StorageError> {
        let options = SqliteConnectOptions::new()
            .filename(path)
            .create_if_missing(true)
            .foreign_keys(true)
            .journal_mode(SqliteJournalMode::Wal)
            .busy_timeout(std::time::Duration::from_secs(5));
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(options)
            .await?;
        MIGRATOR.run(&pool).await?;
        let library = Self { pool };
        if library.schema_version().await? != SCHEMA_VERSION {
            return Err(StorageError::IncompatibleSchema);
        }
        Ok(library)
    }

    pub async fn schema_version(&self) -> Result<u32, StorageError> {
        let version: String =
            sqlx::query_scalar("SELECT value FROM library_metadata WHERE key = 'schema_version'")
                .fetch_one(&self.pool)
                .await?;
        version
            .parse()
            .map_err(|_| StorageError::IncompatibleSchema)
    }

    pub async fn close(self) {
        self.pool.close().await;
    }

    /// Store the whole report atomically. A repeated hand remains a duplicate even across files.
    pub async fn import(
        &self,
        result: &ParseResult,
        source_sha256: &str,
    ) -> Result<ImportSummary, StorageError> {
        let mut tx = self.pool.begin().await?;
        let batch_id: i64 = sqlx::query_scalar(
            "INSERT INTO import_batches (source_sha256, parser_version, parsed_count, imported_count, duplicate_count, rejected_count) VALUES (?, ?, ?, 0, 0, ?) RETURNING id")
            .bind(source_sha256).bind(&result.parser_version)
            .bind((result.hands.len() + result.diagnostics.len()) as i64)
            .bind(result.diagnostics.len() as i64)
            .fetch_one(&mut *tx).await?;
        let mut imported = 0usize;
        let mut duplicates = 0usize;
        for hand in &result.hands {
            validate_hand(hand).map_err(|_| StorageError::InvalidHand)?;
            let json = serde_json::to_string(hand)?;
            let pot: i64 = hand
                .pots
                .iter()
                .try_fold(0i64, |sum, pot| sum.checked_add(pot.amount.0))
                .ok_or(StorageError::InvalidHand)?;
            let inserted = sqlx::query("INSERT INTO imported_hands (batch_id, room, game_variant, external_hand_id, source_sha256, source_start_line, source_end_line, parser_version, played_at, table_name, canonical_json, total_pot_units) VALUES (?, ?, 'nlhe_cash', ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(room, game_variant, external_hand_id) DO NOTHING")
                .bind(batch_id).bind(&hand.provenance.room).bind(&hand.provenance.external_hand_id)
                .bind(&hand.provenance.source_sha256).bind(hand.provenance.start_line as i64)
                .bind(hand.provenance.end_line as i64).bind(&hand.provenance.parser_version)
                .bind(&hand.played_at).bind(&hand.table_name).bind(json).bind(pot)
                .execute(&mut *tx).await?.rows_affected();
            if inserted == 1 {
                imported += 1;
            } else {
                duplicates += 1;
            }
        }
        for d in &result.diagnostics {
            sqlx::query("INSERT INTO import_diagnostics (batch_id, source_hand_id, source_start_line, source_end_line, severity, code, parser_version) VALUES (?, ?, ?, ?, ?, ?, ?)")
                .bind(batch_id).bind(&d.source_hand_id).bind(d.start_line as i64)
                .bind(d.end_line as i64).bind(format!("{:?}", d.severity))
                .bind(format!("{:?}", d.code)).bind(&d.parser_version)
                .execute(&mut *tx).await?;
        }
        sqlx::query(
            "UPDATE import_batches SET imported_count = ?, duplicate_count = ? WHERE id = ?",
        )
        .bind(imported as i64)
        .bind(duplicates as i64)
        .bind(batch_id)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(ImportSummary {
            parsed: result.hands.len() + result.diagnostics.len(),
            imported,
            duplicates,
            rejected: result.diagnostics.len(),
            diagnostics: result.diagnostics.clone(),
            parser_version: result.parser_version.clone(),
        })
    }

    pub async fn hand_count(&self) -> Result<i64, StorageError> {
        Ok(sqlx::query_scalar("SELECT COUNT(*) FROM imported_hands")
            .fetch_one(&self.pool)
            .await?)
    }
}

#[derive(Clone, Debug)]
pub struct ImportSummary {
    pub parsed: usize,
    pub imported: usize,
    pub duplicates: usize,
    pub rejected: usize,
    pub diagnostics: Vec<ParseDiagnostic>,
    pub parser_version: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::borrow::Cow;

    #[tokio::test]
    async fn migration_is_persistent_and_idempotent() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("library.sqlite3");
        for _ in 0..2 {
            let library = Library::open(&path).await.unwrap();
            assert_eq!(library.schema_version().await.unwrap(), SCHEMA_VERSION);
            let journal: String = sqlx::query_scalar("PRAGMA journal_mode")
                .fetch_one(&library.pool)
                .await
                .unwrap();
            assert_eq!(journal, "wal");
            let foreign_keys: i32 = sqlx::query_scalar("PRAGMA foreign_keys")
                .fetch_one(&library.pool)
                .await
                .unwrap();
            assert_eq!(foreign_keys, 1);
            library.close().await;
        }
    }

    #[tokio::test]
    async fn rejects_incompatible_schema_and_invalid_paths() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("library.sqlite3");
        let library = Library::open(&path).await.unwrap();
        sqlx::query("UPDATE library_metadata SET value = '999' WHERE key = 'schema_version'")
            .execute(&library.pool)
            .await
            .unwrap();
        library.close().await;
        assert!(matches!(
            Library::open(&path).await,
            Err(StorageError::IncompatibleSchema)
        ));
        assert!(matches!(
            Library::open(&dir.path().join("missing/library.sqlite3")).await,
            Err(StorageError::Database(_))
        ));
    }

    #[tokio::test]
    async fn mixed_and_overlapping_imports_survive_reopen() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("library.sqlite3");
        let source = [
            include_str!("../../../fixtures/hands/golden_side_pot.txt"),
            include_str!("../../../fixtures/hands/truncated.txt"),
        ]
        .join("\n");
        let parsed = openriver_parser::parse(source.as_bytes()).unwrap();
        let library = Library::open(&path).await.unwrap();
        let first = library.import(&parsed, "mixed-file").await.unwrap();
        assert_eq!(
            (
                first.parsed,
                first.imported,
                first.duplicates,
                first.rejected
            ),
            (2, 1, 0, 1)
        );
        let again = library.import(&parsed, "mixed-file").await.unwrap();
        assert_eq!(
            (again.imported, again.duplicates, again.rejected),
            (0, 1, 1)
        );
        library.close().await;
        let library = Library::open(&path).await.unwrap();
        let overlap = openriver_parser::parse(include_bytes!(
            "../../../fixtures/hands/golden_side_pot.txt"
        ))
        .unwrap();
        let summary = library.import(&overlap, "overlap-file").await.unwrap();
        assert_eq!((summary.imported, summary.duplicates), (0, 1));
        assert_eq!(library.hand_count().await.unwrap(), 1);
        library.close().await;
    }

    #[tokio::test]
    async fn write_failure_rolls_back_batch() {
        let dir = tempfile::tempdir().unwrap();
        let library = Library::open(&dir.path().join("library.sqlite3"))
            .await
            .unwrap();
        sqlx::query("CREATE TRIGGER reject_hand BEFORE INSERT ON imported_hands BEGIN SELECT RAISE(ABORT, 'injected'); END")
            .execute(&library.pool).await.unwrap();
        let parsed = openriver_parser::parse(include_bytes!(
            "../../../fixtures/hands/golden_side_pot.txt"
        ))
        .unwrap();
        assert!(library.import(&parsed, "failure").await.is_err());
        let batches: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM import_batches")
            .fetch_one(&library.pool)
            .await
            .unwrap();
        assert_eq!(batches, 0);
        assert_eq!(library.hand_count().await.unwrap(), 0);
    }

    #[tokio::test]
    async fn schema_one_upgrades_without_losing_metadata() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("library.sqlite3");
        let pool = SqlitePool::connect_with(
            SqliteConnectOptions::new()
                .filename(&path)
                .create_if_missing(true),
        )
        .await
        .unwrap();
        let first = sqlx::migrate::Migrator {
            migrations: Cow::Owned(vec![MIGRATOR.migrations[0].clone()]),
            ..sqlx::migrate::Migrator::DEFAULT
        };
        first.run(&pool).await.unwrap();
        sqlx::query("INSERT INTO library_metadata (key, value) VALUES ('sentinel', 'kept')")
            .execute(&pool)
            .await
            .unwrap();
        pool.close().await;
        let library = Library::open(&path).await.unwrap();
        assert_eq!(library.schema_version().await.unwrap(), 2);
        let value: String =
            sqlx::query_scalar("SELECT value FROM library_metadata WHERE key = 'sentinel'")
                .fetch_one(&library.pool)
                .await
                .unwrap();
        assert_eq!(value, "kept");
        library.close().await;
    }

    #[tokio::test]
    #[ignore = "manual 10,000-hand import measurement"]
    async fn ten_thousand_synthetic_hands() {
        let template = include_str!("../../../fixtures/hands/normal_fold.txt");
        let source = (0..10_000)
            .map(|i| template.replace("Hand #1002", &format!("Hand #{}", 10_000 + i)))
            .collect::<Vec<_>>()
            .join("\n");
        let start = std::time::Instant::now();
        let parsed = openriver_parser::parse(source.as_bytes()).unwrap();
        let parse_elapsed = start.elapsed();
        let dir = tempfile::tempdir().unwrap();
        let library = Library::open(&dir.path().join("library.sqlite3"))
            .await
            .unwrap();
        let start = std::time::Instant::now();
        let result = library.import(&parsed, "synthetic-10k").await.unwrap();
        let write_elapsed = start.elapsed();
        assert_eq!((result.imported, result.rejected), (10_000, 0));
        assert_eq!(library.hand_count().await.unwrap(), 10_000);
        let start = std::time::Instant::now();
        let again = library.import(&parsed, "synthetic-10k").await.unwrap();
        let repeat_elapsed = start.elapsed();
        assert_eq!((again.imported, again.duplicates), (0, 10_000));
        eprintln!("synthetic 10k: source_bytes={}, parse={parse_elapsed:?}, write={write_elapsed:?}, repeat={repeat_elapsed:?}", source.len());
    }
}
