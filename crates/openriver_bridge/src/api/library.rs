//! Coarse-grained, typed application commands. Never expose SQL to Dart.
use crate::frb_generated::StreamSink;
use openriver_analytics::aggregate::{HandFilter, PlayerStats, StatsEngine};
use openriver_analytics::stats::Stat;
use openriver_storage::{AnalyticsQuery, HandQuery, HandSort, Library, StorageError};
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
    ExportDestinationExists,
    InvalidExportPath,
    ExportFailed,
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
            StorageError::ExportDestinationExists => Self::ExportDestinationExists,
            StorageError::InvalidExportPath => Self::InvalidExportPath,
            StorageError::Export(_) => Self::ExportFailed,
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

pub struct PlayerAnalyticsRequest {
    pub room: String,
    pub player: String,
    pub currency: String,
    pub date_from: Option<String>,
    pub date_to: Option<String>,
    pub min_big_blind: Option<i64>,
    pub max_big_blind: Option<i64>,
}

pub struct AnalyticsPlayer {
    pub room: String,
    pub name: String,
    pub hands: u64,
}

pub struct CurrencyResults {
    pub currency: String,
    pub currency_scale: u8,
    pub net: i64,
    pub net_at_showdown: i64,
    pub net_without_showdown: i64,
}

pub struct StatisticValue {
    pub key: String,
    pub label: String,
    pub description: String,
    pub successes: u64,
    pub eligible: u64,
    pub rate: Option<f64>,
    pub interval_low: Option<f64>,
    pub interval_high: Option<f64>,
    pub minimum_meaningful_sample: u32,
}

pub struct PlayerStatistics {
    pub room: String,
    pub name: String,
    pub hands: u64,
    pub hands_counted: u64,
    pub net_big_blinds: f64,
    pub bb_per_100: Option<f64>,
    pub aggression_factor: Option<f64>,
    pub aggression_frequency: Option<f64>,
    pub results: Vec<CurrencyResults>,
    pub stats: Vec<StatisticValue>,
}

pub struct ResultPoint {
    pub sequence: u32,
    pub played_at: String,
    pub external_hand_id: String,
    pub net: i64,
    pub cumulative_net: i64,
    pub cumulative_big_blinds: f64,
}

pub struct PlayerAnalytics {
    pub players: Vec<AnalyticsPlayer>,
    pub total_players: u32,
    pub selected: Option<PlayerStatistics>,
    pub graph_currency: Option<String>,
    pub graph_currency_scale: u8,
    pub points: Vec<ResultPoint>,
}

pub struct ExportSummary {
    pub hand_count: u32,
}

fn analytics_query(request: &PlayerAnalyticsRequest) -> AnalyticsQuery {
    AnalyticsQuery {
        room: (!request.room.is_empty()).then(|| request.room.clone()),
        currency: (!request.currency.is_empty()).then(|| request.currency.to_uppercase()),
        date_from: request.date_from.clone(),
        date_to: request.date_to.clone(),
        min_big_blind: request.min_big_blind,
        max_big_blind: request.max_big_blind,
    }
}

fn analytics_filter(request: &PlayerAnalyticsRequest) -> HandFilter {
    HandFilter {
        from: request
            .date_from
            .as_ref()
            .map(|date| format!("{date}T00:00:00Z")),
        to: request
            .date_to
            .as_ref()
            .map(|date| format!("{date}T23:59:59Z")),
        currency: (!request.currency.is_empty()).then(|| request.currency.to_uppercase()),
        min_big_blind: request.min_big_blind,
        max_big_blind: request.max_big_blind,
        rooms: (!request.room.is_empty()).then(|| std::iter::once(request.room.clone()).collect()),
        ..HandFilter::default()
    }
}

fn statistics(
    engine: &StatsEngine,
    room: String,
    name: String,
    stats: &PlayerStats,
) -> PlayerStatistics {
    PlayerStatistics {
        room,
        name,
        hands: stats.hands,
        hands_counted: engine.hands_counted(),
        net_big_blinds: stats.money.net_big_blinds,
        bb_per_100: stats.money.bb_per_100(),
        aggression_factor: stats.postflop.factor(),
        aggression_frequency: stats.postflop.frequency(),
        results: stats
            .money
            .net
            .iter()
            .map(|((currency, scale), net)| CurrencyResults {
                currency: currency.clone(),
                currency_scale: *scale,
                net: *net,
                net_at_showdown: stats
                    .money
                    .net_at_showdown
                    .get(&(currency.clone(), *scale))
                    .copied()
                    .unwrap_or(0),
                net_without_showdown: stats
                    .money
                    .net_without_showdown
                    .get(&(currency.clone(), *scale))
                    .copied()
                    .unwrap_or(0),
            })
            .collect(),
        stats: Stat::ALL
            .into_iter()
            .map(|stat| {
                let count = stats.get(stat);
                let interval = count.wilson_interval_95();
                StatisticValue {
                    key: stat.key().into(),
                    label: stat.label().into(),
                    description: stat.description().into(),
                    successes: count.successes(),
                    eligible: count.sample_size(),
                    rate: count.rate(),
                    interval_low: interval.map(|value| value.0),
                    interval_high: interval.map(|value| value.1),
                    minimum_meaningful_sample: stat.minimum_meaningful_sample() as u32,
                }
            })
            .collect(),
    }
}

