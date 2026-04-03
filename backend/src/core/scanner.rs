use crate::core::config::AppConfig;
use crate::core::database::{Database, ScanRecord};
use crate::core::heuristics::{HeuristicEngine, HeuristicResult, Verdict};
use crate::core::signatures::{Severity, SignatureDatabase};
use chrono::Utc;
use log::{info, warn};
use sha2::{Digest, Sha256};
use std::fs;
use std::path::Path;
use uuid::Uuid;
use walkdir::WalkDir;

#[derive(Debug, Clone)]
pub struct ScanResult {
    pub file_path: String,
    pub sha256: String,
    pub file_size: u64,
    pub signature_match: Option<String>,
    pub signature_severity: Option<Severity>,
    pub heuristic: HeuristicResult,
    pub overall: OverallVerdict,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OverallVerdict {
    Clean,
    Suspicious,
    Threat,
}

impl std::fmt::Display for OverallVerdict {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            OverallVerdict::Clean => write!(f, "CLEAN"),
            OverallVerdict::Suspicious => write!(f, "SUSPICIOUS"),
            OverallVerdict::Threat => write!(f, "THREAT"),
        }
    }
}

impl ScanResult {
    pub fn is_threat(&self) -> bool {
        self.overall == OverallVerdict::Threat
    }
}

pub struct Scanner<'a> {
    config: &'a AppConfig,
    db: &'a Database,
    sig_db: SignatureDatabase,
    heuristic_engine: HeuristicEngine,
}

impl<'a> Scanner<'a> {
    pub fn new(config: &'a AppConfig, db: &'a Database) -> Result<Self, Box<dyn std::error::Error>> {
        let sig_db = SignatureDatabase::new();
        let heuristic_engine = HeuristicEngine::new(config.heuristic_threshold);
        info!(
            "Scanner initialized: {} signatures loaded, heuristic threshold={:.1}",
            sig_db.total_signatures(),
            config.heuristic_threshold
        );
        Ok(Self {
            config,
            db,
            sig_db,
            heuristic_engine,
        })
    }

    pub fn scan_path(&self, path: &Path) -> Result<Vec<ScanResult>, Box<dyn std::error::Error>> {
        let mut results = Vec::new();

        if path.is_file() {
            if let Some(r) = self.scan_file(path)? {
                results.push(r);
            }
        } else if path.is_dir() {
            for entry in WalkDir::new(path)
                .follow_links(false)
                .into_iter()
                .filter_map(|e| e.ok())
            {
                let entry_path = entry.path();
                if !entry_path.is_file() {
                    continue;
                }

                // Skip hidden files unless configured
                if !self.config.scan_hidden_files {
                    if let Some(name) = entry_path.file_name().and_then(|n| n.to_str()) {
                        if name.starts_with('.') {
                            continue;
                        }
                    }
                }

                match self.scan_file(entry_path) {
                    Ok(Some(r)) => results.push(r),
                    Ok(None) => {}
                    Err(e) => warn!("Error scanning {}: {e}", entry_path.display()),
                }
            }
        }

        Ok(results)
    }

    fn scan_file(&self, path: &Path) -> Result<Option<ScanResult>, Box<dyn std::error::Error>> {
        let metadata = fs::metadata(path)?;
        let file_size = metadata.len();

        // Skip files exceeding size limit
        if file_size > self.config.max_file_size_bytes() {
            info!("Skipping {} (exceeds size limit)", path.display());
            return Ok(None);
        }

        let data = fs::read(path)?;

        // Compute SHA-256
        let mut hasher = Sha256::new();
        hasher.update(&data);
        let hash = hex::encode(hasher.finalize());

        // Signature check
        let sig_match = self.sig_db.lookup(&hash);

        // Heuristic analysis
        let file_name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown");
        let heuristic = self.heuristic_engine.analyze(file_name, &data);

        // Determine overall verdict
        let overall = if sig_match.is_some() {
            OverallVerdict::Threat
        } else if heuristic.verdict == Verdict::Likely {
            OverallVerdict::Threat
        } else if heuristic.verdict == Verdict::Suspicious {
            OverallVerdict::Suspicious
        } else {
            OverallVerdict::Clean
        };

        let file_path_str = path.to_string_lossy().to_string();

        // Build details string
        let details = if let Some(sig) = &sig_match {
            format!("Signature match: {} ({})", sig.name, sig.severity)
        } else if !heuristic.indicators.is_empty() {
            let descs: Vec<_> = heuristic.indicators.iter().map(|i| i.rule.clone()).collect();
            format!("Heuristic: {}", descs.join(", "))
        } else {
            "No issues found".into()
        };

        // Record in database
        let record = ScanRecord {
            id: Uuid::new_v4().to_string(),
            file_path: file_path_str.clone(),
            sha256: hash.clone(),
            file_size,
            scan_result: overall.to_string(),
            details: details.clone(),
            scanned_at: Utc::now().to_rfc3339(),
        };
        self.db.insert_scan(&record)?;

        let result = ScanResult {
            file_path: file_path_str,
            sha256: hash,
            file_size,
            signature_match: sig_match.map(|s| s.name.clone()),
            signature_severity: sig_match.map(|s| s.severity),
            heuristic,
            overall,
        };

        Ok(Some(result))
    }
}
