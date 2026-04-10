"""
OmniShield Real-Time File Monitor
Watches filesystem events and triggers automatic scanning
when new or modified files are detected. Cross-platform support.
"""

import logging
import threading
import time
from pathlib import Path
from typing import Callable, Optional

from watchdog.events import FileSystemEvent, FileSystemEventHandler
from watchdog.observers import Observer

from omnishield.config.settings import (
    DEFAULT_MONITOR_PATHS,
    MONITOR_DEBOUNCE_SECONDS,
    MONITOR_RECURSIVE,
)
from omnishield.core.scanner import OmniScanner, ScanResult

logger = logging.getLogger("omnishield.monitor")


class ThreatEventHandler(FileSystemEventHandler):
    """Handles filesystem events and triggers scanning."""

    def __init__(self, scanner: OmniScanner,
                 auto_quarantine: bool = False,
                 on_threat: Optional[Callable[[ScanResult], None]] = None):
        super().__init__()
        self.scanner = scanner
        self.auto_quarantine = auto_quarantine
        self.on_threat = on_threat
        self._debounce_cache: dict[str, float] = {}
        self._lock = threading.Lock()

    def _should_process(self, path: str) -> bool:
        """Debounce rapid events for the same file."""
        now = time.time()
        with self._lock:
            last_time = self._debounce_cache.get(path, 0)
            if now - last_time < MONITOR_DEBOUNCE_SECONDS:
                return False
            self._debounce_cache[path] = now

            # Cleanup old entries
            cutoff = now - 60
            self._debounce_cache = {
                k: v for k, v in self._debounce_cache.items() if v > cutoff
            }
        return True

    def _handle_event(self, event: FileSystemEvent):
        """Process a filesystem event."""
        if event.is_directory:
            return

        file_path = Path(event.src_path)
        if not file_path.exists() or not file_path.is_file():
            return

        if not self._should_process(event.src_path):
            return

        logger.info(f"[MONITOR] Scanning: {file_path}")

        try:
            result = self.scanner.scan_file(
                file_path, auto_quarantine=self.auto_quarantine
            )

            if not result.clean:
                logger.warning(
                    f"[THREAT] {result.risk_level.upper()}: "
                    f"{file_path} - Score: {result.risk_score}"
                )
                if self.on_threat:
                    self.on_threat(result)
        except Exception as e:
            logger.error(f"[MONITOR] Error scanning {file_path}: {e}")

    def on_created(self, event: FileSystemEvent):
        self._handle_event(event)

    def on_modified(self, event: FileSystemEvent):
        self._handle_event(event)

    def on_moved(self, event: FileSystemEvent):
        # Scan the destination file
        if hasattr(event, "dest_path"):
            dest_event = type(event)(event.dest_path)
            self._handle_event(dest_event)


class RealtimeMonitor:
    """Real-time filesystem protection monitor."""

    def __init__(self, scanner: Optional[OmniScanner] = None,
                 auto_quarantine: bool = False,
                 on_threat: Optional[Callable[[ScanResult], None]] = None):
        self.scanner = scanner or OmniScanner()
        self.auto_quarantine = auto_quarantine
        self.on_threat = on_threat
        self._observer: Optional[Observer] = None
        self._monitored_paths: list[str] = []
        self._running = False

    @property
    def is_running(self) -> bool:
        return self._running

    @property
    def monitored_paths(self) -> list[str]:
        return list(self._monitored_paths)

    def start(self, paths: Optional[list[str]] = None,
              recursive: bool = MONITOR_RECURSIVE):
        """Start real-time monitoring."""
        if self._running:
            logger.warning("[MONITOR] Already running")
            return

        monitor_paths = paths or DEFAULT_MONITOR_PATHS
        handler = ThreatEventHandler(
            scanner=self.scanner,
            auto_quarantine=self.auto_quarantine,
            on_threat=self.on_threat,
        )

        self._observer = Observer()
        self._monitored_paths = []

        for path_str in monitor_paths:
            path = Path(path_str)
            if path.exists() and path.is_dir():
                self._observer.schedule(handler, str(path), recursive=recursive)
                self._monitored_paths.append(str(path))
                logger.info(f"[MONITOR] Watching: {path}")
            else:
                logger.warning(f"[MONITOR] Path not found: {path}")

        if not self._monitored_paths:
            logger.error("[MONITOR] No valid paths to monitor")
            return

        self._observer.start()
        self._running = True
        logger.info(
            f"[MONITOR] Real-time protection ACTIVE "
            f"({len(self._monitored_paths)} paths)"
        )

    def stop(self):
        """Stop real-time monitoring."""
        if not self._running or not self._observer:
            return

        self._observer.stop()
        self._observer.join(timeout=5)
        self._running = False
        self._monitored_paths = []
        logger.info("[MONITOR] Real-time protection STOPPED")

    def add_path(self, path: str, recursive: bool = MONITOR_RECURSIVE):
        """Add a new path to monitor."""
        if not self._running or not self._observer:
            return False

        p = Path(path)
        if not p.exists() or not p.is_dir():
            return False

        handler = ThreatEventHandler(
            scanner=self.scanner,
            auto_quarantine=self.auto_quarantine,
            on_threat=self.on_threat,
        )
        self._observer.schedule(handler, str(p), recursive=recursive)
        self._monitored_paths.append(str(p))
        logger.info(f"[MONITOR] Added watch: {p}")
        return True

    def get_status(self) -> dict:
        """Get monitor status."""
        return {
            "running": self._running,
            "monitored_paths": self._monitored_paths,
            "auto_quarantine": self.auto_quarantine,
        }
