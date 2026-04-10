"""
OmniShield Unit Tests
Tests for all core detection engines and systems.
"""

import os
import tempfile
import unittest
from pathlib import Path

from omnishield.core.entropy import EntropyAnalyzer
from omnishield.core.file_analyzer import FileAnalyzer
from omnishield.core.heuristics import HeuristicEngine
from omnishield.core.quarantine import QuarantineVault
from omnishield.core.scanner import OmniScanner
from omnishield.core.signatures import SignatureEngine
from omnishield.core.threat_db import ThreatDatabase, ThreatRecord


class TestEntropyAnalyzer(unittest.TestCase):
    """Tests for the entropy analysis engine."""

    def setUp(self):
        self.analyzer = EntropyAnalyzer()

    def test_zero_entropy(self):
        """Repeated bytes should have zero entropy."""
        data = bytes([0x41] * 1000)
        entropy = EntropyAnalyzer.calculate_entropy(data)
        self.assertEqual(entropy, 0.0)

    def test_max_entropy(self):
        """All unique bytes should have max entropy (~8.0)."""
        data = bytes(range(256))
        entropy = EntropyAnalyzer.calculate_entropy(data)
        self.assertAlmostEqual(entropy, 8.0, places=1)

    def test_empty_data(self):
        """Empty data should have zero entropy."""
        entropy = EntropyAnalyzer.calculate_entropy(b"")
        self.assertEqual(entropy, 0.0)

    def test_file_analysis(self):
        """Test full file entropy analysis."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".bin") as f:
            f.write(b"Hello World " * 100)
            tmp_path = f.name

        try:
            result = self.analyzer.analyze_file(Path(tmp_path))
            self.assertIsNotNone(result)
            self.assertEqual(result.risk_level, "clean")
            self.assertLess(result.overall_entropy, 5.0)
        finally:
            os.unlink(tmp_path)

    def test_high_entropy_detection(self):
        """High entropy data should be flagged."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".bin") as f:
            # Write pseudo-random data (all byte values)
            f.write(bytes(range(256)) * 500)
            tmp_path = f.name

        try:
            result = self.analyzer.analyze_file(Path(tmp_path))
            self.assertIsNotNone(result)
            self.assertGreater(result.overall_entropy, 7.0)
        finally:
            os.unlink(tmp_path)