fn sampled_points(points: Vec<ResultPoint>) -> Vec<ResultPoint> {
    const MAX_POINTS: usize = 500;
    if points.len() <= MAX_POINTS {
        return points;
    }
    let last = points.len() - 1;
    let mut next_sample = 0usize;
    points
        .into_iter()
        .enumerate()
        .filter_map(|(index, point)| {
            let target = next_sample * last / (MAX_POINTS - 1);
            if index != target {
                return None;
            }
            next_sample += 1;
            Some(point)
        })
        .collect()
}

/// Aggregates validated stored hands in Rust. Players are bounded and graph
/// points are evenly sampled while retaining the first and final results.
pub async fn player_analytics(
    database_path: String,
    request: PlayerAnalyticsRequest,
) -> Result<PlayerAnalytics, CoreError> {
    let library = Library::open(std::path::Path::new(&database_path)).await?;
    let query = analytics_query(&request);
    let filter = analytics_filter(&request);
    let mut engine = StatsEngine::new(filter.clone());
    let mut cursor: Option<(String, i64)> = None;
    loop {
        let batch = library
            .analytics_batch(
                &query,
                cursor.as_ref().map(|(date, id)| (date.as_str(), *id)),
                500,
            )
            .await?;
        if batch.is_empty() {
            break;
        }
        let batch_len = batch.len();
        cursor = batch.last().map(|row| (row.played_at.clone(), row.id));
        for row in batch {
            engine
                .add_hand(&row.hand)
                .map_err(|_| CoreError::InvalidSource)?;
        }
        if batch_len < 500 {
            break;
        }
    }

    let mut players: Vec<_> = engine
        .players()
        .map(|(key, stats)| AnalyticsPlayer {
            room: key.room.clone(),
            name: key.name.clone(),
            hands: stats.hands,
        })
        .collect();
    players.sort_by(|a, b| {
        b.hands
            .cmp(&a.hands)
            .then_with(|| a.room.cmp(&b.room))
            .then_with(|| a.name.cmp(&b.name))
    });
    let total_players = players.len() as u32;
    let selected_key = if request.player.is_empty() {
        players
            .first()
            .map(|player| (player.room.clone(), player.name.clone()))
    } else {
        Some((request.room.clone(), request.player.clone()))
    };
    let selected = selected_key.as_ref().and_then(|(room, name)| {
        engine
            .player(room, name)
            .map(|stats| statistics(&engine, room.clone(), name.clone(), stats))
    });
    if let Some((room, name)) = &selected_key {
        if players.len() >= 100 && !players.iter().any(|p| &p.room == room && &p.name == name) {
            if let Some(stats) = engine.player(room, name) {
                players.push(AnalyticsPlayer {
                    room: room.clone(),
                    name: name.clone(),
                    hands: stats.hands,
                });
            }
        }
    }
    players.truncate(100);

    let graph = selected.as_ref().and_then(|selected| {
        if request.currency.is_empty() {
            selected
                .results
                .first()
                .map(|result| (result.currency.clone(), result.currency_scale))
        } else {
            let currency = request.currency.to_uppercase();
            let scale = selected
                .results
                .iter()
                .find(|result| result.currency == currency)
                .map(|result| result.currency_scale)
                .unwrap_or(2);
            Some((currency, scale))
        }
    });
    let mut points = Vec::new();
    let mut cumulative_net = 0i64;
    let mut cumulative_big_blinds = 0f64;
    if let (Some((room, name)), Some((graph_currency, _))) = (&selected_key, &graph) {
        let mut graph_query = query.clone();
        graph_query.currency = Some(graph_currency.clone());
        let mut graph_filter = filter.clone();
        graph_filter.currency = Some(graph_currency.clone());
        let mut cursor: Option<(String, i64)> = None;
        loop {
            let batch = library
                .analytics_batch(
                    &graph_query,
                    cursor.as_ref().map(|(date, id)| (date.as_str(), *id)),
                    500,
                )
                .await?;
            if batch.is_empty() {
                break;
            }
            let batch_len = batch.len();
            cursor = batch.last().map(|row| (row.played_at.clone(), row.id));
            for row in batch {
                let analysis = openriver_analytics::analysis::analyze(&row.hand)
                    .map_err(|_| CoreError::InvalidSource)?;
                if !graph_filter.hand_matches(&row.hand, &analysis) {
                    continue;
                }
                let Some(player) = analysis.players.iter().find(|player| player.name == *name)
                else {
                    continue;
                };
                if !graph_filter.player_matches(player) || row.hand.provenance.room != *room {
                    continue;
                }
                cumulative_net += player.net;
                cumulative_big_blinds += player.net as f64 / analysis.big_blind as f64;
                points.push(ResultPoint {
                    sequence: points.len() as u32 + 1,
                    played_at: row.played_at,
                    external_hand_id: row.hand.provenance.external_hand_id,
                    net: player.net,
                    cumulative_net,
                    cumulative_big_blinds,
                });
            }
            if batch_len < 500 {
                break;
            }
        }
    }
    library.close().await;
    Ok(PlayerAnalytics {
        players,
        total_players,
        selected,
        graph_currency_scale: graph.as_ref().map(|value| value.1).unwrap_or(2),
        graph_currency: graph.map(|value| value.0),
        points: sampled_points(points),
    })
}

