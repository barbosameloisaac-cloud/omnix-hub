/**
 * OmniShield — Futuristic Dashboard Controller
 * Handles all UI interactions, API communication, and real-time updates.
 */

const API_BASE = window.location.origin;
let autoQuarantine = false;
let scanPollingInterval = null;

// ── Utility ──────────────────────────────────────────────────────────────────
function timestamp() {
    return new Date().toLocaleTimeString('en-US', { hour12: false });
}

function logActivity(message, type = 'info') {
    const feed = document.getElementById('activityFeed');
    const colors = {
        info: 'var(--text-secondary)',
        success: 'var(--neon-green)',
        warning: 'var(--neon-yellow)',
        danger: 'var(--neon-red)',
        scan: 'var(--neon-cyan)',
    };
    const item = document.createElement('div');
    item.className = 'activity-item';
    item.innerHTML = `
        <span class="activity-time">${timestamp()}</span>
        <span class="activity-message" style="color: ${colors[type] || colors.info}">${message}</span>
    `;
    feed.insertBefore(item, feed.firstChild);

    // Keep only last 100 entries
    while (feed.children.length > 100) {
        feed.removeChild(feed.lastChild);
    }
}

function clearActivity() {
    document.getElementById('activityFeed').innerHTML = '';
    logActivity('Activity log cleared.');
}

async function apiCall(endpoint, method = 'GET', body = null) {
    const options = {
        method,
        headers: { 'Content-Type': 'application/json' },
    };
    if (body) options.body = JSON.stringify(body);

    try {
        const response = await fetch(`${API_BASE}${endpoint}`, options);
        if (!response.ok) {
            const err = await response.json().catch(() => ({}));
            throw new Error(err.detail || `HTTP ${response.status}`);
        }
        return await response.json();
    } catch (error) {
        logActivity(`API Error: ${error.message}`, 'danger');
        throw error;
    }
}

// ── Dashboard Updates ────────────────────────────────────────────────────────
async function refreshDashboard() {
    try {
        const [status, stats] = await Promise.all([
            apiCall('/api/status'),
            apiCall('/api/stats'),
        ]);

        // Update stats
        document.getElementById('statFilesScanned').textContent =
            formatNumber(stats.total_files_scanned);
        document.getElementById('statThreats').textContent =
            formatNumber(stats.total_threats_detected);
        document.getElementById('statQuarantined').textContent =
            formatNumber(stats.total_quarantined);
        document.getElementById('statTotalScans').textContent =
            formatNumber(stats.total_scans);

        // Update engine info
        const engines = status.engines;
        if (engines.signature_engine) {
            document.getElementById('sigCount').textContent =
                `${engines.signature_engine.signatures_loaded} signatures`;
        }
        if (engines.heuristic_engine) {
            document.getElementById('heurCount').textContent =
                `${engines.heuristic_engine.rules_loaded} rule sets`;
        }

        // Update system status
        updateSystemStatus(status, stats);

    } catch (e) {
        // API not available yet
    }
}

function formatNumber(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
    return String(n);
}

function updateSystemStatus(status, stats) {
    const badge = document.getElementById('statusBadge');
    const text = document.getElementById('statusText');

    if (status.scan_active) {
        badge.className = 'status-badge scanning';
        text.textContent = 'Scanning...';
    } else if (stats.total_threats_detected > 0 && stats.total_quarantined < stats.total_threats_detected) {
        badge.className = 'status-badge threat';
        text.textContent = 'Threats Detected';
    } else {
        badge.className = 'status-badge protected';
        text.textContent = 'System Protected';
    }
}

// ── Scanning ─────────────────────────────────────────────────────────────────
async function startDirectoryScan() {
    const path = document.getElementById('scanPath').value.trim();
    if (!path) {
        logActivity('Please enter a directory path to scan.', 'warning');
        return;
    }

    try {
        logActivity(`Starting directory scan: ${path}`, 'scan');
        await apiCall('/api/scan/directory', 'POST', {
            path,
            recursive: true,
            auto_quarantine: autoQuarantine,
            scan_all_files: false,
        });
        showProgress();
        startProgressPolling();
    } catch (e) {
        logActivity(`Failed to start scan: ${e.message}`, 'danger');
    }
}

async function startQuickScan() {
    try {
        logActivity('Starting quick scan of common locations...', 'scan');
        await apiCall('/api/scan/quick', 'POST', {
            auto_quarantine: autoQuarantine,
        });
        showProgress();
        startProgressPolling();
    } catch (e) {
        logActivity(`Failed to start quick scan: ${e.message}`, 'danger');
    }
}

