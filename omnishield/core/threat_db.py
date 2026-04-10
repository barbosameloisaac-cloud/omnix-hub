"""
OmniShield Threat Database
SQLite-backed persistent storage for scan history, threat records,
and quarantine metadata. Designed for minimal footprint on all platforms.
"""

import json
import sqlite3
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from omnishield.config.settings import THREAT_DB_PATH


class ThreatRecord:
    """A single threat detection record."""

    def __init__(self, file_path: str, file_hash: str, threat_name: str,
                 threat_category: str, severity: str, detection_method: str,
                 score: int, details: Optional[dict] = None,
                 action_taken: str = "none", timestamp: Optional[str] = None):
        self.file_path = file_path
        self.file_hash = file_hash
        self.threat_name = threat_name
        self.threat_category = threat_category
        self.severity = severity
        self.detection_method = detection_method
        self.score = score
        self.details = details or {}
        self.action_taken = action_taken
        self.timestamp = timestamp or datetime.now(timezone.utc).isoformat()

    def to_dict(self) -> dict:
        return {
            "file_path": self.file_path,
            "file_hash": self.file_hash,
            "threat_name": self.threat_name,
            "threat_category": self.threat_category,
            "severity": self.severity,
            "detection_method": self.detection_method,
            "score": self.score,
            "details": self.details,
            "action_taken": self.action_taken,
            "timestamp": self.timestamp,
        }


class ScanRecord:
    """A scan session record."""

    def __init__(self, scan_id: str, scan_type: str, target_path: str,
                 files_scanned: int = 0, threats_found: int = 0,
                 duration_seconds: float = 0, status: str = "running"):
        self.scan_id = scan_id
        self.scan_type = scan_type
        self.target_path = target_path
        self.files_scanned = files_scanned
        self.threats_found = threats_found
        self.duration_seconds = duration_seconds
        self.status = status
        self.started_at = datetime.now(timezone.utc).isoformat()
        self.completed_at: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "scan_id": self.scan_id,
            "scan_type": self.scan_type,
            "target_path": self.target_path,
            "files_scanned": self.files_scanned,
            "threats_found": self.threats_found,
            "duration_seconds": round(self.duration_seconds, 2),
            "status": self.status,
            "started_at": self.started_at,
            "completed_at": self.completed_at,
        }


