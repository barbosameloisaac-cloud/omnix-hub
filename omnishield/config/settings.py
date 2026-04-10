"""
OmniShield Configuration
Central configuration for all engine parameters.
"""

import os
import platform
from pathlib import Path


# ── System Detection ──────────────────────────────────────────────────────────
PLATFORM = platform.system().lower()  # 'windows', 'linux', 'darwin'
IS_WINDOWS = PLATFORM == "windows"
IS_MACOS = PLATFORM == "darwin"
IS_LINUX = PLATFORM == "linux"
IS_MOBILE = os.environ.get("OMNISHIELD_MOBILE", "0") == "1"

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
QUARANTINE_DIR = DATA_DIR / "quarantine"
LOGS_DIR = DATA_DIR / "logs"
SIGNATURES_DIR = BASE_DIR / "signatures"
THREAT_DB_PATH = DATA_DIR / "threats.db"

# Create directories on import
for d in [DATA_DIR, QUARANTINE_DIR, LOGS_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# ── Scan Settings ─────────────────────────────────────────────────────────────
MAX_FILE_SIZE_MB = 512
SCAN_EXTENSIONS = {
    "executable": {".exe", ".dll", ".sys", ".drv", ".scr", ".com", ".bat", ".cmd",
                   ".ps1", ".vbs", ".js", ".wsf", ".msi", ".pif"},
    "script": {".py", ".rb", ".pl", ".sh", ".bash", ".php", ".lua", ".jar"},
    "document": {".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".pdf",
                 ".rtf", ".odt"},
    "archive": {".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz"},
    "macos": {".app", ".dmg", ".pkg", ".dylib", ".kext"},
    "linux": {".so", ".deb", ".rpm", ".AppImage", ".snap", ".flatpak"},
    "mobile": {".apk", ".ipa", ".aab", ".xapk"},
}
ALL_SCAN_EXTENSIONS = set()
for ext_set in SCAN_EXTENSIONS.values():
    ALL_SCAN_EXTENSIONS.update(ext_set)

# ── Entropy Thresholds ────────────────────────────────────────────────────────
ENTROPY_SUSPICIOUS = 6.8   # Possible packing
ENTROPY_DANGEROUS = 7.2    # Likely packed/encrypted malware
ENTROPY_BLOCK_SIZE = 256

# ── Heuristic Weights ────────────────────────────────────────────────────────
HEURISTIC_THRESHOLD_LOW = 30       # Suspicious
HEURISTIC_THRESHOLD_MEDIUM = 55    # Likely malicious
HEURISTIC_THRESHOLD_HIGH = 75      # Confirmed threat

# ── Real-time Monitor ────────────────────────────────────────────────────────
MONITOR_RECURSIVE = True
MONITOR_DEBOUNCE_SECONDS = 1.0

# ── API Server ────────────────────────────────────────────────────────────────
API_HOST = "0.0.0.0"
API_PORT = 7443
API_CORS_ORIGINS = ["*"]  # In production, restrict this

# ── Scan Directories (default per platform) ──────────────────────────────────
if IS_WINDOWS:
    DEFAULT_SCAN_PATHS = [
        os.path.expanduser("~\\Downloads"),
        os.path.expanduser("~\\Desktop"),
        os.path.expanduser("~\\Documents"),
    ]
    DEFAULT_MONITOR_PATHS = [
        os.path.expanduser("~\\Downloads"),
    ]
elif IS_MACOS:
    DEFAULT_SCAN_PATHS = [
        os.path.expanduser("~/Downloads"),
        os.path.expanduser("~/Desktop"),
        os.path.expanduser("~/Documents"),
        "/Applications",
    ]
    DEFAULT_MONITOR_PATHS = [
        os.path.expanduser("~/Downloads"),
    ]
else:  # Linux / Android (Termux)
    DEFAULT_SCAN_PATHS = [
        os.path.expanduser("~/Downloads"),
        os.path.expanduser("~/Desktop"),
        os.path.expanduser("~/Documents"),
        "/tmp",
    ]
    DEFAULT_MONITOR_PATHS = [
        os.path.expanduser("~/Downloads"),
    ]
