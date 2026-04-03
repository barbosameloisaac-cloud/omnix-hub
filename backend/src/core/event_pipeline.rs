use log::info;
use serde::{Deserialize, Serialize};
use std::sync::Mutex;

/// Central event pipeline through which all security-relevant events flow.
/// Supports submission, buffering, and consumption by downstream processors
/// (deduplicator, correlator, risk engine).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Event {
    pub id: String,
    pub kind: EventKind,
    pub source: String,
    pub detail: String,
    pub timestamp: String,
    pub risk_score: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum EventKind {
    FileCreated,
    FileModified,
    FileDeleted,
    FileScanned,
    ThreatDetected,
    QuarantineAction,
    SignatureUpdate,
    HealthCheck,
    SystemWarning,
}

impl std::fmt::Display for EventKind {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            EventKind::FileCreated => write!(f, "FILE_CREATED"),
            EventKind::FileModified => write!(f, "FILE_MODIFIED"),
            EventKind::FileDeleted => write!(f, "FILE_DELETED"),
            EventKind::FileScanned => write!(f, "FILE_SCANNED"),
            EventKind::ThreatDetected => write!(f, "THREAT_DETECTED"),
            EventKind::QuarantineAction => write!(f, "QUARANTINE_ACTION"),
            EventKind::SignatureUpdate => write!(f, "SIGNATURE_UPDATE"),
            EventKind::HealthCheck => write!(f, "HEALTH_CHECK"),
            EventKind::SystemWarning => write!(f, "SYSTEM_WARNING"),
        }
    }
}

pub struct EventPipeline {
    buffer: Mutex<Vec<Event>>,
    max_buffer_size: usize,
}

impl EventPipeline {
    pub fn new(max_buffer_size: usize) -> Self {
        Self {
            buffer: Mutex::new(Vec::new()),
            max_buffer_size,
        }
    }

    /// Submit an event to the pipeline.
    pub fn submit(&self, event: Event) -> Result<(), String> {
        let mut buf = self.buffer.lock().map_err(|e| e.to_string())?;
        if buf.len() >= self.max_buffer_size {
            // Drop oldest event to make room (ring-buffer behavior)
            buf.remove(0);
        }
        info!("[EVENT] {} from {}", event.kind, event.source);
        buf.push(event);
        Ok(())
    }

    /// Drain all buffered events for processing.
    pub fn drain(&self) -> Result<Vec<Event>, String> {
        let mut buf = self.buffer.lock().map_err(|e| e.to_string())?;
        Ok(buf.drain(..).collect())
    }

    /// Peek at buffered events without consuming them.
    pub fn peek(&self) -> Result<Vec<Event>, String> {
        let buf = self.buffer.lock().map_err(|e| e.to_string())?;
        Ok(buf.clone())
    }

    /// Number of events currently buffered.
    pub fn pending_count(&self) -> usize {
        self.buffer.lock().map(|b| b.len()).unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    fn make_event(kind: EventKind) -> Event {
        Event {
            id: Uuid::new_v4().to_string(),
            kind,
            source: "test".into(),
            detail: "test event".into(),
            timestamp: "2026-01-01T00:00:00Z".into(),
            risk_score: 0.0,
        }
    }

    #[test]
    fn test_submit_and_drain() {
        let pipeline = EventPipeline::new(100);
        pipeline.submit(make_event(EventKind::FileCreated)).unwrap();
        pipeline.submit(make_event(EventKind::FileModified)).unwrap();
        assert_eq!(pipeline.pending_count(), 2);
        let events = pipeline.drain().unwrap();
        assert_eq!(events.len(), 2);
        assert_eq!(pipeline.pending_count(), 0);
    }

    #[test]
    fn test_buffer_overflow_drops_oldest() {
        let pipeline = EventPipeline::new(2);
        pipeline.submit(make_event(EventKind::FileCreated)).unwrap();
        pipeline.submit(make_event(EventKind::FileModified)).unwrap();
        pipeline.submit(make_event(EventKind::FileDeleted)).unwrap();
        let events = pipeline.drain().unwrap();
        assert_eq!(events.len(), 2);
        assert_eq!(events[0].kind, EventKind::FileModified);
        assert_eq!(events[1].kind, EventKind::FileDeleted);
    }
}
