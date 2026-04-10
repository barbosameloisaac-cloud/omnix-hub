"""
OmniShield File Analyzer
Identifies file types, extracts metadata, and performs structural analysis
across all supported platforms (Windows, macOS, Linux, Android, iOS).
"""

import hashlib
import os
import struct
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


# Magic bytes for file type identification
MAGIC_SIGNATURES = {
    b"MZ": "pe_executable",           # Windows PE
    b"\x7fELF": "elf_executable",     # Linux/Android ELF
    b"\xfe\xed\xfa\xce": "macho_32", # Mach-O 32-bit
    b"\xfe\xed\xfa\xcf": "macho_64", # Mach-O 64-bit
    b"\xce\xfa\xed\xfe": "macho_32_r", # Mach-O 32-bit (reversed)
    b"\xcf\xfa\xed\xfe": "macho_64_r", # Mach-O 64-bit (reversed)
    b"\xca\xfe\xba\xbe": "macho_fat",  # Mach-O Fat/Universal
    b"PK\x03\x04": "zip_archive",    # ZIP/APK/DOCX/JAR
    b"Rar!\x1a\x07": "rar_archive",  # RAR
    b"\x1f\x8b": "gzip",             # GZIP
    b"BZ": "bzip2",                   # BZIP2
    b"\xfd7zXZ": "xz",               # XZ
    b"7z\xbc\xaf\x27\x1c": "7zip",   # 7-Zip
    b"%PDF": "pdf_document",          # PDF
    b"\xd0\xcf\x11\xe0": "ole_document", # OLE (DOC/XLS/PPT)
    b"dex\n": "android_dex",          # Android DEX
    b"\x03\x00\x08\x00": "android_arsc", # Android compiled resources
}


class FileMetadata:
    """Comprehensive metadata for a scanned file."""

    def __init__(self):
        self.path: str = ""
        self.name: str = ""
        self.extension: str = ""
        self.size_bytes: int = 0
        self.file_type: str = "unknown"
        self.mime_type: str = "application/octet-stream"
        self.sha256: str = ""
        self.md5: str = ""
        self.created: Optional[str] = None
        self.modified: Optional[str] = None
        self.is_executable: bool = False
        self.is_hidden: bool = False
        self.is_symlink: bool = False
        self.magic_header: str = ""
        self.platform_target: str = "unknown"

    def to_dict(self) -> dict:
        return {
            "path": self.path,
            "name": self.name,
            "extension": self.extension,
            "size_bytes": self.size_bytes,
            "size_human": self._human_size(),
            "file_type": self.file_type,
            "sha256": self.sha256,
            "md5": self.md5,
            "created": self.created,
            "modified": self.modified,
            "is_executable": self.is_executable,
            "is_hidden": self.is_hidden,
            "is_symlink": self.is_symlink,
            "magic_header": self.magic_header,
            "platform_target": self.platform_target,
        }

    def _human_size(self) -> str:
        for unit in ("B", "KB", "MB", "GB", "TB"):
            if self.size_bytes < 1024:
                return f"{self.size_bytes:.1f} {unit}"
            self.size_bytes /= 1024
        return f"{self.size_bytes:.1f} PB"


class FileAnalyzer:
    """Cross-platform file analysis engine."""

    def analyze(self, file_path: Path) -> Optional[FileMetadata]:
        """Perform full analysis of a file."""
        if not file_path.exists() or not file_path.is_file():
            return None

        meta = FileMetadata()
        meta.path = str(file_path.resolve())
        meta.name = file_path.name
        meta.extension = file_path.suffix.lower()
        meta.is_symlink = file_path.is_symlink()
        meta.is_hidden = file_path.name.startswith(".")

        try:
            stat = file_path.stat()
            meta.size_bytes = stat.st_size
            meta.modified = datetime.fromtimestamp(
                stat.st_mtime, tz=timezone.utc
            ).isoformat()
            meta.created = datetime.fromtimestamp(
                stat.st_ctime, tz=timezone.utc
            ).isoformat()
            meta.is_executable = os.access(file_path, os.X_OK)
        except OSError:
            pass

        # Compute hashes
        self._compute_hashes(file_path, meta)

        # Identify file type from magic bytes
        self._identify_type(file_path, meta)

        # Determine target platform
        self._identify_platform(meta)

        return meta

    def _compute_hashes(self, file_path: Path, meta: FileMetadata):
        """Compute SHA-256 and MD5 hashes."""
        try:
            sha256 = hashlib.sha256()
            md5 = hashlib.md5()
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(8192), b""):
                    sha256.update(chunk)
                    md5.update(chunk)
            meta.sha256 = sha256.hexdigest()
            meta.md5 = md5.hexdigest()
        except (OSError, PermissionError):
            pass

    def _identify_type(self, file_path: Path, meta: FileMetadata):
        """Identify file type from magic bytes."""
        try:
            with open(file_path, "rb") as f:
                header = f.read(16)
        except (OSError, PermissionError):
            return

        if not header:
            meta.file_type = "empty"
            return

        meta.magic_header = header[:8].hex()

        for magic, file_type in MAGIC_SIGNATURES.items():
            if header.startswith(magic):
                meta.file_type = file_type

                # ZIP-based format disambiguation
                if file_type == "zip_archive":
                    meta.file_type = self._disambiguate_zip(file_path, meta)
                return

        # Script detection
        if header.startswith(b"#!"):
            meta.file_type = "script"
        elif header.startswith((b"<html", b"<!DOCTYPE", b"<HTML")):
            meta.file_type = "html"
        else:
            meta.file_type = "data"

    def _disambiguate_zip(self, file_path: Path, meta: FileMetadata) -> str:
        """Distinguish between ZIP, APK, JAR, DOCX, etc."""
        ext = meta.extension
        if ext == ".apk":
            return "android_apk"
        elif ext == ".aab":
            return "android_bundle"
        elif ext == ".ipa":
            return "ios_app"
        elif ext == ".jar":
            return "java_archive"
        elif ext in (".docx", ".xlsx", ".pptx"):
            return "office_document"
        elif ext == ".xapk":
            return "android_xapk"
        return "zip_archive"

    def _identify_platform(self, meta: FileMetadata):
        """Determine which platform this file targets."""
        type_to_platform = {
            "pe_executable": "windows",
            "elf_executable": "linux",
            "macho_32": "macos", "macho_64": "macos",
            "macho_32_r": "macos", "macho_64_r": "macos",
            "macho_fat": "macos",
            "android_apk": "android", "android_dex": "android",
            "android_bundle": "android", "android_xapk": "android",
            "ios_app": "ios",
        }
        meta.platform_target = type_to_platform.get(meta.file_type, "cross-platform")

    def quick_hash(self, file_path: Path) -> Optional[str]:
        """Quick SHA-256 hash computation."""
        try:
            sha256 = hashlib.sha256()
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(8192), b""):
                    sha256.update(chunk)
            return sha256.hexdigest()
        except (OSError, PermissionError):
            return None
