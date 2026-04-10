"""
OmniShield Signature Engine
Hash-based and pattern-based malware signature matching.
Supports SHA-256 hash lookups and byte-pattern scanning.
"""

import hashlib
import json
import re
from pathlib import Path
from typing import Optional

from omnishield.config.settings import SIGNATURES_DIR


class SignatureMatch:
    """Represents a signature match result."""

    def __init__(self, name: str, category: str, severity: str, signature_id: str,
                 description: str = ""):
        self.name = name
        self.category = category
        self.severity = severity
        self.signature_id = signature_id
        self.description = description

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "category": self.category,
            "severity": self.severity,
            "signature_id": self.signature_id,
            "description": self.description,
        }


class SignatureEngine:
    """Multi-method signature detection engine."""

    def __init__(self):
        self.hash_signatures: dict[str, dict] = {}
        self.byte_patterns: list[dict] = []
        self.string_patterns: list[dict] = []
        self._load_signatures()

    def _load_signatures(self):
        """Load all signature databases."""
        sig_file = SIGNATURES_DIR / "malware_signatures.json"
        if not sig_file.exists():
            return

        with open(sig_file, "r") as f:
            data = json.load(f)

        # Load hash-based signatures
        for sig in data.get("hash_signatures", []):
            self.hash_signatures[sig["hash"]] = sig

        # Load byte-pattern signatures
        self.byte_patterns = data.get("byte_patterns", [])

        # Load string-pattern signatures
        self.string_patterns = data.get("string_patterns", [])

    def scan_file_hash(self, file_path: Path) -> Optional[SignatureMatch]:
        """Check file hash against known malware signatures."""
        try:
            sha256 = hashlib.sha256()
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(8192), b""):
                    sha256.update(chunk)
            file_hash = sha256.hexdigest()

            if file_hash in self.hash_signatures:
                sig = self.hash_signatures[file_hash]
                return SignatureMatch(
                    name=sig["name"],
                    category=sig.get("category", "malware"),
                    severity=sig.get("severity", "high"),
                    signature_id=sig.get("id", "HASH-UNKNOWN"),
                    description=sig.get("description", "Known malware hash match"),
                )
        except (OSError, PermissionError):
            pass
        return None

    def scan_byte_patterns(self, file_path: Path) -> list[SignatureMatch]:
        """Scan file for known malicious byte patterns."""
        matches = []
        try:
            with open(file_path, "rb") as f:
                content = f.read(10 * 1024 * 1024)  # Read up to 10MB

            for pattern_def in self.byte_patterns:
                try:
                    pattern = bytes.fromhex(pattern_def["hex_pattern"])
                    if pattern in content:
                        matches.append(SignatureMatch(
                            name=pattern_def["name"],
                            category=pattern_def.get("category", "malware"),
                            severity=pattern_def.get("severity", "medium"),
                            signature_id=pattern_def.get("id", "BYTE-UNKNOWN"),
                            description=pattern_def.get("description", ""),
                        ))
                except (ValueError, KeyError):
                    continue
        except (OSError, PermissionError):
            pass
        return matches

    def scan_string_patterns(self, file_path: Path) -> list[SignatureMatch]:
        """Scan file for suspicious string patterns."""
        matches = []
        try:
            with open(file_path, "rb") as f:
                content = f.read(10 * 1024 * 1024)

            text_content = content.decode("utf-8", errors="ignore")

            for pattern_def in self.string_patterns:
                try:
                    regex = re.compile(pattern_def["pattern"], re.IGNORECASE)
                    if regex.search(text_content):
                        matches.append(SignatureMatch(
                            name=pattern_def["name"],
                            category=pattern_def.get("category", "suspicious"),
                            severity=pattern_def.get("severity", "medium"),
                            signature_id=pattern_def.get("id", "STR-UNKNOWN"),
                            description=pattern_def.get("description", ""),
                        ))
                except (re.error, KeyError):
                    continue
        except (OSError, PermissionError):
            pass
        return matches

    def full_scan(self, file_path: Path) -> list[SignatureMatch]:
        """Run all signature checks on a file."""
        results = []

        hash_match = self.scan_file_hash(file_path)
        if hash_match:
            results.append(hash_match)

        results.extend(self.scan_byte_patterns(file_path))
        results.extend(self.scan_string_patterns(file_path))

        return results

    @property
    def signature_count(self) -> int:
        return (len(self.hash_signatures) + len(self.byte_patterns) +
                len(self.string_patterns))
