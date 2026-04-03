use log::{info, warn};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Instant;

/// Application-level background service manager.
/// Tracks named services (monitor, pipeline processor, health checker, etc.)
/// with their running state, schedule, and last execution time.
///
/// This does NOT spawn OS-level daemons or system services.
/// It manages in-process task lifecycle for the application.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceInfo {
    pub name: String,
    pub description: String,
    pub status: ServiceStatus,
    pub interval_secs: u64,
    pub last_run: Option<String>,
    pub run_count: u64,
    pub error_count: u64,
    pub last_error: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ServiceStatus {
    Idle,
    Running,
    Stopped,
    Error,
}

impl std::fmt::Display for ServiceStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ServiceStatus::Idle => write!(f, "IDLE"),
            ServiceStatus::Running => write!(f, "RUNNING"),
            ServiceStatus::Stopped => write!(f, "STOPPED"),
            ServiceStatus::Error => write!(f, "ERROR"),
        }
    }
}

pub struct BackgroundServiceManager {
    services: Mutex<HashMap<String, ManagedService>>,
}

struct ManagedService {
    info: ServiceInfo,
    stop_flag: Arc<AtomicBool>,
    started_at: Option<Instant>,
}

impl BackgroundServiceManager {
    pub fn new() -> Self {
        Self {
            services: Mutex::new(HashMap::new()),
        }
    }

    /// Register a new service with the manager.
    pub fn register(
        &self,
        name: &str,
        description: &str,
        interval_secs: u64,
    ) -> Arc<AtomicBool> {
        let stop_flag = Arc::new(AtomicBool::new(false));
        let service = ManagedService {
            info: ServiceInfo {
                name: name.into(),
                description: description.into(),
                status: ServiceStatus::Idle,
                interval_secs,
                last_run: None,
                run_count: 0,
                error_count: 0,
                last_error: None,
            },
            stop_flag: Arc::clone(&stop_flag),
            started_at: None,
        };

        let mut services = self.services.lock().unwrap();
        services.insert(name.into(), service);
        info!("Registered background service: {name}");
        stop_flag
    }

    /// Mark a service as running.
    pub fn mark_running(&self, name: &str) {
        let mut services = self.services.lock().unwrap();
        if let Some(svc) = services.get_mut(name) {
            svc.info.status = ServiceStatus::Running;
            svc.started_at = Some(Instant::now());
        }
    }

    /// Record a successful execution cycle.
    pub fn record_cycle(&self, name: &str) {
        let mut services = self.services.lock().unwrap();
        if let Some(svc) = services.get_mut(name) {
            svc.info.run_count += 1;
            svc.info.last_run = Some(chrono::Utc::now().to_rfc3339());
        }
    }

    /// Record an error in a service.
    pub fn record_error(&self, name: &str, error: &str) {
        let mut services = self.services.lock().unwrap();
        if let Some(svc) = services.get_mut(name) {
            svc.info.error_count += 1;
            svc.info.last_error = Some(error.into());
            svc.info.status = ServiceStatus::Error;
            warn!("Service '{name}' error: {error}");
        }
    }

    /// Stop a service by name.
    pub fn stop(&self, name: &str) -> bool {
        let mut services = self.services.lock().unwrap();
        if let Some(svc) = services.get_mut(name) {
            svc.stop_flag.store(true, Ordering::Relaxed);
            svc.info.status = ServiceStatus::Stopped;
            info!("Stopped service: {name}");
            true
        } else {
            false
        }
    }

    /// Stop all registered services.
    pub fn stop_all(&self) {
        let mut services = self.services.lock().unwrap();
        for (name, svc) in services.iter_mut() {
            svc.stop_flag.store(true, Ordering::Relaxed);
            svc.info.status = ServiceStatus::Stopped;
            info!("Stopped service: {name}");
        }
    }

    /// Check if a service should stop.
    pub fn should_stop(&self, name: &str) -> bool {
        let services = self.services.lock().unwrap();
        services
            .get(name)
            .map(|svc| svc.stop_flag.load(Ordering::Relaxed))
            .unwrap_or(true)
    }

    /// Get info for all registered services.
    pub fn list_services(&self) -> Vec<ServiceInfo> {
        let services = self.services.lock().unwrap();
        services.values().map(|svc| svc.info.clone()).collect()
    }

    /// Get info for a specific service.
    pub fn get_service(&self, name: &str) -> Option<ServiceInfo> {
        let services = self.services.lock().unwrap();
        services.get(name).map(|svc| svc.info.clone())
    }

    /// Get uptime in seconds for a running service.
    pub fn uptime_secs(&self, name: &str) -> Option<u64> {
        let services = self.services.lock().unwrap();
        services
            .get(name)
            .and_then(|svc| svc.started_at.map(|s| s.elapsed().as_secs()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_register_and_stop() {
        let mgr = BackgroundServiceManager::new();
        let _flag = mgr.register("test-svc", "A test service", 60);
        assert!(!mgr.should_stop("test-svc"));
        mgr.mark_running("test-svc");

        let info = mgr.get_service("test-svc").unwrap();
        assert_eq!(info.status, ServiceStatus::Running);

        mgr.stop("test-svc");
        assert!(mgr.should_stop("test-svc"));
    }

    #[test]
    fn test_record_cycles() {
        let mgr = BackgroundServiceManager::new();
        mgr.register("counter", "Counting service", 10);
        mgr.record_cycle("counter");
        mgr.record_cycle("counter");
        let info = mgr.get_service("counter").unwrap();
        assert_eq!(info.run_count, 2);
    }
}
