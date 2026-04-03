use crate::core::event_pipeline::{Event, EventKind};
use serde::{Deserialize, Serialize};

/// Correlates related events to detect compound patterns.
/// For example: rapid file modifications in the same directory may indicate
/// bulk file encryption (a defensive signal worth surfacing to the user).
///
/// All correlation is purely observational and advisory — no blocking or
/// automated response.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Correlation {
    pub id: String,
    pub pattern: CorrelationPattern,
    pub involved_events: Vec<String>, // event IDs
    pub description: String,
    pub combined_risk: f64,
    pub timestamp: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CorrelationPattern {
    /// Many files modified in quick succession in the same directory
    RapidBulkModification,
    /// A file was created and immediately deleted
    CreateThenDelete,
    /// Multiple threats detected in the same directory
    ClusteredThreats,
    /// File created with a suspicious extension right after a scan
    PostScanCreation,
}

impl std::fmt::Display for CorrelationPattern {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CorrelationPattern::RapidBulkModification => write!(f, "RAPID_BULK_MODIFICATION"),
            CorrelationPattern::CreateThenDelete => write!(f, "CREATE_THEN_DELETE"),
            CorrelationPattern::ClusteredThreats => write!(f, "CLUSTERED_THREATS"),
            CorrelationPattern::PostScanCreation => write!(f, "POST_SCAN_CREATION"),
        }
    }
}

pub struct EventCorrelator {
    /// Minimum events in a window to trigger bulk modification detection
    bulk_threshold: usize,
    /// Time window in seconds for correlating related events
    window_secs: i64,
}

impl EventCorrelator {
    pub fn new(bulk_threshold: usize, window_secs: i64) -> Self {
        Self {
            bulk_threshold,
            window_secs,
        }
    }

    /// Analyze a batch of events for correlation patterns.
    pub fn correlate(&self, events: &[Event]) -> Vec<Correlation> {
        let mut correlations = Vec::new();

        self.detect_bulk_modifications(events, &mut correlations);
        self.detect_create_then_delete(events, &mut correlations);
        self.detect_clustered_threats(events, &mut correlations);

        correlations
    }

    fn detect_bulk_modifications(&self, events: &[Event], out: &mut Vec<Correlation>) {
        use std::collections::HashMap;

        // Group FileModified events by parent directory
        let mut by_dir: HashMap<String, Vec<&Event>> = HashMap::new();
        for event in events {
            if event.kind == EventKind::FileModified {
                let dir = parent_dir(&event.source);
                by_dir.entry(dir).or_default().push(event);
            }
        }

        for (dir, dir_events) in &by_dir {
            if dir_events.len() >= self.bulk_threshold {
                // Check that they're within the time window
                if self.events_within_window(dir_events) {
                    out.push(Correlation {
                        id: uuid::Uuid::new_v4().to_string(),
                        pattern: CorrelationPattern::RapidBulkModification,
                        involved_events: dir_events.iter().map(|e| e.id.clone()).collect(),
                        description: format!(
                            "{} files modified rapidly in directory '{}'",
                            dir_events.len(),
                            dir
                        ),
                        combined_risk: 0.3 * dir_events.len() as f64,
                        timestamp: chrono::Utc::now().to_rfc3339(),
                    });
                }
            }
        }
    }

    fn detect_create_then_delete(&self, events: &[Event], out: &mut Vec<Correlation>) {
        use std::collections::HashMap;

        let mut created: HashMap<&str, &Event> = HashMap::new();
        for event in events {
            if event.kind == EventKind::FileCreated {
                created.insert(&event.source, event);
            }
        }

        for event in events {
            if event.kind == EventKind::FileDeleted {
                if let Some(create_event) = created.get(event.source.as_str()) {
                    if self.two_events_within_window(create_event, event) {
                        out.push(Correlation {
                            id: uuid::Uuid::new_v4().to_string(),
                            pattern: CorrelationPattern::CreateThenDelete,
                            involved_events: vec![
                                create_event.id.clone(),
                                event.id.clone(),
                            ],
                            description: format!(
                                "File '{}' was created and quickly deleted",
                                event.source
                            ),
                            combined_risk: 0.5,
                            timestamp: chrono::Utc::now().to_rfc3339(),
                        });
                    }
                }
            }
        }
    }

    fn detect_clustered_threats(&self, events: &[Event], out: &mut Vec<Correlation>) {
        use std::collections::HashMap;

        let mut by_dir: HashMap<String, Vec<&Event>> = HashMap::new();
        for event in events {
            if event.kind == EventKind::ThreatDetected {
                let dir = parent_dir(&event.source);
                by_dir.entry(dir).or_default().push(event);
            }
        }

        for (dir, dir_events) in &by_dir {
            if dir_events.len() >= 2 {
                out.push(Correlation {
                    id: uuid::Uuid::new_v4().to_string(),
                    pattern: CorrelationPattern::ClusteredThreats,
                    involved_events: dir_events.iter().map(|e| e.id.clone()).collect(),
                    description: format!(
                        "{} threats detected in directory '{}'",
                        dir_events.len(),
                        dir
                    ),
                    combined_risk: 0.5 * dir_events.len() as f64,
                    timestamp: chrono::Utc::now().to_rfc3339(),
                });
            }
        }
    }

    fn events_within_window(&self, events: &[&Event]) -> bool {
        if events.len() < 2 {
            return false;
        }
        let timestamps: Vec<_> = events
            .iter()
            .filter_map(|e| chrono::DateTime::parse_from_rfc3339(&e.timestamp).ok())
            .collect();
        if timestamps.len() < 2 {
            return false;
        }
        let min = timestamps.iter().min().unwrap();
        let max = timestamps.iter().max().unwrap();
        (*max - *min).num_seconds() <= self.window_secs
    }

    fn two_events_within_window(&self, a: &Event, b: &Event) -> bool {
        let pa = chrono::DateTime::parse_from_rfc3339(&a.timestamp);
        let pb = chrono::DateTime::parse_from_rfc3339(&b.timestamp);
        match (pa, pb) {
            (Ok(ta), Ok(tb)) => (tb - ta).num_seconds().abs() <= self.window_secs,
            _ => false,
        }
    }
}

fn parent_dir(path: &str) -> String {
    std::path::Path::new(path)
        .parent()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|| ".".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_event(kind: EventKind, source: &str, ts: &str) -> Event {
        Event {
            id: uuid::Uuid::new_v4().to_string(),
            kind,
            source: source.into(),
            detail: "test".into(),
            timestamp: ts.into(),
            risk_score: 0.0,
        }
    }

    #[test]
    fn test_bulk_modification_detection() {
        let correlator = EventCorrelator::new(3, 60);
        let events = vec![
            make_event(EventKind::FileModified, "/data/a.txt", "2026-01-01T00:00:00+00:00"),
            make_event(EventKind::FileModified, "/data/b.txt", "2026-01-01T00:00:10+00:00"),
            make_event(EventKind::FileModified, "/data/c.txt", "2026-01-01T00:00:20+00:00"),
        ];
        let correlations = correlator.correlate(&events);
        assert_eq!(correlations.len(), 1);
        assert_eq!(correlations[0].pattern, CorrelationPattern::RapidBulkModification);
    }
}
