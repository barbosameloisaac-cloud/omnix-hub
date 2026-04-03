use chrono::Utc;
use log::info;
use std::fs;
use std::path::{Path, PathBuf};

/// Application-level log rotation manager.
/// Rotates log files when they exceed a size threshold, keeping
/// a configurable number of historical log files.
///
/// Operates only on application-owned log files in the configured
/// log directory. No system-level log manipulation.
pub struct LogRotationManager {
    log_dir: PathBuf,
    max_file_size_bytes: u64,
    max_rotated_files: usize,
}

impl LogRotationManager {
    pub fn new(log_dir: &str, max_file_size_mb: u64, max_rotated_files: usize) -> Self {
        Self {
            log_dir: PathBuf::from(log_dir),
            max_file_size_bytes: max_file_size_mb * 1024 * 1024,
            max_rotated_files,
        }
    }

    /// Ensure the log directory exists.
    pub fn initialize(&self) -> Result<(), std::io::Error> {
        fs::create_dir_all(&self.log_dir)
    }

    /// Check if the given log file needs rotation and rotate if so.
    /// Returns true if rotation occurred.
    pub fn rotate_if_needed(&self, log_file: &str) -> Result<bool, Box<dyn std::error::Error>> {
        let path = self.log_dir.join(log_file);
        if !path.exists() {
            return Ok(false);
        }

        let metadata = fs::metadata(&path)?;
        if metadata.len() < self.max_file_size_bytes {
            return Ok(false);
        }

        self.rotate(&path, log_file)?;
        Ok(true)
    }

    /// Force rotation of a log file.
    pub fn rotate(
        &self,
        path: &Path,
        base_name: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let timestamp = Utc::now().format("%Y%m%d_%H%M%S");
        let rotated_name = format!("{base_name}.{timestamp}");
        let rotated_path = self.log_dir.join(&rotated_name);

        fs::rename(path, &rotated_path)?;

        // Create a fresh empty log file
        fs::write(path, "")?;

        info!("Rotated log: {base_name} -> {rotated_name}");

        // Cleanup old rotated files
        self.cleanup_old_rotations(base_name)?;

        Ok(rotated_name)
    }

    /// Remove oldest rotated files beyond the retention limit.
    fn cleanup_old_rotations(
        &self,
        base_name: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let prefix = format!("{base_name}.");
        let mut rotated_files: Vec<PathBuf> = fs::read_dir(&self.log_dir)?
            .filter_map(|e| e.ok())
            .filter(|e| {
                e.file_name()
                    .to_str()
                    .map(|n| n.starts_with(&prefix) && n != base_name)
                    .unwrap_or(false)
            })
            .map(|e| e.path())
            .collect();

        // Sort by name (which includes timestamp, so chronological)
        rotated_files.sort();

        // Remove oldest files beyond the limit
        while rotated_files.len() > self.max_rotated_files {
            if let Some(oldest) = rotated_files.first() {
                info!("Removing old log rotation: {}", oldest.display());
                fs::remove_file(oldest)?;
                rotated_files.remove(0);
            }
        }

        Ok(())
    }

    /// List all rotated log files for a given base name.
    pub fn list_rotations(
        &self,
        base_name: &str,
    ) -> Result<Vec<String>, Box<dyn std::error::Error>> {
        let prefix = format!("{base_name}.");
        let mut files: Vec<String> = fs::read_dir(&self.log_dir)?
            .filter_map(|e| e.ok())
            .filter_map(|e| {
                let name = e.file_name().to_string_lossy().to_string();
                if name.starts_with(&prefix) && name != base_name {
                    Some(name)
                } else {
                    None
                }
            })
            .collect();
        files.sort();
        Ok(files)
    }

    /// Get total size of all log files (current + rotated) in bytes.
    pub fn total_log_size(&self) -> Result<u64, std::io::Error> {
        let mut total = 0u64;
        if self.log_dir.exists() {
            for entry in fs::read_dir(&self.log_dir)? {
                let entry = entry?;
                if entry.path().is_file() {
                    total += entry.metadata()?.len();
                }
            }
        }
        Ok(total)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn test_rotation_creates_new_file() {
        let dir = std::env::temp_dir().join("omnix_log_test");
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();

        let mgr = LogRotationManager::new(dir.to_str().unwrap(), 0, 5); // 0 MB = always rotate

        let log_path = dir.join("test.log");
        fs::write(&log_path, "some log content here\n").unwrap();

        let rotated = mgr.rotate_if_needed("test.log").unwrap();
        assert!(rotated);

        // Original file should be empty now
        let content = fs::read_to_string(&log_path).unwrap();
        assert!(content.is_empty());

        // Rotated file should exist
        let rotations = mgr.list_rotations("test.log").unwrap();
        assert_eq!(rotations.len(), 1);

        let _ = fs::remove_dir_all(&dir);
    }
}
