use crate::core::database::{Database, QuarantineRecord};
use chrono::Utc;
use sha2::{Digest, Sha256};
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

/// Quarantine system for safely isolating suspicious files.
///
/// Files are moved to a quarantine directory and renamed to prevent
/// accidental execution. Original metadata is stored in the database
/// so files can be restored if a detection is a false positive.
pub struct Quarantine<'a> {
    quarantine_dir: PathBuf,
    db: &'a Database,
}

impl<'a> Quarantine<'a> {
    pub fn new(quarantine_dir: &str, db: &'a Database) -> Result<Self, std::io::Error> {
        let dir = PathBuf::from(quarantine_dir);
        if !dir.exists() {
            fs::create_dir_all(&dir)?;
        }
        Ok(Self {
            quarantine_dir: dir,
            db,
        })
    }

    /// Move a file into quarantine.
    /// The file is renamed with a UUID to prevent execution and path collision.
    pub fn isolate(&self, file_path: &str) -> Result<QuarantineRecord, Box<dyn std::error::Error>> {
        let source = Path::new(file_path);
        if !source.exists() {
            return Err(format!("File not found: {file_path}").into());
        }

        // Read and hash before moving
        let data = fs::read(source)?;
        let mut hasher = Sha256::new();
        hasher.update(&data);
        let sha256 = hex::encode(hasher.finalize());

        let id = Uuid::new_v4().to_string();
        let quarantine_name = format!("{id}.quarantined");
        let dest = self.quarantine_dir.join(&quarantine_name);

        // Move file to quarantine
        fs::rename(source, &dest).or_else(|_| {
            // If rename fails (cross-device), copy + delete
            fs::copy(source, &dest)?;
            fs::remove_file(source)
        })?;

        let record = QuarantineRecord {
            id: id.clone(),
            original_path: file_path.to_string(),
            quarantine_path: dest.to_string_lossy().to_string(),
            sha256,
            reason: "Detected as threat by scanner".into(),
            quarantined_at: Utc::now().to_rfc3339(),
            restored: false,
        };

        self.db.insert_quarantine(&record)?;

        Ok(record)
    }

    /// Restore a quarantined file to its original location.
    pub fn restore(&self, quarantine_id: &str) -> Result<String, Box<dyn std::error::Error>> {
        // Find the record
        let items = self.db.get_quarantined_items()?;
        let record = items
            .iter()
            .find(|r| r.id == quarantine_id)
            .ok_or_else(|| format!("Quarantine record not found: {quarantine_id}"))?;

        let source = Path::new(&record.quarantine_path);
        let dest = Path::new(&record.original_path);

        if !source.exists() {
            return Err("Quarantined file no longer exists on disk".into());
        }

        // Ensure parent directory exists
        if let Some(parent) = dest.parent() {
            fs::create_dir_all(parent)?;
        }

        fs::rename(source, dest).or_else(|_| {
            fs::copy(source, dest)?;
            fs::remove_file(source)
        })?;

        self.db.mark_restored(quarantine_id)?;

        Ok(record.original_path.clone())
    }

    /// List all currently quarantined files.
    pub fn list(&self) -> Result<Vec<QuarantineRecord>, Box<dyn std::error::Error>> {
        Ok(self.db.get_quarantined_items()?)
    }
}
