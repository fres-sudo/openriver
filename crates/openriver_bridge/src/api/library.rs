//! Coarse-grained, typed application commands. Never expose SQL to Dart.
use crate::frb_generated::StreamSink;
use openriver_storage::{HandQuery, HandSort, Library, StorageError};
use sha2::{Digest, Sha256};
use std::sync::atomic::{AtomicBool, Ordering};

/// One import runs at a time (the UI enforces this); `cancel_import` flips this flag.
static CANCEL_IMPORT: AtomicBool = AtomicBool::new(false);

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
    Cancelled,
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
            StorageError::Cancelled => Self::Cancelled,
            StorageError::InvalidStoredHand => Self::InvalidSource,
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

/// Streamed during an import. The last event carries the `summary`; earlier ones only progress.
pub struct ImportEvent {
    pub processed: u32,
    pub total: u32,
    pub summary: Option<ImportSummary>,
}

pub struct HandListItem {
    pub id: i64,
    pub played_at: String,
    pub room: String,
    pub external_hand_id: String,
    pub table_name: String,
    pub currency: String,
    pub currency_scale: u8,
    pub small_blind: i64,
    pub big_blind: i64,
    pub player_count: u8,
    pub total_pot: i64,
}

pub enum HandSortColumn {
    PlayedAt,
    HandId,
    Table,
    Room,
    Blinds,
    Players,
    Pot,
}

pub struct HandQueryRequest {
    pub search: String,
    pub room: String,
    pub currency: String,
    pub date_from: Option<String>,
    pub date_to: Option<String>,
    pub min_players: Option<u8>,
    pub max_players: Option<u8>,
    pub sort: HandSortColumn,
    pub descending: bool,
    pub page: u32,
    pub page_size: u32,
}

pub struct HandSearchResult {
    pub hands: Vec<HandListItem>,
    pub total: i64,
    pub page: u32,
    pub page_size: u32,
}

pub async fn search_hands(
    database_path: String,
    request: HandQueryRequest,
) -> Result<HandSearchResult, CoreError> {
    let library = Library::open(std::path::Path::new(&database_path)).await?;
    let page = library
        .search_hands(&HandQuery {
            search: request.search,
            room: request.room,
            currency: request.currency,
            date_from: request.date_from,
            date_to: request.date_to,
            min_players: request.min_players,
            max_players: request.max_players,
            sort: match request.sort {
                HandSortColumn::PlayedAt => HandSort::PlayedAt,
                HandSortColumn::HandId => HandSort::HandId,
                HandSortColumn::Table => HandSort::Table,
                HandSortColumn::Room => HandSort::Room,
                HandSortColumn::Blinds => HandSort::Blinds,
                HandSortColumn::Players => HandSort::Players,
                HandSortColumn::Pot => HandSort::Pot,
            },
            descending: request.descending,
            page: request.page,
            page_size: request.page_size,
        })
        .await?;
    library.close().await;
    Ok(HandSearchResult {
        hands: page.hands.into_iter().map(HandListItem::from).collect(),
        total: page.total,
        page: page.page,
        page_size: page.page_size,
    })
}

impl From<openriver_storage::StoredHandSummary> for HandListItem {
    fn from(row: openriver_storage::StoredHandSummary) -> Self {
        Self {
            id: row.id,
            played_at: row.played_at,
            room: row.room,
            external_hand_id: row.external_hand_id,
            table_name: row.table_name,
            currency: row.currency,
            currency_scale: row.currency_scale,
            small_blind: row.small_blind,
            big_blind: row.big_blind,
            player_count: row.player_count,
            total_pot: row.total_pot,
        }
    }
}

pub struct HandPage {
    pub hands: Vec<HandListItem>,
    pub next_played_at: Option<String>,
    pub next_id: Option<i64>,
}

pub async fn list_hands(
    database_path: String,
    cursor_played_at: Option<String>,
    cursor_id: Option<i64>,
) -> Result<HandPage, CoreError> {
    let library = Library::open(std::path::Path::new(&database_path)).await?;
    let cursor = cursor_played_at.as_deref().zip(cursor_id);
    let mut rows = library.list_hands(31, cursor).await?;
    library.close().await;
    let has_more = rows.len() > 30;
    rows.truncate(30);
    let next = if has_more { rows.last() } else { None };
    let next_played_at = next.map(|row| row.played_at.clone());
    let next_id = next.map(|row| row.id);
    Ok(HandPage {
        hands: rows.into_iter().map(HandListItem::from).collect(),
        next_played_at,
        next_id,
    })
}

/// Rust computes every replay snapshot; Dart only renders this serialized view.
pub async fn hand_replay(database_path: String, hand_id: i64) -> Result<String, CoreError> {
    let library = Library::open(std::path::Path::new(&database_path)).await?;
    let hand = library.get_hand(hand_id).await?;
    library.close().await;
    let hand = hand.ok_or(CoreError::InvalidSource)?;
    let replay =
        openriver_analytics::replay::replay(&hand).map_err(|_| CoreError::InvalidSource)?;
    serde_json::to_string(&replay).map_err(|_| CoreError::InvalidSource)
}

/// Asks the running import to stop; its uncommitted batch is discarded.
#[flutter_rust_bridge::frb(sync)]
pub fn cancel_import() {
    CANCEL_IMPORT.store(true, Ordering::Relaxed);
}

/// The selected path is used only for this bounded read and is never returned in errors.
pub async fn import_hand_history(
    database_path: String,
    file_path: String,
    events: StreamSink<ImportEvent>,
) -> Result<(), CoreError> {
    CANCEL_IMPORT.store(false, Ordering::Relaxed);
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
    let outcome = library
        .import_with_progress(&parsed, &source_hash, &CANCEL_IMPORT, |processed, total| {
            let _ = events.add(ImportEvent {
                processed: processed as u32,
                total: total as u32,
                summary: None,
            });
        })
        .await;
    let stored_hand_count = match &outcome {
        Ok(_) => library.hand_count().await? as u32,
        Err(_) => 0,
    };
    library.close().await;
    let summary = outcome?;
    let report = ImportSummary {
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
    };
    let _ = events.add(ImportEvent {
        processed: report.parsed,
        total: report.parsed,
        summary: Some(report),
    });
    Ok(())
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

#[cfg(test)]
mod tests {
    #[test]
    fn replay_json_keeps_rust_snapshot_shape() {
        let parsed =
            openriver_parser::parse(include_bytes!("../../../../fixtures/hands/normal_fold.txt"))
                .unwrap();
        let replay = openriver_analytics::replay::replay(&parsed.hands[0]).unwrap();
        let wire = serde_json::to_value(replay).unwrap();
        let steps = wire["steps"].as_array().unwrap();
        assert_eq!(steps[0]["event"], "Start");
        assert_eq!(steps[0]["seats"][0]["position"], "Button");
        assert_eq!(
            steps[1]["event"]["Action"]["kind"]["PostSmallBlind"]["amount_added"],
            1
        );
        assert!(steps
            .iter()
            .any(|step| step["event"]["Street"]["street"] == "Flop"));
        assert!(steps
            .iter()
            .any(|step| step["event"]["Award"]["amount"] == 4));
    }
}
