use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// A known-threat signature entry.
/// Uses SHA-256 hashes of known test/example files only.
/// This is NOT a real malware database — it contains only safe test signatures
/// for demonstrating defensive scanning logic.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Signature {
    pub sha256: String,
    pub name: String,
    pub description: String,
    pub severity: Severity,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Severity {
    Low,
    Medium,
    High,
    Critical,
}

impl std::fmt::Display for Severity {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Severity::Low => write!(f, "LOW"),
            Severity::Medium => write!(f, "MEDIUM"),
            Severity::High => write!(f, "HIGH"),
            Severity::Critical => write!(f, "CRITICAL"),
        }
    }
}

pub struct SignatureDatabase {
    signatures: HashMap<String, Signature>,
}

impl SignatureDatabase {
    /// Builds the signature database with safe test entries only.
    /// These are SHA-256 hashes of well-known test strings used in
    /// antivirus testing (e.g., EICAR test pattern).
    pub fn new() -> Self {
        let mut signatures = HashMap::new();

        // EICAR test file — industry-standard antivirus test string.
        // This is NOT malware. It is a safe test file recognized by all AV vendors.
        // Content: "X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
        // SHA-256 of the EICAR test string:
        signatures.insert(
            "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f".into(),
            Signature {
                sha256: "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f"
                    .into(),
                name: "EICAR-Test-File".into(),
                description: "EICAR standard antivirus test file (safe, not malware)".into(),
                severity: Severity::Low,
            },
        );

        // Test signature: SHA-256 of the string "OMNIX-TEST-THREAT-SAMPLE"
        // Used exclusively for unit testing the detection pipeline.
        signatures.insert(
            "a]placeholder_test_hash_do_not_use_in_production".into(),
            Signature {
                sha256: "placeholder_test_hash_do_not_use_in_production".into(),
                name: "OmniX-Test-Signature".into(),
                description: "Internal test signature for pipeline validation".into(),
                severity: Severity::Low,
            },
        );

        Self { signatures }
    }

    /// Looks up a file hash against the local signature database.
    pub fn lookup(&self, sha256: &str) -> Option<&Signature> {
        self.signatures.get(sha256)
    }

    pub fn total_signatures(&self) -> usize {
        self.signatures.len()
    }
}
