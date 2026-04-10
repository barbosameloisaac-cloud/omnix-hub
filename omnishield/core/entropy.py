"""
OmniShield Entropy Analysis Engine
Detects packed, encrypted, or obfuscated malware using Shannon entropy analysis.
High entropy regions indicate compression/encryption commonly used by malware.
"""

import math
from pathlib import Path
from typing import Optional

from omnishield.config.settings import (
    ENTROPY_BLOCK_SIZE,
    ENTROPY_DANGEROUS,
    ENTROPY_SUSPICIOUS,
)


class EntropyResult:
    """Entropy analysis result for a file."""

    def __init__(self, file_path: str, overall_entropy: float,
                 max_block_entropy: float, suspicious_blocks: int,
                 total_blocks: int, risk_level: str):
        self.file_path = file_path
        self.overall_entropy = overall_entropy
        self.max_block_entropy = max_block_entropy
        self.suspicious_blocks = suspicious_blocks
        self.total_blocks = total_blocks
        self.risk_level = risk_level

    @property
    def score(self) -> int:
        """Convert entropy to a threat score (0-100)."""
        if self.overall_entropy >= ENTROPY_DANGEROUS:
            base = 70
        elif self.overall_entropy >= ENTROPY_SUSPICIOUS:
            base = 40
        else:
            base = 0

        suspicious_ratio = (self.suspicious_blocks / max(self.total_blocks, 1))
        bonus = int(suspicious_ratio * 30)

        return min(base + bonus, 100)

    def to_dict(self) -> dict:
        return {
            "file_path": self.file_path,
            "overall_entropy": round(self.overall_entropy, 4),
            "max_block_entropy": round(self.max_block_entropy, 4),
            "suspicious_blocks": self.suspicious_blocks,
            "total_blocks": self.total_blocks,
            "risk_level": self.risk_level,
            "score": self.score,
        }


class EntropyAnalyzer:
    """Shannon entropy analyzer for malware detection."""

    def __init__(self, block_size: int = ENTROPY_BLOCK_SIZE):
        self.block_size = block_size

    @staticmethod
    def calculate_entropy(data: bytes) -> float:
        """Calculate Shannon entropy of a byte sequence."""
        if not data:
            return 0.0

        byte_counts = [0] * 256
        for byte in data:
            byte_counts[byte] += 1

        length = len(data)
        entropy = 0.0
        for count in byte_counts:
            if count > 0:
                probability = count / length
                entropy -= probability * math.log2(probability)

        return entropy

    def analyze_file(self, file_path: Path) -> Optional[EntropyResult]:
        """Perform full entropy analysis on a file."""
        try:
            with open(file_path, "rb") as f:
                content = f.read(50 * 1024 * 1024)  # Limit to 50MB
        except (OSError, PermissionError):
            return None

        if not content:
            return EntropyResult(
                file_path=str(file_path),
                overall_entropy=0.0,
                max_block_entropy=0.0,
                suspicious_blocks=0,
                total_blocks=0,
                risk_level="clean",
            )

        # Overall file entropy
        overall_entropy = self.calculate_entropy(content)

        # Block-level analysis
        max_block_entropy = 0.0
        suspicious_blocks = 0
        total_blocks = 0

        for i in range(0, len(content), self.block_size):
            block = content[i:i + self.block_size]
            if len(block) < self.block_size // 2:
                break

            block_entropy = self.calculate_entropy(block)
            total_blocks += 1
            max_block_entropy = max(max_block_entropy, block_entropy)

            if block_entropy >= ENTROPY_SUSPICIOUS:
                suspicious_blocks += 1

        # Determine risk level
        if overall_entropy >= ENTROPY_DANGEROUS:
            risk_level = "critical"
        elif overall_entropy >= ENTROPY_SUSPICIOUS:
            risk_level = "suspicious"
        elif suspicious_blocks > total_blocks * 0.5:
            risk_level = "suspicious"
        else:
            risk_level = "clean"

        return EntropyResult(
            file_path=str(file_path),
            overall_entropy=overall_entropy,
            max_block_entropy=max_block_entropy,
            suspicious_blocks=suspicious_blocks,
            total_blocks=total_blocks,
            risk_level=risk_level,
        )

    def quick_check(self, file_path: Path) -> str:
        """Quick entropy check returning risk level string."""
        result = self.analyze_file(file_path)
        if result is None:
            return "error"
        return result.risk_level