class TestHeuristicEngine(unittest.TestCase):
    """Tests for the heuristic analysis engine."""

    def setUp(self):
        self.engine = HeuristicEngine()

    def test_clean_file(self):
        """Normal text file should be clean."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".txt",
                                         mode='w') as f:
            f.write("This is a perfectly normal text file with nothing suspicious.")
            tmp_path = f.name

        try:
            result = self.engine.analyze_file(Path(tmp_path))
            self.assertIsNotNone(result)
            self.assertEqual(result.risk_level, "clean")
            self.assertEqual(result.total_score, 0)
        finally:
            os.unlink(tmp_path)

    def test_suspicious_patterns(self):
        """File with suspicious strings should be flagged."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".txt",
                                         mode='wb') as f:
            f.write(b"VirtualAllocEx WriteProcessMemory CreateRemoteThread")
            tmp_path = f.name

        try:
            result = self.engine.analyze_file(Path(tmp_path))
            self.assertIsNotNone(result)
            self.assertGreater(result.total_score, 0)
            self.assertGreater(len(result.triggered_rules), 0)
        finally:
            os.unlink(tmp_path)

    def test_pe_header_detection(self):
        """Basic PE header should be detected."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".exe",
                                         mode='wb') as f:
            # Write minimal PE-like header
            header = bytearray(512)
            header[0:2] = b"MZ"
            header[0x3C:0x40] = (128).to_bytes(4, 'little')
            header[128:132] = b"PE\x00\x00"
            header[134:136] = (3).to_bytes(2, 'little')  # 3 sections
            f.write(bytes(header))
            tmp_path = f.name

        try:
            result = self.engine.analyze_file(Path(tmp_path))
            self.assertIsNotNone(result)
        finally:
            os.unlink(tmp_path)


class TestFileAnalyzer(unittest.TestCase):
    """Tests for the file analyzer."""

    def setUp(self):
        self.analyzer = FileAnalyzer()

    def test_text_file(self):
        """Test analysis of a text file."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".txt",
                                         mode='w') as f:
            f.write("Hello, World!")
            tmp_path = f.name

        try:
            meta = self.analyzer.analyze(Path(tmp_path))
            self.assertIsNotNone(meta)
            self.assertEqual(meta.extension, ".txt")
            self.assertGreater(len(meta.sha256), 0)
            self.assertGreater(len(meta.md5), 0)
        finally:
            os.unlink(tmp_path)

    def test_empty_file(self):
        """Test analysis of an empty file."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".dat") as f:
            tmp_path = f.name

        try:
            meta = self.analyzer.analyze(Path(tmp_path))
            self.assertIsNotNone(meta)
            self.assertEqual(meta.size_bytes, 0)
            self.assertEqual(meta.file_type, "empty")
        finally:
            os.unlink(tmp_path)

    def test_pe_detection(self):
        """Test PE executable detection."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".exe",
                                         mode='wb') as f:
            f.write(b"MZ" + b"\x00" * 100)
            tmp_path = f.name

        try:
            meta = self.analyzer.analyze(Path(tmp_path))
            self.assertIsNotNone(meta)
            self.assertEqual(meta.file_type, "pe_executable")
            self.assertEqual(meta.platform_target, "windows")
        finally:
            os.unlink(tmp_path)

    def test_elf_detection(self):
        """Test ELF binary detection."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".bin",
                                         mode='wb') as f:
            f.write(b"\x7fELF" + b"\x00" * 100)
            tmp_path = f.name

        try:
            meta = self.analyzer.analyze(Path(tmp_path))
            self.assertIsNotNone(meta)
            self.assertEqual(meta.file_type, "elf_executable")
            self.assertEqual(meta.platform_target, "linux")
        finally:
            os.unlink(tmp_path)

    def test_nonexistent_file(self):
        """Test with non-existent file."""
        meta = self.analyzer.analyze(Path("/nonexistent/file.txt"))
        self.assertIsNone(meta)


class TestSignatureEngine(unittest.TestCase):
    """Tests for the signature detection engine."""

    def setUp(self):
        self.engine = SignatureEngine()

    def test_signatures_loaded(self):
        """Signatures should be loaded from JSON."""
        self.assertGreater(self.engine.signature_count, 0)

    def test_eicar_detection(self):
        """Test EICAR test file detection."""
        eicar = (b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-"
                 b"STANDARD-ANTIVIRUS-TEST-FILE!$H+H*")

        with tempfile.NamedTemporaryFile(delete=False, suffix=".com",
                                         mode='wb') as f:
            f.write(eicar)
            tmp_path = f.name

        try:
            # Check byte pattern match
            matches = self.engine.scan_byte_patterns(Path(tmp_path))
            eicar_found = any("EICAR" in m.name for m in matches)
            self.assertTrue(eicar_found, "EICAR signature should be detected")
        finally:
            os.unlink(tmp_path)

    def test_clean_file(self):
        """Clean file should have no signature matches."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".txt",
                                         mode='w') as f:
            f.write("Perfectly normal content.")
            tmp_path = f.name

        try:
            matches = self.engine.full_scan(Path(tmp_path))
            self.assertEqual(len(matches), 0)
        finally:
            os.unlink(tmp_path)


class TestThreatDatabase(unittest.TestCase):
    """Tests for the threat database."""

    def setUp(self):
        self.tmp_db = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
        self.tmp_db.close()
        self.db = ThreatDatabase(db_path=Path(self.tmp_db.name))

    def tearDown(self):
        self.db.close()
        os.unlink(self.tmp_db.name)

    def test_add_threat(self):
        """Test adding a threat record."""
        record = ThreatRecord(
            file_path="/test/malware.exe",
            file_hash="abc123",
            threat_name="Test.Malware",
            threat_category="trojan",
            severity="high",
            detection_method="signature",
            score=85,
        )
        row_id = self.db.add_threat(record)
        self.assertGreater(row_id, 0)

    def test_get_stats(self):
        """Test statistics retrieval."""
        record = ThreatRecord(
            file_path="/test/malware.exe",
            file_hash="abc123",
            threat_name="Test.Malware",
            threat_category="trojan",
            severity="high",
            detection_method="signature",
            score=85,
        )
        self.db.add_threat(record)

        stats = self.db.get_stats()
        self.assertEqual(stats["total_threats_detected"], 1)
        self.assertIn("high", stats["severity_breakdown"])

    def test_is_known_threat(self):
        """Test known threat lookup."""
        record = ThreatRecord(
            file_path="/test/malware.exe",
            file_hash="known_hash_123",
            threat_name="Test.Malware",
            threat_category="trojan",
            severity="high",
            detection_method="signature",
            score=85,
        )
        self.db.add_threat(record)

        self.assertTrue(self.db.is_known_threat("known_hash_123"))
        self.assertFalse(self.db.is_known_threat("unknown_hash"))


