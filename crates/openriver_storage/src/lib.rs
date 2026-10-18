//! The sole owner of local SQLite connections and migrations.

use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions},
    SqlitePool,
};
use std::path::Path;

pub const SCHEMA_VERSION: u32 = 1;
static MIGRATOR: sqlx::migrate::Migrator = sqlx::migrate!("./migrations");

#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("could not open the local database")]
    Database(#[from] sqlx::Error),
    #[error("could not migrate the local database")]
    Migration(#[from] sqlx::migrate::MigrateError),
    #[error("the local database schema is incompatible")]
    IncompatibleSchema,
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
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