/// Creates a consistent SQLite backup without copying the live WAL files.
pub async fn export_library(
    database_path: String,
    destination_path: String,
) -> Result<ExportSummary, CoreError> {
    let library = Library::open(std::path::Path::new(&database_path)).await?;
    let hand_count = library
        .export_snapshot(std::path::Path::new(&destination_path))
        .await? as u32;
    library.close().await;
    Ok(ExportSummary { hand_count })
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
    use super::*;

    #[tokio::test]
    async fn analytics_returns_core_stats_and_a_bounded_result_graph() {
        let dir = tempfile::tempdir().unwrap();
        let database_path = dir.path().join("library.sqlite3");
        let library = Library::open(&database_path).await.unwrap();
        let parsed =
            openriver_parser::parse(include_bytes!("../../../../fixtures/hands/normal_fold.txt"))
                .unwrap();
        library.import(&parsed, "analytics").await.unwrap();
        library.close().await;

        let report = player_analytics(
            database_path.to_string_lossy().into_owned(),
            PlayerAnalyticsRequest {
                room: String::new(),
                player: String::new(),
                currency: String::new(),
                date_from: None,
                date_to: None,
                min_big_blind: None,
                max_big_blind: None,
            },
        )
        .await
        .unwrap();
        assert_eq!(report.total_players, 2);
        assert_eq!(report.players.len(), 2);
        let selected = report.selected.unwrap();
        assert_eq!(selected.name, "Ada");
        assert_eq!(selected.hands, 1);
        assert_eq!(selected.results[0].net, 2);
        assert_eq!(selected.bb_per_100, Some(100.0));
        let vpip = selected
            .stats
            .iter()
            .find(|stat| stat.key == "vpip")
            .unwrap();
        assert_eq!(
            (vpip.successes, vpip.eligible, vpip.rate),
            (1, 1, Some(1.0))
        );
        let pfr = selected
            .stats
            .iter()
            .find(|stat| stat.key == "pfr")
            .unwrap();
        assert_eq!((pfr.successes, pfr.eligible, pfr.rate), (0, 1, Some(0.0)));
        assert_eq!(report.graph_currency.as_deref(), Some("USD"));
        assert_eq!(report.points.len(), 1);
        assert_eq!(report.points[0].cumulative_net, 2);
        assert_eq!(report.points[0].cumulative_big_blinds, 1.0);
    }

    #[test]
    fn graph_sampling_retains_both_endpoints() {
        let points = (1..=600)
            .map(|sequence| ResultPoint {
                sequence,
                played_at: String::new(),
                external_hand_id: sequence.to_string(),
                net: 0,
                cumulative_net: 0,
                cumulative_big_blinds: 0.0,
            })
            .collect();
        let sampled = sampled_points(points);
        assert_eq!(sampled.len(), 500);
        assert_eq!(sampled.first().unwrap().sequence, 1);
        assert_eq!(sampled.last().unwrap().sequence, 600);
        assert!(sampled
            .windows(2)
            .all(|pair| pair[0].sequence < pair[1].sequence));
    }

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
