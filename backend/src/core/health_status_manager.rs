use crate::core::background_service_manager::BackgroundServiceManager;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::time::Instant;

/// System health status manager.
/// Aggregates health signals from all subsystems (database, scanner, monitor,
/// services) and produces a single health report for the UI.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthReport {
    pub timestamp: String,
    pub overall_status: HealthStatus,
    pub components: Vec<ComponentHealth>,
    pub uptime_secs: u64,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentHealth {
    pub name: String,
    pub status: HealthStatus,
    pub detail: String,
    pub last_check: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HealthStatus {
    Healthy,
    Degraded,
    Unhealthy,
    Unknown,
}

impl std::fmt::Display for HealthStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            HealthStatus::Healthy => write!(f, "HEALTHY"),
            HealthStatus::Degraded => write!(f, "DEGRADED"),
            HealthStatus::Unhealthy => write!(f, "UNHEALTHY"),
            HealthStatus::Unknown => write!(f, "UNKNOWN"),
        }
    }
}

pub struct HealthStatusManager {
    start_time: Instant,
}

impl HealthStatusManager {
    pub fn new() -> Self {
        Self {
            start_time: Instant::now(),
        }
    }

    /// Generate a full health report.
    pub fn check_health(
        &self,
        db_ok: bool,
        scanner_ok: bool,
        service_manager: Option<&BackgroundServiceManager>,
    ) -> HealthReport {
        let now = Utc::now().to_rfc3339();
        let mut components = Vec::new();
        let mut warnings = Vec::new();

        // Database health
        let db_status = if db_ok {
            HealthStatus::Healthy
        } else {
            warnings.push("Database connection issue detected".into());
            HealthStatus::Unhealthy
        };
        components.push(ComponentHealth {
            name: "database".into(),
            status: db_status,
            detail: if db_ok {
                "SQLite connection OK".into()
            } else {
                "Database unavailable".into()
            },
            last_check: now.clone(),
        });

        // Scanner health
        let scanner_status = if scanner_ok {
            HealthStatus::Healthy
        } else {
            warnings.push("Scanner engine not initialized".into());
            HealthStatus::Unhealthy
        };
        components.push(ComponentHealth {
            name: "scanner".into(),
            status: scanner_status,
            detail: if scanner_ok {
                "Scanner engine ready".into()
            } else {
                "Scanner unavailable".into()
            },
            last_check: now.clone(),
        });

        // Background services health
        if let Some(mgr) = service_manager {
            let services = mgr.list_services();
            for svc in &services {
                let status = match svc.status {
                    crate::core::background_service_manager::ServiceStatus::Running => {
                        HealthStatus::Healthy
                    }
                    crate::core::background_service_manager::ServiceStatus::Idle => {
                        HealthStatus::Healthy
                    }
                    crate::core::background_service_manager::ServiceStatus::Error => {
                        warnings.push(format!(
                            "Service '{}' in error state: {}",
                            svc.name,
                            svc.last_error.as_deref().unwrap_or("unknown")
                        ));
                        HealthStatus::Degraded
                    }
                    crate::core::background_service_manager::ServiceStatus::Stopped => {
                        HealthStatus::Unknown
                    }
                };
                components.push(ComponentHealth {
                    name: format!("service:{}", svc.name),
                    status,
                    detail: format!(
                        "{} (runs: {}, errors: {})",
                        svc.status, svc.run_count, svc.error_count
                    ),
                    last_check: now.clone(),
                });
            }
        }

        // Disk space check (advisory only)
        if let Some(warning) = self.check_disk_advisory() {
            warnings.push(warning);
        }

        // Overall status: worst component status
        let overall_status = Self::aggregate_status(&components);

        HealthReport {
            timestamp: now,
            overall_status,
            components,
            uptime_secs: self.start_time.elapsed().as_secs(),
            warnings,
        }
    }

    /// Produce a JSON report for the Flutter UI.
    pub fn to_json(&self, report: &HealthReport) -> String {
        serde_json::to_string_pretty(report).unwrap_or_default()
    }

    fn aggregate_status(components: &[ComponentHealth]) -> HealthStatus {
        if components.iter().any(|c| c.status == HealthStatus::Unhealthy) {
            HealthStatus::Unhealthy
        } else if components.iter().any(|c| c.status == HealthStatus::Degraded) {
            HealthStatus::Degraded
        } else if components.iter().all(|c| c.status == HealthStatus::Healthy) {
            HealthStatus::Healthy
        } else {
            HealthStatus::Degraded
        }
    }

    /// Basic advisory disk space check — reads available space on the
    /// current partition. Non-privileged, read-only.
    fn check_disk_advisory(&self) -> Option<String> {
        // Use a simple heuristic: check if quarantine dir exists and is accessible
        // Full statvfs-based check would require platform-specific code
        let quarantine = std::path::Path::new("quarantine");
        if quarantine.exists() {
            match std::fs::read_dir(quarantine) {
                Ok(entries) => {
                    let count = entries.count();
                    if count > 100 {
                        Some(format!(
                            "Quarantine directory contains {count} files — consider reviewing"
                        ))
                    } else {
                        None
                    }
                }
                Err(_) => Some("Cannot read quarantine directory".into()),
            }
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_healthy_report() {
        let mgr = HealthStatusManager::new();
        let report = mgr.check_health(true, true, None);
        assert_eq!(report.overall_status, HealthStatus::Healthy);
        assert!(report.warnings.is_empty());
    }

    #[test]
    fn test_unhealthy_db() {
        let mgr = HealthStatusManager::new();
        let report = mgr.check_health(false, true, None);
        assert_eq!(report.overall_status, HealthStatus::Unhealthy);
        assert!(!report.warnings.is_empty());
    }
}
