"""
OmniShield Quarantine System
Safely isolates detected threats by encrypting and moving them
to a secure quarantine vault. Supports restore operations.
"""

import hashlib
import os
import shutil
import struct
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from omnishield.config.settings import QUARANTINE_DIR
from omnishield.core.threat_db import ThreatDatabase


class QuarantineVault:
    """Manages quarantined threat files with simple XOR encryption."""

    QUARANTINE_MAGIC = b"OMNI_Q\x01\x00"  # File header magic
    XOR_KEY = b"OmniShield_NeonCore_2026_QuarantineVault"

    def __init__(self, db: Optional[ThreatDatabase] = None):
        self.vault_dir = QUARANTINE_DIR
        self.vault_dir.mkdir(parents=True, exist_ok=True)
        self.db = db or ThreatDatabase()

    def quarantine_file(self, file_path: Path, threat_name: str = "Unknown"
                        ) -> Optional[str]:
        """
        Move a file to quarantine vault.
        The file is XOR-encrypted to prevent accidental execution.
        Returns the quarantine path or None on failure.
        """
        if not file_path.exists():
            return None

        try:
            # Compute file hash before quarantine
            sha256 = hashlib.sha256()
            with open(file_path, "rb") as f:
                content = f.read()
                sha256.update(content)
            file_hash = sha256.hexdigest()

            # Generate quarantine filename
            timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
            q_name = f"{timestamp}_{file_hash[:16]}.qvault"
            q_path = self.vault_dir / q_name

            # Build quarantine file: MAGIC + original_path_len + original_path + encrypted_content
            original_path_bytes = str(file_path.resolve()).encode("utf-8")
            encrypted = self._xor_encrypt(content)

            with open(q_path, "wb") as qf:
                qf.write(self.QUARANTINE_MAGIC)
                qf.write(struct.pack("<I", len(original_path_bytes)))
                qf.write(original_path_bytes)
                qf.write(encrypted)

            # Remove original file
            os.remove(file_path)

            # Record in database
            self.db.add_quarantine_record(
                original_path=str(file_path.resolve()),
                quarantine_path=str(q_path),
                file_hash=file_hash,
                threat_name=threat_name,
            )

            return str(q_path)

        except (OSError, PermissionError) as e:
            return None

    def restore_file(self, quarantine_id: int) -> Optional[str]:
        """
        Restore a quarantined file to its original location.
        Returns the restored path or None on failure.
        """
        records = self.db.get_quarantine_list()
        record = None
        for r in records:
            if r["id"] == quarantine_id:
                record = r
                break

        if not record:
            return None

        q_path = Path(record["quarantine_path"])
        if not q_path.exists():
            return None

        try:
            with open(q_path, "rb") as qf:
                magic = qf.read(len(self.QUARANTINE_MAGIC))
                if magic != self.QUARANTINE_MAGIC:
                    return None

                path_len = struct.unpack("<I", qf.read(4))[0]
                original_path = qf.read(path_len).decode("utf-8")
                encrypted_content = qf.read()

            # Decrypt
            content = self._xor_encrypt(encrypted_content)  # XOR is symmetric

            # Restore to original location
            restore_path = Path(original_path)
            restore_path.parent.mkdir(parents=True, exist_ok=True)

            with open(restore_path, "wb") as f:
                f.write(content)

            # Remove quarantine file
            os.remove(q_path)

            # Update database
            self.db.mark_restored(quarantine_id)

            return str(restore_path)

        except (OSError, PermissionError, struct.error):
            return None

    def delete_quarantined(self, quarantine_id: int) -> bool:
        """Permanently delete a quarantined file."""
        records = self.db.get_quarantine_list()
        record = None
        for r in records:
            if r["id"] == quarantine_id:
                record = r
                break

        if not record:
            return False

        try:
            q_path = Path(record["quarantine_path"])
            if q_path.exists():
                os.remove(q_path)
            self.db.mark_restored(quarantine_id)
            return True
        except OSError:
            return False

    def list_quarantined(self) -> list[dict]:
        """List all quarantined files."""
        return self.db.get_quarantine_list()

    def vault_size(self) -> int:
        """Get total size of quarantine vault in bytes."""
        total = 0
        for f in self.vault_dir.iterdir():
            if f.suffix == ".qvault":
                total += f.stat().st_size
        return total

    def _xor_encrypt(self, data: bytes) -> bytes:
        """XOR encrypt/decrypt data with the vault key."""
        key = self.XOR_KEY
        key_len = len(key)
        return bytes(b ^ key[i % key_len] for i, b in enumerate(data))
