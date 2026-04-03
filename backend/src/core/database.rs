use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::sync::Mutex;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanRecord {
    pub id: String,
    pub file_path: String,
    pub sha256: String,
    pub file_size: u64,
    pub scan_result: String,
    pub details: String,
    pub scanned_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuarantineRecord {
    pub id: String,
    pub original_path: String,
    pub quarantine_path: String,
    pub sha256: String,
    pub reason: String,
    pub quarantined_at: String,
    pub restored: bool,
}

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    pub fn open(path: &str) -> Result<Self, rusqlite::Error> {
        let conn = Connection::open(path)?;
        conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;")?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn initialize(&self) -> Result<(), rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS scan_history (
                id TEXT PRIMARY KEY,
                file_path TEXT NOT NULL,
                sha256 TEXT NOT NULL,
                file_size INTEGER NOT NULL,
                scan_result TEXT NOT NULL,
                details TEXT NOT NULL DEFAULT '',
                scanned_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS quarantine (
                id TEXT PRIMARY KEY,
                original_path TEXT NOT NULL,
                quarantine_path TEXT NOT NULL,
                sha256 TEXT NOT NULL,
                reason TEXT NOT NULL DEFAULT '',
                quarantined_at TEXT NOT NULL,
                restored INTEGER NOT NULL DEFAULT 0
            );

            CREATE INDEX IF NOT EXISTS idx_scan_sha256 ON scan_history(sha256);
            CREATE INDEX IF NOT EXISTS idx_scan_path ON scan_history(file_path);
            CREATE INDEX IF NOT EXISTS idx_quarantine_sha256 ON quarantine(sha256);",
        )?;
        Ok(())
    }

    pub fn insert_scan(&self, record: &ScanRecord) -> Result<(), rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO scan_history (id, file_path, sha256, file_size, scan_result, details, scanned_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                record.id,
                record.file_path,
                record.sha256,
                record.file_size,
                record.scan_result,
                record.details,
                record.scanned_at
            ],
        )?;
        Ok(())
    }

    pub fn insert_quarantine(&self, record: &QuarantineRecord) -> Result<(), rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO quarantine (id, original_path, quarantine_path, sha256, reason, quarantined_at, restored)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                record.id,
                record.original_path,
                record.quarantine_path,
                record.sha256,
                record.reason,
                record.quarantined_at,
                record.restored as i32
            ],
        )?;
        Ok(())
    }

    pub fn mark_restored(&self, quarantine_id: &str) -> Result<bool, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let updated = conn.execute(
            "UPDATE quarantine SET restored = 1 WHERE id = ?1 AND restored = 0",
            params![quarantine_id],
        )?;
        Ok(updated > 0)
    }

    pub fn find_by_sha256(&self, sha256: &str) -> Result<Vec<ScanRecord>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, file_path, sha256, file_size, scan_result, details, scanned_at
             FROM scan_history WHERE sha256 = ?1 ORDER BY scanned_at DESC",
        )?;
        let rows = stmt.query_map(params![sha256], |row| {
            Ok(ScanRecord {
                id: row.get(0)?,
                file_path: row.get(1)?,
                sha256: row.get(2)?,
                file_size: row.get::<_, i64>(3)? as u64,
                scan_result: row.get(4)?,
                details: row.get(5)?,
                scanned_at: row.get(6)?,
            })
        })?;
        rows.collect()
    }

    pub fn get_quarantined_items(&self) -> Result<Vec<QuarantineRecord>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, original_path, quarantine_path, sha256, reason, quarantined_at, restored
             FROM quarantine WHERE restored = 0 ORDER BY quarantined_at DESC",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(QuarantineRecord {
                id: row.get(0)?,
                original_path: row.get(1)?,
                quarantine_path: row.get(2)?,
                sha256: row.get(3)?,
                reason: row.get(4)?,
                quarantined_at: row.get(5)?,
                restored: row.get::<_, i32>(6)? != 0,
            })
        })?;
        rows.collect()
    }
}
