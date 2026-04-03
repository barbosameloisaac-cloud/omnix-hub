use crate::core::scanner::{OverallVerdict, ScanResult};
use chrono::Utc;

pub struct ReportGenerator;

impl ReportGenerator {
    /// Generate a human-readable scan report.
    pub fn generate(results: &[ScanResult]) -> String {
        let mut report = String::new();

        let total = results.len();
        let clean = results
            .iter()
            .filter(|r| r.overall == OverallVerdict::Clean)
            .count();
        let suspicious = results
            .iter()
            .filter(|r| r.overall == OverallVerdict::Suspicious)
            .count();
        let threats = results
            .iter()
            .filter(|r| r.overall == OverallVerdict::Threat)
            .count();

        report.push_str(&format!(
            "═══ OmniX Hub Scan Report ═══\nDate: {}\n",
            Utc::now().format("%Y-%m-%d %H:%M:%S UTC")
        ));
        report.push_str(&format!("Files scanned: {total}\n"));
        report.push_str(&format!(
            "Results: {clean} clean, {suspicious} suspicious, {threats} threat(s)\n"
        ));
        report.push_str("═════════════════════════════\n");

        // Only show non-clean files in detail
        for result in results.iter().filter(|r| r.overall != OverallVerdict::Clean) {
            report.push_str(&format!("\n▸ {}\n", result.file_path));
            report.push_str(&format!("  SHA-256: {}\n", result.sha256));
            report.push_str(&format!(
                "  Size: {}\n",
                human_readable_size(result.file_size)
            ));
            report.push_str(&format!("  Verdict: {}\n", result.overall));

            if let Some(ref sig_name) = result.signature_match {
                report.push_str(&format!(
                    "  Signature: {} [{}]\n",
                    sig_name,
                    result.signature_severity.unwrap()
                ));
            }

            if !result.heuristic.indicators.is_empty() {
                report.push_str("  Heuristic indicators:\n");
                for ind in &result.heuristic.indicators {
                    report.push_str(&format!("    - [{}] {} (score: {:.1})\n", ind.rule, ind.description, ind.score));
                }
                report.push_str(&format!(
                    "  Heuristic total: {:.2}\n",
                    result.heuristic.total_score
                ));
            }
        }

        if threats == 0 && suspicious == 0 {
            report.push_str("\nAll files appear clean.\n");
        }

        report
    }

    /// Generate a JSON report for programmatic consumption (e.g., Flutter frontend).
    pub fn generate_json(results: &[ScanResult]) -> String {
        let entries: Vec<serde_json::Value> = results
            .iter()
            .map(|r| {
                serde_json::json!({
                    "file_path": r.file_path,
                    "sha256": r.sha256,
                    "file_size": r.file_size,
                    "verdict": format!("{}", r.overall),
                    "signature_match": r.signature_match,
                    "heuristic_score": r.heuristic.total_score,
                    "heuristic_verdict": format!("{}", r.heuristic.verdict),
                    "indicators": r.heuristic.indicators.iter().map(|i| {
                        serde_json::json!({
                            "rule": i.rule,
                            "description": i.description,
                            "score": i.score,
                        })
                    }).collect::<Vec<_>>(),
                })
            })
            .collect();

        let report = serde_json::json!({
            "scan_date": Utc::now().to_rfc3339(),
            "total_files": results.len(),
            "clean": results.iter().filter(|r| r.overall == OverallVerdict::Clean).count(),
            "suspicious": results.iter().filter(|r| r.overall == OverallVerdict::Suspicious).count(),
            "threats": results.iter().filter(|r| r.overall == OverallVerdict::Threat).count(),
            "results": entries,
        });

        serde_json::to_string_pretty(&report).unwrap_or_default()
    }
}

fn human_readable_size(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;
    const GB: u64 = MB * 1024;

    if bytes >= GB {
        format!("{:.1} GB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.1} MB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.1} KB", bytes as f64 / KB as f64)
    } else {
        format!("{bytes} B")
    }
}
