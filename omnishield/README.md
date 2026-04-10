# OmniShield — Cross-Platform Futuristic Antivirus Engine

**NeonCore v1.0.0** | 100% Free | Open Source

A next-generation antivirus engine with a futuristic holographic web interface, multi-layer threat detection, and cross-platform support for **Windows, macOS, Linux, Android, and iOS**.

---

## Features

### Multi-Layer Detection Engine
- **Signature Engine** — SHA-256 hash matching + byte-pattern scanning + regex string detection
- **Heuristic Engine** — Behavioral analysis with weighted rules for Windows, macOS, Linux, and mobile threats
- **Entropy Analyzer** — Shannon entropy analysis to detect packed, encrypted, or obfuscated malware
- **File Analyzer** — Magic-byte identification for PE, ELF, Mach-O, APK, DEX, and 20+ formats

### Real-Time Protection
- Filesystem monitoring with automatic scanning of new/modified files
- Configurable watched directories
- Auto-quarantine for critical threats

### Quarantine Vault
- XOR-encrypted isolation prevents accidental execution
- Full restore capability with original path preservation
- Permanent deletion option

### Futuristic Web Dashboard
- Neon/holographic cyberpunk aesthetic
- Responsive design works on phones, tablets, and desktops
- Live scan progress with animated ring visualization
- Threat history and quarantine management
- Engine status monitoring

### CLI Interface
- Full command-line control for headless environments
- Colored terminal output
- Scriptable for automation

---

## Supported Platforms

| Platform | Method | Status |
|----------|--------|--------|
| **Windows** 10/11 | Native Python | Full Support |
| **macOS** (Intel/Apple Silicon) | Native Python | Full Support |
| **Linux** (Ubuntu, Fedora, Arch, etc.) | Native Python | Full Support |
| **Android** | Termux / Pydroid 3 | Full Support |
| **iOS/iPadOS** | Web Dashboard via Safari | Dashboard Only |
| **ChromeOS** | Linux container | Full Support |

---

## Quick Start

### Prerequisites
- Python 3.9+
- pip

### Installation

```bash
# Clone the repository
git clone https://github.com/barbosameloisaac-cloud/omnix-hub.git
cd omnix-hub

# Install dependencies
pip install -r omnishield/requirements.txt

# Run OmniShield
python -m omnishield
```

### Mobile Installation (Android via Termux)

```bash
# Install Termux from F-Droid
pkg install python
pip install -r omnishield/requirements.txt
python -m omnishield
# Open http://localhost:7443 in your phone browser
```

---

## Usage

### Launch Web Dashboard
```bash
python -m omnishield dashboard
# Opens at http://localhost:7443 — accessible from any device on your network
```

### Scan a File
```bash
python -m omnishield scan /path/to/suspicious/file.exe
```

### Scan a Directory
```bash
python -m omnishield scan /home/user/Downloads
python -m omnishield scan /home/user/Downloads --all-files  # Scan all file types
```

### Quick Scan (Common Locations)
```bash
python -m omnishield quick
python -m omnishield quick --quarantine  # Auto-quarantine threats
```

### Real-Time Monitoring
```bash
python -m omnishield monitor                    # Monitor default locations
python -m omnishield monitor /home/user/Downloads --quarantine
```

### Check Engine Status
```bash
python -m omnishield status
```

---

## REST API

The dashboard exposes a full REST API at `http://localhost:7443/api/`:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/status` | GET | System status |
| `/api/stats` | GET | Threat statistics |
| `/api/scan/file` | POST | Scan a single file |
| `/api/scan/directory` | POST | Scan a directory |
| `/api/scan/quick` | POST | Quick scan |
| `/api/scan/progress` | GET | Current scan progress |
| `/api/scan/abort` | POST | Abort current scan |
| `/api/threats` | GET | Threat history |
| `/api/quarantine` | GET | Quarantine list |
| `/api/quarantine/restore` | POST | Restore file |
| `/api/quarantine/delete` | POST | Delete quarantined file |
| `/api/monitor/start` | POST | Start real-time monitor |
| `/api/monitor/stop` | POST | Stop monitor |
| `/api/monitor/status` | GET | Monitor status |

---

## Architecture

```
omnishield/
├── main.py                 # CLI entry point
├── __main__.py             # python -m support
├── config/
│   └── settings.py         # Central configuration
├── core/
│   ├── scanner.py          # Main scan orchestrator
│   ├── signatures.py       # Signature matching engine
│   ├── heuristics.py       # Behavioral heuristic engine
│   ├── entropy.py          # Shannon entropy analyzer
│   ├── file_analyzer.py    # File type identification
│   ├── threat_db.py        # SQLite threat database
│   ├── quarantine.py       # Quarantine vault system
│   └── monitor.py          # Real-time filesystem monitor
├── api/
│   └── server.py           # FastAPI REST API
├── ui/
│   ├── index.html          # Dashboard HTML
│   ├── css/omnishield.css  # Futuristic UI styles
│   └── js/omnishield.js    # Dashboard logic
├── signatures/
│   └── malware_signatures.json  # Signature database
└── tests/
    └── test_scanner.py     # Unit tests
```

---

## Detection Methods

### 1. Signature-Based Detection
Compares file hashes (SHA-256) and byte patterns against a known malware database. Includes EICAR test file detection for verification.

### 2. Heuristic Behavioral Analysis
Scans for suspicious API calls, persistence mechanisms, and behavioral patterns across platforms:
- **Windows**: Process injection, registry persistence, PowerShell encoding
- **macOS**: LaunchAgent persistence, unsigned Mach-O binaries
- **Linux**: Crontab persistence, init.d manipulation
- **Mobile**: SMS fraud, excessive permissions, device ID harvesting
- **Cross-platform**: Reverse shells, crypto miners, keyloggers, ransomware

### 3. Entropy Analysis
Uses Shannon entropy to detect:
- Packed executables (UPX, custom packers)
- Encrypted payloads
- Obfuscated malware
- Polymorphic threats

### 4. Structural Analysis
Inspects binary headers (PE, ELF, Mach-O) for anomalies:
- Abnormal section counts
- Missing import tables
- Writable code sections
- Unsigned binaries

---

## Running Tests

```bash
cd omnix-hub
python -m pytest omnishield/tests/ -v
```

---

## License

MIT License — 100% free for personal and commercial use.
