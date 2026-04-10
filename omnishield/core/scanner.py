"""
OmniShield Core Scanner
The main scanning orchestrator that combines all detection engines
(signatures, heuristics, entropy) into a unified threat assessment pipeline.
"""

import os
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from omnishield.config.settings import (
    ALL_SCAN_EXTENSIONS,
    HEURISTIC_THRESHOLD_LOW,
    MAX_FILE_SIZE_MB,
)
from omnishield.core.entropy import EntropyAnalyzer
from omnishield.core.file_analyzer import FileAnalyzer
from omnishield.core.heuristics import HeuristicEngine
from omnishield.core.quarantine import QuarantineVault
from omnishield.core.signatures import SignatureEngine
from omnishield.core.threat_db import ScanRecord, ThreatDatabase, ThreatRecord


class ScanResult:
    """Result of scanning a single file."""

    def __init__(self, file_path: str, clean: bool = True):
        self.file_path = file_path
        self.clean = clean
        self.threats: list[dict] = []
        self.risk_score: int = 0
        self.risk_level: str = "clean"
        self.file_metadata: Optional[dict] = None
        self.entropy_data: Optional[dict] = None
        self.heuristic_data: Optional[dict] = None
        self.scan_time_ms: float = 0

    def to_dict(self) -> dict:
        return {
            "file_path": self.file_path,
            "clean": self.clean,
            "threats": self.threats,
            "risk_score": self.risk_score,
            "risk_level": self.risk_level,
            "file_metadata": self.file_metadata,
            "entropy_data": self.entropy_data,
            "heuristic_data": self.heuristic_data,
            "scan_time_ms": round(self.scan_time_ms, 2),
        }


class ScanProgress:
    """Tracks progress of a scan operation."""

    def __init__(self):
        self.scan_id: str = str(uuid.uuid4())[:12]
        self.total_files: int = 0
        self.scanned_files: int = 0
        self.threats_found: int = 0
        self.current_file: str = ""
        self.status: str = "initializing"
        self.started_at: float = time.time()
        self.results: list[ScanResult] = []

    @property
    def progress_percent(self) -> float:
        if self.total_files == 0:
            return 0
        return round((self.scanned_files / self.total_files) * 100, 1)

    @property
    def elapsed_seconds(self) -> float:
        return round(time.time() - self.started_at, 2)

    def to_dict(self) -> dict:
        return {
            "scan_id": self.scan_id,
            "total_files": self.total_files,
            "scanned_files": self.scanned_files,
            "threats_found": self.threats_found,
            "current_file": self.current_file,
            "status": self.status,
            "progress_percent": self.progress_percent,
            "elapsed_seconds": self.elapsed_seconds,
        }


