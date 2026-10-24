//! Coarse-grained, typed application commands. Never expose SQL to Dart.
use openriver_storage::{Library, StorageError};
use sha2::{Digest, Sha256};

pub struct CoreStatus {
    pub core_version: String,
    pub schema_version: u32,
}

#[derive(Debug)]
pub enum CoreError {
    DatabaseUnavailable,
    MigrationFailed,
    IncompatibleSchema,
    FileUnavailable,
    InvalidSource,
    UnsupportedFormat,
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
            StorageError::Serialization(_) => Self::DatabaseUnavailable,
            StorageError::InvalidHand => Self::InvalidSource,
        }
    }
}

pub struct ImportDiagnostic {
    pub source_hand_id: Option<String>,
    pub start_line: u32,
    pub end_line: u32,
    pub code: String,
}

pub struct ImportSummary {
    pub parsed: u32,
    pub imported: u32,
    pub duplicates: u32,
    pub rejected: u32,
    pub parser_version: String,
    pub diagnostics: Vec<ImportDiagnostic>,
    pub stored_hand_count: u32,
}

/// The selected path is used only for this bounded read and is never returned in errors.
pub async fn import_hand_history(
    database_path: String,
    file_path: String,
) -> Result<ImportSummary, CoreError> {
    let path = std::path::Path::new(&file_path);
    let size = std::fs::metadata(path)
        .map_err(|_| CoreError::FileUnavailable)?
        .len();
    if size > openriver_parser::MAX_SOURCE_BYTES as u64 {
        return Err(CoreError::InvalidSource);
    }
    let bytes = std::fs::read(path).map_err(|_| CoreError::FileUnavailable)?;
    let parsed = openriver_parser::parse(&bytes).map_err(|error| match error {
        openriver_parser::ImportError::UnsupportedFormat => CoreError::UnsupportedFormat,
        _ => CoreError::InvalidSource,
    })?;
    let source_hash = format!("{:x}", Sha256::digest(&bytes));
    let library = Library::open(std::path::Path::new(&database_path)).await?;
    let summary = library.import(&parsed, &source_hash).await?;
    let stored_hand_count = library.hand_count().await? as u32;
    library.close().await;
    Ok(ImportSummary {
        parsed: summary.parsed as u32,
        imported: summary.imported as u32,
        duplicates: summary.duplicates as u32,
        rejected: summary.rejected as u32,
        parser_version: summary.parser_version,
        diagnostics: summary
            .diagnostics
            .into_iter()
            .map(|d| ImportDiagnostic {
                source_hand_id: d.source_hand_id,
                start_line: d.start_line as u32,
                end_line: d.end_line as u32,
                code: format!("{:?}", d.code),
            })
            .collect(),
        stored_hand_count,
    })
}

pub async fn stored_hand_count(database_path: String) -> Result<u32, CoreError> {
    let library = Library::open(std::path::Path::new(&database_path)).await?;
    let count = library.hand_count().await? as u32;
    library.close().await;
    Ok(count)
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
