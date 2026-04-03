use rusqlite::params;
use serde::{Deserialize, Serialize};
use crate::core::database::Database;

/// Tracks the history of signature database updates.
/// Each applied update bundle is recorded with version, timestamp,
/// number of signatures added, and status.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateRecord {
    pub id: String,
    pub version: String,
    pub applied_at: String,
    pub signatures_added: usize,
    pub description: String,
    pub status: String,
}

pub struct UpdateHistory<'a> {
    db: &'a Database,
}

impl<'a> UpdateHistory<'a> {
    pub fn new(db: &'a Database) -> Self {
        Self { db }
    }

    /// Create the update_history table if it doesn't exist.
    pub fn initialize(db: &Database) -> Result<(), rusqlite::Error> {
        db.execute_raw(
            "CREATE TABLE IF NOT EXISTS update_history (
                id TEXT PRIMARY KEY,
                version TEXT NOT NULL,
                applied_at TEXT NOT NULL,
                signatures_added INTEGER NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'applied'
            );
            CREATE INDEX IF NOT EXISTS idx_update_version ON update_history(version);",
        )
    }

    /// Record a new update in the history.
    pub fn record_update(&self, record: &UpdateRecord) -> Result<(), rusqlite::Error> {
        self.db.execute_sql(
            "INSERT INTO update_history (id, version, applied_at, signatures_added, description, status)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                record.id,
                record.version,
                record.applied_at,
                record.signatures_added as i64,
                record.description,
                record.status
            ],
        )
    }

    /// Get all update records, newest first.
    pub fn get_all(&self) -> Result<Vec<UpdateRecord>, rusqlite::Error> {
        self.db.query_mapped(
            "SELECT id, version, applied_at, signatures_added, description, status
             FROM update_history ORDER BY applied_at DESC",
            [],
            |row| {
                Ok(UpdateRecord {
                    id: row.get(0)?,
                    version: row.get(1)?,
                    applied_at: row.get(2)?,
                    signatures_added: row.get::<_, i64>(3)? as usize,
                    description: row.get(4)?,
                    status: row.get(5)?,
                })
            },
        )
    }

    /// Get the latest applied version, if any.
    pub fn latest_version(&self) -> Result<Option<String>, rusqlite::Error> {
        let records = self.get_all()?;
        Ok(records.first().map(|r| r.version.clone()))
    }
}