class ThreatDatabase:
    """SQLite-backed threat and scan history database."""

    def __init__(self, db_path: Optional[Path] = None):
        self.db_path = str(db_path or THREAT_DB_PATH)
        self._local = threading.local()
        self._init_db()

    @property
    def _conn(self) -> sqlite3.Connection:
        if not hasattr(self._local, "conn") or self._local.conn is None:
            self._local.conn = sqlite3.connect(self.db_path)
            self._local.conn.row_factory = sqlite3.Row
            self._local.conn.execute("PRAGMA journal_mode=WAL")
        return self._local.conn

    def _init_db(self):
        """Initialize database schema."""
        conn = self._conn
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS threats (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_path TEXT NOT NULL,
                file_hash TEXT,
                threat_name TEXT NOT NULL,
                threat_category TEXT,
                severity TEXT,
                detection_method TEXT,
                score INTEGER DEFAULT 0,
                details TEXT,
                action_taken TEXT DEFAULT 'none',
                timestamp TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS scans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scan_id TEXT UNIQUE NOT NULL,
                scan_type TEXT,
                target_path TEXT,
                files_scanned INTEGER DEFAULT 0,
                threats_found INTEGER DEFAULT 0,
                duration_seconds REAL DEFAULT 0,
                status TEXT DEFAULT 'running',
                started_at TEXT NOT NULL,
                completed_at TEXT
            );

            CREATE TABLE IF NOT EXISTS quarantine (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                original_path TEXT NOT NULL,
                quarantine_path TEXT NOT NULL,
                file_hash TEXT,
                threat_name TEXT,
                quarantined_at TEXT NOT NULL,
                restored BOOLEAN DEFAULT 0
            );

            CREATE INDEX IF NOT EXISTS idx_threats_hash ON threats(file_hash);
            CREATE INDEX IF NOT EXISTS idx_threats_timestamp ON threats(timestamp);
            CREATE INDEX IF NOT EXISTS idx_scans_id ON scans(scan_id);
            CREATE INDEX IF NOT EXISTS idx_quarantine_hash ON quarantine(file_hash);
        """)
        conn.commit()

    def add_threat(self, record: ThreatRecord) -> int:
        """Store a new threat detection."""
        cur = self._conn.execute(
            """INSERT INTO threats
               (file_path, file_hash, threat_name, threat_category, severity,
                detection_method, score, details, action_taken, timestamp)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (record.file_path, record.file_hash, record.threat_name,
             record.threat_category, record.severity, record.detection_method,
             record.score, json.dumps(record.details), record.action_taken,
             record.timestamp),
        )
        self._conn.commit()
        return cur.lastrowid

    def add_scan(self, record: ScanRecord) -> int:
        """Store a new scan session."""
        cur = self._conn.execute(
            """INSERT INTO scans
               (scan_id, scan_type, target_path, files_scanned, threats_found,
                duration_seconds, status, started_at, completed_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (record.scan_id, record.scan_type, record.target_path,
             record.files_scanned, record.threats_found, record.duration_seconds,
             record.status, record.started_at, record.completed_at),
        )
        self._conn.commit()
        return cur.lastrowid

    def update_scan(self, scan_id: str, **kwargs):
        """Update a scan record."""
        allowed = {"files_scanned", "threats_found", "duration_seconds",
                    "status", "completed_at"}
        updates = {k: v for k, v in kwargs.items() if k in allowed}
        if not updates:
            return

        set_clause = ", ".join(f"{k} = ?" for k in updates)
        values = list(updates.values()) + [scan_id]
        self._conn.execute(
            f"UPDATE scans SET {set_clause} WHERE scan_id = ?", values,
        )
        self._conn.commit()

    def get_recent_threats(self, limit: int = 50) -> list[dict]:
        """Get most recent threat detections."""
        rows = self._conn.execute(
            "SELECT * FROM threats ORDER BY timestamp DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(r) for r in rows]

    def get_recent_scans(self, limit: int = 20) -> list[dict]:
        """Get most recent scan sessions."""
        rows = self._conn.execute(
            "SELECT * FROM scans ORDER BY started_at DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(r) for r in rows]

    def get_stats(self) -> dict:
        """Get overall statistics."""
        total_threats = self._conn.execute(
            "SELECT COUNT(*) FROM threats").fetchone()[0]
        total_scans = self._conn.execute(
            "SELECT COUNT(*) FROM scans").fetchone()[0]
        total_quarantined = self._conn.execute(
            "SELECT COUNT(*) FROM quarantine WHERE restored = 0").fetchone()[0]
        total_files_scanned = self._conn.execute(
            "SELECT COALESCE(SUM(files_scanned), 0) FROM scans").fetchone()[0]

        severity_counts = {}
        for row in self._conn.execute(
            "SELECT severity, COUNT(*) as cnt FROM threats GROUP BY severity"
        ).fetchall():
            severity_counts[row[0]] = row[1]

        category_counts = {}
        for row in self._conn.execute(
            "SELECT threat_category, COUNT(*) as cnt FROM threats "
            "GROUP BY threat_category"
        ).fetchall():
            category_counts[row[0]] = row[1]

        return {
            "total_threats_detected": total_threats,
            "total_scans": total_scans,
            "total_quarantined": total_quarantined,
            "total_files_scanned": total_files_scanned,
            "severity_breakdown": severity_counts,
            "category_breakdown": category_counts,
        }

    def is_known_threat(self, file_hash: str) -> bool:
        """Check if a hash is already recorded as a threat."""
        row = self._conn.execute(
            "SELECT COUNT(*) FROM threats WHERE file_hash = ?", (file_hash,)
        ).fetchone()
        return row[0] > 0

    def add_quarantine_record(self, original_path: str, quarantine_path: str,
                              file_hash: str, threat_name: str):
        """Record a quarantined file."""
        self._conn.execute(
            """INSERT INTO quarantine
               (original_path, quarantine_path, file_hash, threat_name, quarantined_at)
               VALUES (?, ?, ?, ?, ?)""",
            (original_path, quarantine_path, file_hash, threat_name,
             datetime.now(timezone.utc).isoformat()),
        )
        self._conn.commit()

    def get_quarantine_list(self) -> list[dict]:
        """Get all quarantined files."""
        rows = self._conn.execute(
            "SELECT * FROM quarantine WHERE restored = 0 "
            "ORDER BY quarantined_at DESC"
        ).fetchall()
        return [dict(r) for r in rows]

    def mark_restored(self, quarantine_id: int):
        """Mark a quarantined file as restored."""
        self._conn.execute(
            "UPDATE quarantine SET restored = 1 WHERE id = ?", (quarantine_id,)
        )
        self._conn.commit()

    def close(self):
        """Close the database connection."""
        if hasattr(self._local, "conn") and self._local.conn:
            self._local.conn.close()
            self._local.conn = None
