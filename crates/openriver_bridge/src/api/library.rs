//! Coarse-grained, typed application commands. Never expose SQL to Dart.
use openriver_storage::{Library, StorageError};

pub struct CoreStatus {
    pub core_version: String,
    pub schema_version: u32,
}

#[derive(Debug)]
pub enum CoreError {
    DatabaseUnavailable,
    MigrationFailed,
    IncompatibleSchema,
}

impl std::fmt::Display for CoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for CoreError {}

impl From<StorageError> for CoreError {
    fn from(value: StorageError) -> Self {
        match value {
            StorageError::Database(_) => Self::DatabaseUnavailable,
            StorageError::Migration(_) => Self::MigrationFailed,
            StorageError::IncompatibleSchema => Self::IncompatibleSchema,
        }
    }
}

/// Proves the installed core can open and migrate this device's library.
/// The connection closes explicitly; future commands will use a library handle.
pub async fn initialize_library(database_path: String) -> Result<CoreStatus, CoreError> {
    let library = Library::open(std::path::Path::new(&database_path)).await?;
    let schema_version = library.schema_version().await?;
    library.close().await;
    Ok(CoreStatus {
        core_version: env!("CARGO_PKG_VERSION").to_owned(),
        schema_version,
    })
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
