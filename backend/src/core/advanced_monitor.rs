use crate::core::event_pipeline::{Event, EventKind, EventPipeline};
use chrono::Utc;
use log::warn;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use uuid::Uuid;

/// Application-level file monitor that periodically checks watched directories
/// for changes by comparing file metadata snapshots.
///
/// This uses only standard filesystem reads — no OS-level hooks, no kernel modules,
/// no privileged APIs. It is a polling-based approach suitable for cross-platform use.
pub struct AdvancedMonitor {
    watch_paths: Vec<PathBuf>,
    poll_interval: Duration,
    running: Arc<AtomicBool>,
    snapshot: HashMap<String, FileSnapshot>,
}

#[derive(Debug, Clone)]
struct FileSnapshot {
    size: u64,
    sha256: String,
}

impl AdvancedMonitor {
    pub fn new(watch_paths: Vec<PathBuf>, poll_interval_secs: u64) -> Self {
        Self {
            watch_paths,
            poll_interval: Duration::from_secs(poll_interval_secs),
            running: Arc::new(AtomicBool::new(false)),
            snapshot: HashMap::new(),
        }
    }

    pub fn is_running(&self) -> bool {
        self.running.load(Ordering::Relaxed)
    }

    pub fn stop_flag(&self) -> Arc<AtomicBool> {
        Arc::clone(&self.running)
    }

    /// Take an initial snapshot of all watched paths.
    pub fn take_snapshot(&mut self) -> Result<usize, Box<dyn std::error::Error>> {
        self.snapshot.clear();
        for dir in &self.watch_paths.clone() {
            self.scan_directory(dir)?;
        }
        Ok(self.snapshot.len())
    }

    /// Compare current state against the last snapshot and emit events for changes.
    /// Returns a list of detected change events.
    pub fn detect_changes(
        &mut self,
    ) -> Result<Vec<Event>, Box<dyn std::error::Error>> {
        let mut events = Vec::new();
        let mut current = HashMap::new();

        for dir in &self.watch_paths.clone() {
            Self::collect_files(dir, &mut current)?;
        }

        // Detect new and modified files
        for (path, cur_snap) in &current {
            match self.snapshot.get(path) {
                None => {
                    events.push(Event {
                        id: Uuid::new_v4().to_string(),
                        kind: EventKind::FileCreated,
                        source: path.clone(),
                        detail: format!("New file: {} ({} bytes)", path, cur_snap.size),
                        timestamp: Utc::now().to_rfc3339(),
                        risk_score: 0.0,
                    });
                }
                Some(old_snap) => {
                    if old_snap.sha256 != cur_snap.sha256 {
                        events.push(Event {
                            id: Uuid::new_v4().to_string(),
                            kind: EventKind::FileModified,
                            source: path.clone(),
                            detail: format!(
                                "File modified: {} (hash changed)",
                                path
                            ),
                            timestamp: Utc::now().to_rfc3339(),
                            risk_score: 0.0,
                        });
                    }
                }
            }
        }

        // Detect deleted files
        for path in self.snapshot.keys() {
            if !current.contains_key(path) {
                events.push(Event {
                    id: Uuid::new_v4().to_string(),
                    kind: EventKind::FileDeleted,
                    source: path.clone(),
                    detail: format!("File deleted: {}", path),
                    timestamp: Utc::now().to_rfc3339(),
                    risk_score: 0.0,
                });
            }
        }

        // Update snapshot to current state
        self.snapshot = current;

        Ok(events)
    }

    /// Run a single monitoring cycle: detect changes and push them into the pipeline.
    pub fn run_cycle(
        &mut self,
        pipeline: &EventPipeline,
    ) -> Result<usize, Box<dyn std::error::Error>> {
        let events = self.detect_changes()?;
        let count = events.len();
        for event in events {
            pipeline.submit(event)?;
        }
        Ok(count)
    }

    /// Poll interval for external loop control.
    pub fn poll_interval(&self) -> Duration {
        self.poll_interval
    }

    fn scan_directory(&mut self, dir: &Path) -> Result<(), Box<dyn std::error::Error>> {
        let mut files = HashMap::new();
        Self::collect_files(dir, &mut files)?;
        self.snapshot.extend(files);
        Ok(())
    }

    fn collect_files(
        dir: &Path,
        out: &mut HashMap<String, FileSnapshot>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if !dir.exists() {
            warn!("Watch path does not exist: {}", dir.display());
            return Ok(());
        }

        let walker = walkdir::WalkDir::new(dir)
            .follow_links(false)
            .max_depth(10);

        for entry in walker.into_iter().filter_map(|e| e.ok()) {
            let path = entry.path();
            if !path.is_file() {
                continue;
            }
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                if name.starts_with('.') {
                    continue;
                }
            }

            let metadata = fs::metadata(path)?;

            // Compute SHA-256
            let data = fs::read(path)?;
            let mut hasher = Sha256::new();
            hasher.update(&data);
            let hash = hex::encode(hasher.finalize());

            let path_str = path.to_string_lossy().to_string();
            out.insert(
                path_str.clone(),
                FileSnapshot {
                    size: metadata.len(),
                    sha256: hash,
                },
            );
        }
        Ok(())
    }
}