async function scanSingleFile() {
    const path = document.getElementById('scanFilePath').value.trim();
    if (!path) {
        logActivity('Please enter a file path to scan.', 'warning');
        return;
    }

    try {
        logActivity(`Scanning file: ${path}`, 'scan');
        const result = await apiCall('/api/scan/file', 'POST', {
            path,
            auto_quarantine: autoQuarantine,
        });

        if (result.clean) {
            logActivity(`File is CLEAN: ${path} (${result.scan_time_ms}ms)`, 'success');
        } else {
            logActivity(
                `THREAT DETECTED in ${path} — ${result.risk_level.toUpperCase()} ` +
                `(score: ${result.risk_score})`, 'danger'
            );
        }

        refreshDashboard();
        refreshThreats();
    } catch (e) {
        logActivity(`Scan error: ${e.message}`, 'danger');
    }
}

async function abortScan() {
    try {
        await apiCall('/api/scan/abort', 'POST');
        logActivity('Scan abort requested.', 'warning');
    } catch (e) {
        logActivity(`Abort error: ${e.message}`, 'danger');
    }
}

function showProgress() {
    document.getElementById('progressContainer').style.display = 'flex';
}

function hideProgress() {
    document.getElementById('progressContainer').style.display = 'none';
}

function startProgressPolling() {
    if (scanPollingInterval) clearInterval(scanPollingInterval);
    scanPollingInterval = setInterval(pollProgress, 800);
}

async function pollProgress() {
    try {
        const progress = await apiCall('/api/scan/progress');

        // Update ring
        const percent = progress.progress_percent || 0;
        const ring = document.getElementById('progressRing');
        const circumference = 2 * Math.PI * 36;
        ring.style.strokeDashoffset = circumference - (percent / 100) * circumference;
        document.getElementById('progressPercent').textContent = `${Math.round(percent)}%`;

        // Update text
        document.getElementById('scanStatusText').textContent =
            progress.status ? progress.status.toUpperCase() : 'SCANNING';
        document.getElementById('currentFile').textContent =
            progress.current_file || 'Processing...';
        document.getElementById('scannedCount').textContent = progress.scanned_files || 0;
        document.getElementById('totalCount').textContent = progress.total_files || 0;
        document.getElementById('threatsCount').textContent = progress.threats_found || 0;

        if (progress.status === 'completed' || progress.status === 'aborted') {
            clearInterval(scanPollingInterval);
            scanPollingInterval = null;

            const msg = progress.status === 'completed'
                ? `Scan completed: ${progress.scanned_files} files scanned, ` +
                  `${progress.threats_found} threats found (${progress.elapsed_seconds}s)`
                : 'Scan aborted by user.';
            const type = progress.threats_found > 0 ? 'danger' : 'success';
            logActivity(msg, progress.status === 'aborted' ? 'warning' : type);

            setTimeout(() => {
                hideProgress();
                refreshDashboard();
                refreshThreats();
                refreshQuarantine();
            }, 2000);
        }
    } catch (e) {
        // API temporarily unavailable
    }
}

// ── Auto-Quarantine Toggle ───────────────────────────────────────────────────
function toggleAutoQuarantine() {
    autoQuarantine = !autoQuarantine;
    const toggle = document.getElementById('toggleQuarantine');
    toggle.classList.toggle('active', autoQuarantine);
    logActivity(
        `Auto-quarantine ${autoQuarantine ? 'ENABLED' : 'DISABLED'}`,
        autoQuarantine ? 'success' : 'info'
    );
}

// ── Real-Time Monitor ────────────────────────────────────────────────────────
async function startMonitor() {
    const path = document.getElementById('monitorPath').value.trim();
    const paths = path ? [path] : null;

    try {
        logActivity('Starting real-time protection...', 'scan');
        const result = await apiCall('/api/monitor/start', 'POST', {
            paths,
            auto_quarantine: autoQuarantine,
        });
        updateMonitorUI(result.status);
        logActivity('Real-time protection ACTIVE', 'success');
    } catch (e) {
        logActivity(`Monitor error: ${e.message}`, 'danger');
    }
}

async function stopMonitor() {
    try {
        await apiCall('/api/monitor/stop', 'POST');
        updateMonitorUI({ running: false, monitored_paths: [] });
        logActivity('Real-time protection STOPPED', 'warning');
    } catch (e) {
        logActivity(`Monitor error: ${e.message}`, 'danger');
    }
}