class OmniScanner:
    """Main scanning orchestrator combining all detection engines."""

    def __init__(self):
        self.signature_engine = SignatureEngine()
        self.heuristic_engine = HeuristicEngine()
        self.entropy_analyzer = EntropyAnalyzer()
        self.file_analyzer = FileAnalyzer()
        self.threat_db = ThreatDatabase()
        self.quarantine = QuarantineVault(db=self.threat_db)
        self._progress: Optional[ScanProgress] = None
        self._abort = False

    @property
    def progress(self) -> Optional[ScanProgress]:
        return self._progress

    def abort_scan(self):
        """Signal the current scan to abort."""
        self._abort = True

    def scan_file(self, file_path: Path, auto_quarantine: bool = False
                  ) -> ScanResult:
        """Scan a single file through all detection engines."""
        start = time.time()
        result = ScanResult(file_path=str(file_path))

        # File metadata analysis
        meta = self.file_analyzer.analyze(file_path)
        if meta:
            result.file_metadata = meta.to_dict()

        # Skip files that are too large
        try:
            if file_path.stat().st_size > MAX_FILE_SIZE_MB * 1024 * 1024:
                result.scan_time_ms = (time.time() - start) * 1000
                return result
        except OSError:
            result.scan_time_ms = (time.time() - start) * 1000
            return result

        max_score = 0

        # 1. Signature-based detection
        sig_matches = self.signature_engine.full_scan(file_path)
        for match in sig_matches:
            result.threats.append({
                "source": "signature",
                **match.to_dict(),
            })
            result.clean = False

        # 2. Entropy analysis
        entropy_result = self.entropy_analyzer.analyze_file(file_path)
        if entropy_result:
            result.entropy_data = entropy_result.to_dict()
            if entropy_result.risk_level in ("suspicious", "critical"):
                max_score = max(max_score, entropy_result.score)

        # 3. Heuristic analysis
        heuristic_result = self.heuristic_engine.analyze_file(file_path)
        if heuristic_result:
            result.heuristic_data = heuristic_result.to_dict()
            if heuristic_result.total_score >= HEURISTIC_THRESHOLD_LOW:
                result.threats.append({
                    "source": "heuristic",
                    "name": "Heuristic.Suspicious",
                    "category": "heuristic",
                    "severity": heuristic_result.risk_level,
                    "score": heuristic_result.total_score,
                    "description": f"{len(heuristic_result.triggered_rules)} "
                                   f"behavioral rules triggered",
                })
                result.clean = False
                max_score = max(max_score, heuristic_result.total_score)

        # Compute final risk score and level
        if sig_matches:
            max_score = max(max_score, 90)
        result.risk_score = min(max_score, 100)

        if result.risk_score >= 75:
            result.risk_level = "critical"
        elif result.risk_score >= 55:
            result.risk_level = "high"
        elif result.risk_score >= 30:
            result.risk_level = "suspicious"
        else:
            result.risk_level = "clean"

        # Record threat in database
        if not result.clean:
            primary_threat = result.threats[0] if result.threats else {}
            self.threat_db.add_threat(ThreatRecord(
                file_path=str(file_path),
                file_hash=meta.sha256 if meta else "",
                threat_name=primary_threat.get("name", "Unknown"),
                threat_category=primary_threat.get("category", "unknown"),
                severity=result.risk_level,
                detection_method=primary_threat.get("source", "multi"),
                score=result.risk_score,
                details={"threats": result.threats},
                action_taken="quarantined" if auto_quarantine else "detected",
            ))

            # Auto-quarantine if enabled
            if auto_quarantine and result.risk_level in ("critical", "high"):
                threat_name = primary_threat.get("name", "Unknown")
                self.quarantine.quarantine_file(file_path, threat_name)

        result.scan_time_ms = (time.time() - start) * 1000
        return result

    def scan_directory(self, directory: Path, recursive: bool = True,
                       auto_quarantine: bool = False,
                       scan_all_files: bool = False) -> ScanProgress:
        """Scan an entire directory."""
        self._abort = False
        progress = ScanProgress()
        self._progress = progress

        # Collect files to scan
        files_to_scan: list[Path] = []
        try:
            iterator = directory.rglob("*") if recursive else directory.glob("*")
            for entry in iterator:
                if self._abort:
                    break
                if entry.is_file():
                    if scan_all_files or entry.suffix.lower() in ALL_SCAN_EXTENSIONS:
                        files_to_scan.append(entry)
        except PermissionError:
            pass

        progress.total_files = len(files_to_scan)
        progress.status = "scanning"

        # Record scan session
        scan_record = ScanRecord(
            scan_id=progress.scan_id,
            scan_type="directory",
            target_path=str(directory),
        )
        self.threat_db.add_scan(scan_record)

        # Scan each file
        for file_path in files_to_scan:
            if self._abort:
                progress.status = "aborted"
                break

            progress.current_file = str(file_path)
            try:
                result = self.scan_file(file_path, auto_quarantine=auto_quarantine)
                progress.results.append(result)
                if not result.clean:
                    progress.threats_found += 1
            except Exception:
                pass

            progress.scanned_files += 1

        if progress.status != "aborted":
            progress.status = "completed"

        # Update scan record
        self.threat_db.update_scan(
            progress.scan_id,
            files_scanned=progress.scanned_files,
            threats_found=progress.threats_found,
            duration_seconds=progress.elapsed_seconds,
            status=progress.status,
            completed_at=datetime.now(timezone.utc).isoformat(),
        )

        return progress

    def quick_scan(self, paths: Optional[list[str]] = None,
                   auto_quarantine: bool = False) -> ScanProgress:
        """Quick scan of common threat locations."""
        from omnishield.config.settings import DEFAULT_SCAN_PATHS

        targets = paths or DEFAULT_SCAN_PATHS
        self._abort = False
        progress = ScanProgress()
        self._progress = progress
        progress.status = "scanning"

        scan_record = ScanRecord(
            scan_id=progress.scan_id,
            scan_type="quick",
            target_path=", ".join(targets),
        )
        self.threat_db.add_scan(scan_record)

        for target in targets:
            if self._abort:
                break
            target_path = Path(target)
            if target_path.is_dir():
                sub_progress = self.scan_directory(
                    target_path,
                    recursive=False,
                    auto_quarantine=auto_quarantine,
                )
                progress.scanned_files += sub_progress.scanned_files
                progress.threats_found += sub_progress.threats_found
                progress.results.extend(sub_progress.results)
            elif target_path.is_file():
                result = self.scan_file(target_path, auto_quarantine=auto_quarantine)
                progress.results.append(result)
                progress.scanned_files += 1
                if not result.clean:
                    progress.threats_found += 1

        progress.status = "completed"
        progress.total_files = progress.scanned_files

        self.threat_db.update_scan(
            progress.scan_id,
            files_scanned=progress.scanned_files,
            threats_found=progress.threats_found,
            duration_seconds=progress.elapsed_seconds,
            status="completed",
            completed_at=datetime.now(timezone.utc).isoformat(),
        )

        return progress

    def get_engine_status(self) -> dict:
        """Get status of all detection engines."""
        return {
            "signature_engine": {
                "status": "active",
                "signatures_loaded": self.signature_engine.signature_count,
            },
            "heuristic_engine": {
                "status": "active",
                "rules_loaded": len(HeuristicEngine.SUSPICIOUS_STRINGS),
            },
            "entropy_analyzer": {
                "status": "active",
            },
            "threat_database": self.threat_db.get_stats(),
            "quarantine_vault": {
                "files": len(self.quarantine.list_quarantined()),
                "size_bytes": self.quarantine.vault_size(),
            },
        }
