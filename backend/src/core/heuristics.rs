use serde::{Deserialize, Serialize};

/// Heuristic analysis result for a single file.
/// Each rule that fires produces an `Indicator` with a score and explanation.
/// The total score is compared against the configured threshold.
///
/// All heuristics here are purely defensive and educational:
/// they detect suspicious patterns that a security-aware user would want to know about,
/// such as embedded scripts in non-script files or unusually high entropy.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HeuristicResult {
    pub indicators: Vec<Indicator>,
    pub total_score: f64,
    pub verdict: Verdict,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Indicator {
    pub rule: String,
    pub description: String,
    pub score: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Verdict {
    Clean,
    Suspicious,
    Likely,
}

impl std::fmt::Display for Verdict {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Verdict::Clean => write!(f, "CLEAN"),
            Verdict::Suspicious => write!(f, "SUSPICIOUS"),
            Verdict::Likely => write!(f, "LIKELY_THREAT"),
        }
    }
}

pub struct HeuristicEngine {
    threshold: f64,
}

impl HeuristicEngine {
    pub fn new(threshold: f64) -> Self {
        Self { threshold }
    }

    /// Analyze file contents with safe, explainable heuristic rules.
    pub fn analyze(&self, file_name: &str, data: &[u8]) -> HeuristicResult {
        let mut indicators = Vec::new();

        // Rule 1: Detect embedded script tags in non-HTML/JS files
        if let Some(ind) = self.check_embedded_scripts(file_name, data) {
            indicators.push(ind);
        }

        // Rule 2: High Shannon entropy — may indicate packed/encrypted content
        if let Some(ind) = self.check_entropy(data) {
            indicators.push(ind);
        }

        // Rule 3: Null byte presence in text-like files
        if let Some(ind) = self.check_null_bytes(file_name, data) {
            indicators.push(ind);
        }

        // Rule 4: Double extension (e.g., "report.pdf.exe")
        if let Some(ind) = self.check_double_extension(file_name) {
            indicators.push(ind);
        }

        // Rule 5: Executable header in a non-executable extension
        if let Some(ind) = self.check_mismatched_header(file_name, data) {
            indicators.push(ind);
        }

        let total_score: f64 = indicators.iter().map(|i| i.score).sum();
        let verdict = if total_score >= self.threshold {
            Verdict::Likely
        } else if total_score >= self.threshold * 0.5 {
            Verdict::Suspicious
        } else {
            Verdict::Clean
        };

        HeuristicResult {
            indicators,
            total_score,
            verdict,
        }
    }

    fn check_embedded_scripts(&self, file_name: &str, data: &[u8]) -> Option<Indicator> {
        let text_extensions = [".txt", ".csv", ".log", ".md", ".json", ".xml"];
        let is_text_file = text_extensions
            .iter()
            .any(|ext| file_name.to_lowercase().ends_with(ext));

        if !is_text_file {
            return None;
        }

        let content = String::from_utf8_lossy(data).to_lowercase();
        let patterns = ["<script", "javascript:", "vbscript:", "powershell"];
        let found: Vec<&str> = patterns
            .iter()
            .filter(|p| content.contains(**p))
            .copied()
            .collect();

        if found.is_empty() {
            return None;
        }

        Some(Indicator {
            rule: "EMBEDDED_SCRIPT".into(),
            description: format!(
                "Text file contains script-like patterns: {}",
                found.join(", ")
            ),
            score: 0.4,
        })
    }

    fn check_entropy(&self, data: &[u8]) -> Option<Indicator> {
        if data.len() < 256 {
            return None;
        }

        let entropy = shannon_entropy(data);
        if entropy > 7.5 {
            Some(Indicator {
                rule: "HIGH_ENTROPY".into(),
                description: format!(
                    "File has unusually high entropy ({:.2}/8.0), may be packed or encrypted",
                    entropy
                ),
                score: 0.3,
            })
        } else {
            None
        }
    }

    fn check_null_bytes(&self, file_name: &str, data: &[u8]) -> Option<Indicator> {
        let text_extensions = [".txt", ".csv", ".log", ".md", ".json", ".xml", ".html"];
        let is_text = text_extensions
            .iter()
            .any(|ext| file_name.to_lowercase().ends_with(ext));

        if !is_text {
            return None;
        }

        let null_count = data.iter().filter(|&&b| b == 0).count();
        let ratio = null_count as f64 / data.len().max(1) as f64;

        if ratio > 0.01 {
            Some(Indicator {
                rule: "NULL_BYTES_IN_TEXT".into(),
                description: format!(
                    "Text file contains {:.1}% null bytes, which is unusual",
                    ratio * 100.0
                ),
                score: 0.3,
            })
        } else {
            None
        }
    }

    fn check_double_extension(&self, file_name: &str) -> Option<Indicator> {
        let risky_final = [".exe", ".scr", ".bat", ".cmd", ".com", ".pif", ".vbs", ".js"];
        let lower = file_name.to_lowercase();
        let parts: Vec<&str> = lower.split('.').collect();

        if parts.len() >= 3 {
            let last = format!(".{}", parts.last().unwrap_or(&""));
            if risky_final.iter().any(|ext| last == *ext) {
                return Some(Indicator {
                    rule: "DOUBLE_EXTENSION".into(),
                    description: format!(
                        "File has a double extension ending in '{last}', a common social engineering technique"
                    ),
                    score: 0.5,
                });
            }
        }
        None
    }

    fn check_mismatched_header(&self, file_name: &str, data: &[u8]) -> Option<Indicator> {
        if data.len() < 4 {
            return None;
        }

        let non_exe_extensions = [
            ".pdf", ".doc", ".jpg", ".png", ".gif", ".txt", ".csv", ".zip",
        ];
        let is_non_exe = non_exe_extensions
            .iter()
            .any(|ext| file_name.to_lowercase().ends_with(ext));

        if !is_non_exe {
            return None;
        }

        // MZ header = DOS/Windows executable
        let has_mz = data[0] == b'M' && data[1] == b'Z';
        // ELF header = Linux executable
        let has_elf = data[0] == 0x7f && data[1] == b'E' && data[2] == b'L' && data[3] == b'F';

        if has_mz || has_elf {
            Some(Indicator {
                rule: "MISMATCHED_HEADER".into(),
                description: "File extension suggests non-executable, but file header indicates executable binary".into(),
                score: 0.6,
            })
        } else {
            None
        }
    }
}

/// Calculate Shannon entropy of a byte slice (0.0 to 8.0)
fn shannon_entropy(data: &[u8]) -> f64 {
    let mut freq = [0u64; 256];
    for &byte in data {
        freq[byte as usize] += 1;
    }
    let len = data.len() as f64;
    let mut entropy = 0.0;
    for &count in &freq {
        if count > 0 {
            let p = count as f64 / len;
            entropy -= p * p.log2();
        }
    }
    entropy
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_double_extension_detection() {
        let engine = HeuristicEngine::new(0.7);
        let result = engine.analyze("invoice.pdf.exe", b"MZ dummy data here");
        assert!(result.indicators.iter().any(|i| i.rule == "DOUBLE_EXTENSION"));
    }

    #[test]
    fn test_clean_file() {
        let engine = HeuristicEngine::new(0.7);
        let result = engine.analyze("readme.rs", b"fn main() { println!(\"hello\"); }");
        assert_eq!(result.verdict, Verdict::Clean);
    }

    #[test]
    fn test_entropy_calculation() {
        // Uniform random-like data should have high entropy
        let data: Vec<u8> = (0..=255).cycle().take(1024).collect();
        let e = shannon_entropy(&data);
        assert!(e > 7.9);
    }
}