function updateMonitorUI(status) {
    const container = document.getElementById('monitorStatus');
    const label = document.getElementById('monitorLabel');
    const btnStart = document.getElementById('btnStartMonitor');
    const btnStop = document.getElementById('btnStopMonitor');
    const pathsContainer = document.getElementById('monitorPaths');

    if (status.running) {
        container.className = 'monitor-status active';
        label.textContent = 'Protection Active';
        btnStart.style.display = 'none';
        btnStop.style.display = 'inline-flex';

        pathsContainer.innerHTML = status.monitored_paths.map(p =>
            `<div class="monitor-path-item">${escapeHtml(p)}</div>`
        ).join('');
    } else {
        container.className = 'monitor-status inactive';
        label.textContent = 'Protection Inactive';
        btnStart.style.display = 'inline-flex';
        btnStop.style.display = 'none';
        pathsContainer.innerHTML = '';
    }
}

// ── Threat History ───────────────────────────────────────────────────────────
async function refreshThreats() {
    try {
        const threats = await apiCall('/api/threats?limit=50');
        const list = document.getElementById('threatList');

        if (!threats || threats.length === 0) {
            list.innerHTML = `
                <div class="empty-state">
                    <div class="icon">&#9737;</div>
                    <p>No threats detected yet. Run a scan to begin.</p>
                </div>`;
            return;
        }

        list.innerHTML = threats.map(t => `
            <div class="threat-item">
                <div class="threat-severity ${t.severity || 'medium'}"></div>
                <div class="threat-info">
                    <div class="threat-name">${escapeHtml(t.threat_name)}</div>
                    <div class="threat-path">${escapeHtml(t.file_path)}</div>
                </div>
                <span class="threat-badge ${t.severity || 'suspicious'}">
                    ${(t.severity || 'unknown').toUpperCase()}
                </span>
            </div>
        `).join('');
    } catch (e) {
        // API not ready
    }
}

// ── Quarantine Vault ─────────────────────────────────────────────────────────
async function refreshQuarantine() {
    try {
        const items = await apiCall('/api/quarantine');
        const list = document.getElementById('quarantineList');

        if (!items || items.length === 0) {
            list.innerHTML = `
                <div class="empty-state">
                    <div class="icon">&#128274;</div>
                    <p>Quarantine vault is empty.</p>
                </div>`;
            return;
        }

        list.innerHTML = items.map(q => `
            <div class="quarantine-item">
                <div class="quarantine-info">
                    <div class="quarantine-name">${escapeHtml(q.threat_name || 'Unknown')}</div>
                    <div class="quarantine-path">${escapeHtml(q.original_path)}</div>
                </div>
                <div class="quarantine-actions">
                    <button class="btn btn-ghost btn-sm" onclick="restoreFile(${q.id})">Restore</button>
                    <button class="btn btn-danger btn-sm" onclick="deleteQuarantined(${q.id})">Delete</button>
                </div>
            </div>
        `).join('');
    } catch (e) {
        // API not ready
    }
}

async function restoreFile(id) {
    try {
        const result = await apiCall('/api/quarantine/restore', 'POST', { quarantine_id: id });
        logActivity(`File restored: ${result.path}`, 'success');
        refreshQuarantine();
        refreshDashboard();
    } catch (e) {
        logActivity(`Restore failed: ${e.message}`, 'danger');
    }
}

async function deleteQuarantined(id) {
    try {
        await apiCall('/api/quarantine/delete', 'POST', { quarantine_id: id });
        logActivity('Quarantined file permanently deleted.', 'warning');
        refreshQuarantine();
        refreshDashboard();
    } catch (e) {
        logActivity(`Delete failed: ${e.message}`, 'danger');
    }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text || '';
    return div.innerHTML;
}

// ── Initialization ───────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    logActivity('OmniShield NeonCore v1.0.0 initialized.', 'success');
    logActivity('Detection engines: Signatures | Heuristics | Entropy | File Analyzer', 'info');
    logActivity('Ready for commands. Enter a path and scan.', 'info');

    // Initial data load
    refreshDashboard();
    refreshThreats();
    refreshQuarantine();

    // Check monitor status
    apiCall('/api/monitor/status').then(updateMonitorUI).catch(() => {});

    // Auto-refresh every 10 seconds
    setInterval(refreshDashboard, 10000);
});
