use crate::core::event_correlator::Correlation;
use crate::core::event_pipeline::Event;
use crate::core::scanner::ScanResult;
use serde::{Deserialize, Serialize};

/// Computes a composite risk score for files and events.
/// Combines signature match, heuristic score, event correlation, and
/// historical scan data into a single normalized [0.0, 10.0] score.
///
/// Scoring is transparent and explainable — each contributing factor
/// is listed with its weight and contribution.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiskAssessment {
    pub subject: String,
    pub total_score: f64,
    pub level: RiskLevel,
    pub factors: Vec<RiskFactor>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiskFactor {
    pub name: String,
    pub weight: f64,
    pub raw_value: f64,
    pub contribution: f64,
    pub explanation: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum RiskLevel {
    None,
    Low,
    Medium,
    High,
    Critical,
}

impl std::fmt::Display for RiskLevel {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RiskLevel::None => write!(f, "NONE"),
            RiskLevel::Low => write!(f, "LOW"),
            RiskLevel::Medium => write!(f, "MEDIUM"),
            RiskLevel::High => write!(f, "HIGH"),
            RiskLevel::Critical => write!(f, "CRITICAL"),
        }
    }
}

pub struct RiskEngine {
    weights: RiskWeights,
}

#[derive(Debug, Clone)]
pub struct RiskWeights {
    pub signature_match: f64,
    pub heuristic_score: f64,
    pub correlation_score: f64,
    pub repeat_offender: f64,
}

impl Default for RiskWeights {
    fn default() -> Self {
        Self {
            signature_match: 4.0,
            heuristic_score: 3.0,
            correlation_score: 2.0,
            repeat_offender: 1.0,
        }
    }
}

impl RiskEngine {
    pub fn new() -> Self {
        Self {
            weights: RiskWeights::default(),
        }
    }

    pub fn with_weights(weights: RiskWeights) -> Self {
        Self { weights }
    }

    /// Assess risk for a scan result, optionally enriched with correlation data.
    pub fn assess_scan(
        &self,
        scan: &ScanResult,
        correlations: &[Correlation],
        prior_detections: usize,
    ) -> RiskAssessment {
        let mut factors = Vec::new();

        // Factor 1: Signature match
        let sig_raw = if scan.signature_match.is_some() {
            1.0
        } else {
            0.0
        };
        let sig_contribution = sig_raw * self.weights.signature_match;
        factors.push(RiskFactor {
            name: "signature_match".into(),
            weight: self.weights.signature_match,
            raw_value: sig_raw,
            contribution: sig_contribution,
            explanation: if scan.signature_match.is_some() {
                format!(
                    "Matched known signature: {}",
                    scan.signature_match.as_deref().unwrap_or("unknown")
                )
            } else {
                "No signature match".into()
            },
        });

        // Factor 2: Heuristic score (normalized to 0-1 from the raw total)
        let heur_raw = (scan.heuristic.total_score / 2.0).min(1.0);
        let heur_contribution = heur_raw * self.weights.heuristic_score;
        factors.push(RiskFactor {
            name: "heuristic_score".into(),
            weight: self.weights.heuristic_score,
            raw_value: heur_raw,
            contribution: heur_contribution,
            explanation: format!(
                "Heuristic analysis: {} indicator(s), verdict={}",
                scan.heuristic.indicators.len(),
                scan.heuristic.verdict
            ),
        });

        // Factor 3: Correlation context
        let corr_raw = if correlations.is_empty() {
            0.0
        } else {
            (correlations.len() as f64 * 0.3).min(1.0)
        };
        let corr_contribution = corr_raw * self.weights.correlation_score;
        factors.push(RiskFactor {
            name: "correlation_context".into(),
            weight: self.weights.correlation_score,
            raw_value: corr_raw,
            contribution: corr_contribution,
            explanation: if correlations.is_empty() {
                "No correlated events".into()
            } else {
                format!(
                    "{} correlated pattern(s) detected",
                    correlations.len()
                )
            },
        });

        // Factor 4: Repeat offender (file hash seen in previous threats)
        let repeat_raw = (prior_detections as f64 * 0.2).min(1.0);
        let repeat_contribution = repeat_raw * self.weights.repeat_offender;
        factors.push(RiskFactor {
            name: "repeat_offender".into(),
            weight: self.weights.repeat_offender,
            raw_value: repeat_raw,
            contribution: repeat_contribution,
            explanation: if prior_detections == 0 {
                "No prior detections for this hash".into()
            } else {
                format!("Hash previously detected {} time(s)", prior_detections)
            },
        });

        let total_score = factors.iter().map(|f| f.contribution).sum::<f64>().min(10.0);
        let level = Self::score_to_level(total_score);

        RiskAssessment {
            subject: scan.file_path.clone(),
            total_score,
            level,
            factors,
        }
    }

    /// Assess risk for standalone events (not tied to a scan result).
    pub fn assess_event(&self, event: &Event) -> RiskAssessment {
        let base = event.risk_score.min(10.0);
        let level = Self::score_to_level(base);

        RiskAssessment {
            subject: event.source.clone(),
            total_score: base,
            level,
            factors: vec![RiskFactor {
                name: "event_base_score".into(),
                weight: 1.0,
                raw_value: base,
                contribution: base,
                explanation: format!("Event type: {}", event.kind),
            }],
        }
    }

    fn score_to_level(score: f64) -> RiskLevel {
        if score >= 8.0 {
            RiskLevel::Critical
        } else if score >= 5.0 {
            RiskLevel::High
        } else if score >= 3.0 {
            RiskLevel::Medium
        } else if score >= 1.0 {
            RiskLevel::Low
        } else {
            RiskLevel::None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::heuristics::{HeuristicResult, Verdict};

    fn clean_scan() -> ScanResult {
        ScanResult {
            file_path: "/tmp/clean.txt".into(),
            sha256: "abc123".into(),
            file_size: 100,
            signature_match: None,
            signature_severity: None,
            heuristic: HeuristicResult {
                indicators: vec![],
                total_score: 0.0,
                verdict: Verdict::Clean,
            },
            overall: crate::core::scanner::OverallVerdict::Clean,
        }
    }

    #[test]
    fn test_clean_file_low_risk() {
        let engine = RiskEngine::new();
        let assessment = engine.assess_scan(&clean_scan(), &[], 0);
        assert_eq!(assessment.level, RiskLevel::None);
        assert!(assessment.total_score < 1.0);
    }

    #[test]
    fn test_signature_match_high_risk() {
        let engine = RiskEngine::new();
        let mut scan = clean_scan();
        scan.signature_match = Some("EICAR-Test".into());
        let assessment = engine.assess_scan(&scan, &[], 0);
        assert!(assessment.total_score >= 4.0);
    }
}
