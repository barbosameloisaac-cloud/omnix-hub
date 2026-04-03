use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub database_path: String,
    pub quarantine_dir: String,
    pub max_file_size_mb: u64,
    pub scan_hidden_files: bool,
    pub heuristic_threshold: f64,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            database_path: "omnix_hub.db".into(),
            quarantine_dir: "quarantine".into(),
            max_file_size_mb: 100,
            scan_hidden_files: false,
            heuristic_threshold: 0.7,
        }
    }
}

impl AppConfig {
    const CONFIG_FILE: &'static str = "omnix_config.json";

    pub fn load_or_default() -> Result<Self, Box<dyn std::error::Error>> {
        let path = Path::new(Self::CONFIG_FILE);
        if path.exists() {
            let data = std::fs::read_to_string(path)?;
            let config: AppConfig = serde_json::from_str(&data)?;
            Ok(config)
        } else {
            let config = AppConfig::default();
            config.save()?;
            Ok(config)
        }
    }

    pub fn save(&self) -> Result<(), Box<dyn std::error::Error>> {
        let json = serde_json::to_string_pretty(self)?;
        std::fs::write(Self::CONFIG_FILE, json)?;
        Ok(())
    }

    pub fn max_file_size_bytes(&self) -> u64 {
        self.max_file_size_mb * 1024 * 1024
    }

    pub fn quarantine_path(&self) -> PathBuf {
        PathBuf::from(&self.quarantine_dir)
    }
}