class TestQuarantineVault(unittest.TestCase):
    """Tests for the quarantine system."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.tmp_db = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
        self.tmp_db.close()

        self.db = ThreatDatabase(db_path=Path(self.tmp_db.name))

        # Patch quarantine dir
        import omnishield.core.quarantine as qmod
        self._orig_dir = qmod.QUARANTINE_DIR
        qmod.QUARANTINE_DIR = Path(self.tmp_dir)

        self.vault = QuarantineVault(db=self.db)
        self.vault.vault_dir = Path(self.tmp_dir)

    def tearDown(self):
        self.db.close()
        os.unlink(self.tmp_db.name)
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

        import omnishield.core.quarantine as qmod
        qmod.QUARANTINE_DIR = self._orig_dir

    def test_quarantine_and_restore(self):
        """Test quarantining and restoring a file."""
        # Create a test file
        test_file = Path(self.tmp_dir) / "test_threat.exe"
        test_content = b"This is malicious content for testing"
        with open(test_file, "wb") as f:
            f.write(test_content)

        # Quarantine it
        q_path = self.vault.quarantine_file(test_file, "Test.Threat")
        self.assertIsNotNone(q_path)
        self.assertFalse(test_file.exists(), "Original file should be removed")

        # Verify quarantine record
        records = self.vault.list_quarantined()
        self.assertEqual(len(records), 1)

        # Restore it
        restore_path = self.vault.restore_file(records[0]["id"])
        self.assertIsNotNone(restore_path)

        # Verify content
        with open(restore_path, "rb") as f:
            restored_content = f.read()
        self.assertEqual(restored_content, test_content)


class TestOmniScanner(unittest.TestCase):
    """Tests for the main scanner orchestrator."""

    def setUp(self):
        self.scanner = OmniScanner()

    def test_scan_clean_file(self):
        """Scan a clean text file."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".txt",
                                         mode='w') as f:
            f.write("Just a normal file.")
            tmp_path = f.name

        try:
            result = self.scanner.scan_file(Path(tmp_path))
            self.assertTrue(result.clean)
            self.assertEqual(result.risk_level, "clean")
            self.assertEqual(result.risk_score, 0)
            self.assertGreater(result.scan_time_ms, 0)
        finally:
            os.unlink(tmp_path)

    def test_scan_eicar(self):
        """Scan the EICAR test file — should detect as threat."""
        eicar = (b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-"
                 b"STANDARD-ANTIVIRUS-TEST-FILE!$H+H*")

        with tempfile.NamedTemporaryFile(delete=False, suffix=".com",
                                         mode='wb') as f:
            f.write(eicar)
            tmp_path = f.name

        try:
            result = self.scanner.scan_file(Path(tmp_path))
            self.assertFalse(result.clean, "EICAR should be detected as a threat")
            self.assertGreater(len(result.threats), 0)
        finally:
            os.unlink(tmp_path)

    def test_scan_directory(self):
        """Test directory scanning."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create some test files
            for i in range(3):
                p = Path(tmpdir) / f"test_{i}.txt"
                p.write_text(f"File content {i}")

            progress = self.scanner.scan_directory(
                Path(tmpdir), recursive=True, scan_all_files=True
            )
            self.assertEqual(progress.status, "completed")
            self.assertEqual(progress.scanned_files, 3)

    def test_engine_status(self):
        """Test engine status reporting."""
        status = self.scanner.get_engine_status()
        self.assertIn("signature_engine", status)
        self.assertIn("heuristic_engine", status)
        self.assertIn("entropy_analyzer", status)
        self.assertEqual(status["signature_engine"]["status"], "active")


if __name__ == "__main__":
    unittest.main()
