use crate::core::event_pipeline::Event;
use std::collections::HashMap;

/// Deduplicates events within a time window to prevent flooding.
/// Two events are considered duplicates if they share the same kind + source
/// and occur within `window_secs` of each other.
pub struct EventDeduplicator {
    window_secs: i64,
    seen: HashMap<String, String>, // dedup_key -> last timestamp
}

impl EventDeduplicator {
    pub fn new(window_secs: i64) -> Self {
        Self {
            window_secs,
            seen: HashMap::new(),
        }
    }

    /// Filter a batch of events, removing duplicates within the time window.
    pub fn deduplicate(&mut self, events: Vec<Event>) -> Vec<Event> {
        let mut result = Vec::new();

        for event in events {
            let key = Self::dedup_key(&event);

            if let Some(last_ts) = self.seen.get(&key) {
                if Self::within_window(last_ts, &event.timestamp, self.window_secs) {
                    continue; // duplicate, skip
                }
            }

            self.seen.insert(key, event.timestamp.clone());
            result.push(event);
        }

        result
    }

    /// Purge entries older than the window to prevent unbounded growth.
    pub fn purge_old(&mut self, current_time: &str) {
        self.seen
            .retain(|_, ts| !Self::older_than(ts, current_time, self.window_secs * 2));
    }

    pub fn tracked_keys(&self) -> usize {
        self.seen.len()
    }

    fn dedup_key(event: &Event) -> String {
        format!("{}:{}", event.kind, event.source)
    }

    fn within_window(ts_a: &str, ts_b: &str, window_secs: i64) -> bool {
        let parse_a = chrono::DateTime::parse_from_rfc3339(ts_a);
        let parse_b = chrono::DateTime::parse_from_rfc3339(ts_b);
        match (parse_a, parse_b) {
            (Ok(a), Ok(b)) => (b - a).num_seconds().abs() < window_secs,
            _ => false,
        }
    }

    fn older_than(ts: &str, current: &str, threshold_secs: i64) -> bool {
        let parse_ts = chrono::DateTime::parse_from_rfc3339(ts);
        let parse_cur = chrono::DateTime::parse_from_rfc3339(current);
        match (parse_ts, parse_cur) {
            (Ok(t), Ok(c)) => (c - t).num_seconds() > threshold_secs,
            _ => false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::event_pipeline::EventKind;

    fn make_event(source: &str, ts: &str) -> Event {
        Event {
            id: uuid::Uuid::new_v4().to_string(),
            kind: EventKind::FileModified,
            source: source.into(),
            detail: "test".into(),
            timestamp: ts.into(),
            risk_score: 0.0,
        }
    }

    #[test]
    fn test_dedup_within_window() {
        let mut dedup = EventDeduplicator::new(60);
        let events = vec![
            make_event("/tmp/a.txt", "2026-01-01T00:00:00+00:00"),
            make_event("/tmp/a.txt", "2026-01-01T00:00:30+00:00"), // within 60s
            make_event("/tmp/b.txt", "2026-01-01T00:00:30+00:00"), // different source
        ];
        let result = dedup.deduplicate(events);
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn test_dedup_outside_window() {
        let mut dedup = EventDeduplicator::new(60);
        let events = vec![
            make_event("/tmp/a.txt", "2026-01-01T00:00:00+00:00"),
            make_event("/tmp/a.txt", "2026-01-01T00:02:00+00:00"), // 120s later
        ];
        let result = dedup.deduplicate(events);
        assert_eq!(result.len(), 2);
    }
}
