use crate::core::update_history::{UpdateHistory, UpdateRecord};
use chrono::Utc;
use log::{info, warn};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

/// Manages local signature database updates from a trusted directory.
/// No network access — reads update bundles from a local staging path.
/// Each bundle is a JSON file containing new signatures, verified by SHA-256 checksum.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateManifest {
    pub version: String,
    pub published_at: String,
    pub sha256_checksum: String,
    pub signatures_count: usize,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignatureBundle {
    pub manifest: UpdateManifest,
    pub signatures: Vec<SignatureEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignatureEntry {
    pub sha256: String,
    pub name: String,
    pub description: String,
    pub severity: String,
}

pub struct Updater {
    staging_dir: PathBuf,
    applied_dir: PathBuf,
}

impl Updater {
    pub fn new(staging_dir: &str) -> Result<Self, std::io::Error> {
        let staging = PathBuf::from(staging_dir);
        let applied = staging.join("applied");
        fs::create_dir_all(&staging)?;
        fs::create_dir_all(&applied)?;
        Ok(Self {
            staging_dir: staging,
            applied_dir: applied,
        })
    }

    /// List available update bundles in the staging directory.
    pub fn list_pending(&self) -> Result<Vec<UpdateManifest>, Box<dyn std::error::Error>> {
        let mut manifests = Vec::new();
        for entry in fs::read_dir(&self.staging_dir)? {
            let entry = entry?;
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) == Some("json") && path.is_file() {
                match self.read_bundle(&path) {
                    Ok(bundle) => manifests.push(bundle.manifest),
                    Err(e) => warn!("Skipping invalid bundle {}: {e}", path.display()),
                }
            }
        }
        manifests.sort_by(|a, b| a.version.cmp(&b.version));
        Ok(manifests)
    }

    /// Validate and apply a single update bundle.
    /// Returns the list of new signature entries on success.
    pub fn apply_bundle(
        &self,
        bundle_path: &Path,
        history: &UpdateHistory,
    ) -> Result<Vec<SignatureEntry>, Box<dyn std::error::Error>> {
        let bundle = self.read_bundle(bundle_path)?;

        // Verify integrity via SHA-256 of the raw file
        let raw = fs::read(bundle_path)?;
        let mut hasher = Sha256::new();
        hasher.update(&raw);
        let computed = hex::encode(hasher.finalize());

        if computed != bundle.manifest.sha256_checksum {
            return Err(format!(
                "Checksum mismatch: expected {}, got {computed}",
                bundle.manifest.sha256_checksum
            )
            .into());
        }

        if bundle.signatures.len() != bundle.manifest.signatures_count {
            return Err(format!(
                "Signature count mismatch: manifest says {}, bundle has {}",
                bundle.manifest.signatures_count,
                bundle.signatures.len()
            )
            .into());
        }

        // Record in history
        let record = UpdateRecord {
            id: Uuid::new_v4().to_string(),
            version: bundle.manifest.version.clone(),
            applied_at: Utc::now().to_rfc3339(),
            signatures_added: bundle.signatures.len(),
            description: bundle.manifest.description.clone(),
            status: "applied".into(),
        };
        history.record_update(&record)?;

        // Move bundle to applied directory
        let dest = self
            .applied_dir
            .join(bundle_path.file_name().unwrap_or_default());
        fs::rename(bundle_path, &dest).or_else(|_| {
            fs::copy(bundle_path, &dest)?;
            fs::remove_file(bundle_path)
        })?;

        info!(
            "Applied update v{}: {} signatures",
            bundle.manifest.version,
            bundle.signatures.len()
        );

        Ok(bundle.signatures)
    }

    fn read_bundle(&self, path: &Path) -> Result<SignatureBundle, Box<dyn std::error::Error>> {
        let data = fs::read_to_string(path)?;
        let bundle: SignatureBundle = serde_json::from_str(&data)?;
        Ok(bundle)
    }
}
