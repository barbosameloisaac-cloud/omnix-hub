"""
OmniShield Heuristic Analysis Engine
Behavioral pattern analysis to detect unknown/zero-day threats.
Uses weighted rule scoring to evaluate file suspiciousness.
"""

import re
import struct
from pathlib import Path
from typing import Optional

from omnishield.config.settings import (
    HEURISTIC_THRESHOLD_HIGH,
    HEURISTIC_THRESHOLD_LOW,
    HEURISTIC_THRESHOLD_MEDIUM,
)


class HeuristicRule:
    """A single heuristic detection rule."""

    def __init__(self, rule_id: str, name: str, description: str,
                 weight: int, category: str):
        self.rule_id = rule_id
        self.name = name
        self.description = description
        self.weight = weight
        self.category = category
        self.triggered = False

    def to_dict(self) -> dict:
        return {
            "rule_id": self.rule_id,
            "name": self.name,
            "description": self.description,
            "weight": self.weight,
            "category": self.category,
            "triggered": self.triggered,
        }


class HeuristicResult:
    """Result of heuristic analysis."""

    def __init__(self, file_path: str, total_score: int,
                 triggered_rules: list[HeuristicRule], risk_level: str):
        self.file_path = file_path
        self.total_score = total_score
        self.triggered_rules = triggered_rules
        self.risk_level = risk_level

    def to_dict(self) -> dict:
        return {
            "file_path": self.file_path,
            "total_score": self.total_score,
            "risk_level": self.risk_level,
            "triggered_rules": [r.to_dict() for r in self.triggered_rules],
        }


class HeuristicEngine:
    """Behavioral heuristic analysis engine."""

    # ── Suspicious API/system call patterns ──────────────────────────────────
    SUSPICIOUS_STRINGS = {
        # Process manipulation
        "process_injection": {
            "patterns": [
                rb"VirtualAllocEx", rb"WriteProcessMemory", rb"CreateRemoteThread",
                rb"NtCreateThreadEx", rb"RtlCreateUserThread",
            ],
            "weight": 25,
            "category": "injection",
            "description": "Process injection API calls detected",
        },
        # Registry manipulation (Windows)
        "registry_persistence": {
            "patterns": [
                rb"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
                rb"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
                rb"CurrentVersion\\Explorer\\Shell Folders",
            ],
            "weight": 20,
            "category": "persistence",
            "description": "Registry persistence mechanism detected",
        },
        # Network activity
        "network_suspicious": {
            "patterns": [
                rb"WSAStartup", rb"InternetOpenUrl", rb"HttpSendRequest",
                rb"URLDownloadToFile", rb"WinHttpConnect",
            ],
            "weight": 10,
            "category": "network",
            "description": "Suspicious network API calls detected",
        },
        # Crypto / ransomware indicators
        "crypto_operations": {
            "patterns": [
                rb"CryptEncrypt", rb"CryptDecrypt", rb"CryptGenKey",
                rb"BCryptEncrypt", rb"AES", rb"Your files have been encrypted",
            ],
            "weight": 20,
            "category": "ransomware",
            "description": "Cryptographic operations suggesting ransomware behavior",
        },
        # Anti-analysis / evasion
        "anti_analysis": {
            "patterns": [
                rb"IsDebuggerPresent", rb"CheckRemoteDebuggerPresent",
                rb"NtQueryInformationProcess", rb"GetTickCount",
                rb"OutputDebugString",
            ],
            "weight": 15,
            "category": "evasion",
            "description": "Anti-debugging/anti-analysis techniques detected",
        },
        # Privilege escalation
        "privilege_escalation": {
            "patterns": [
                rb"AdjustTokenPrivileges", rb"SeDebugPrivilege",
                rb"ImpersonateLoggedOnUser", rb"SetTokenInformation",
            ],
            "weight": 20,
            "category": "privilege_escalation",
            "description": "Privilege escalation attempts detected",
        },
        # Keylogging
        "keylogger": {
            "patterns": [
                rb"SetWindowsHookEx", rb"GetAsyncKeyState",
                rb"GetKeyState", rb"GetKeyboardState",
            ],
            "weight": 25,
            "category": "spyware",
            "description": "Keylogging behavior indicators detected",
        },
        # Shell execution
        "shell_execution": {
            "patterns": [
                rb"cmd.exe /c", rb"powershell.exe -e", rb"powershell -enc",
                rb"/bin/sh -c", rb"/bin/bash -c", rb"os.system(",
                rb"subprocess.call(", rb"exec(",
            ],
            "weight": 15,
            "category": "execution",
            "description": "Shell command execution patterns detected",
        },
        # Data exfiltration
        "data_exfil": {
            "patterns": [
                rb"ftp://", rb"smtp://", rb"EHLO",
                rb"Content-Disposition: attachment",
            ],
            "weight": 10,
            "category": "exfiltration",
            "description": "Potential data exfiltration indicators",
        },
        # macOS specific threats
        "macos_persistence": {
            "patterns": [
                rb"LaunchAgents", rb"LaunchDaemons", rb"loginwindow",
                rb"com.apple.loginitems",
            ],
            "weight": 15,
            "category": "persistence",
            "description": "macOS persistence mechanism detected",
        },
        # Linux specific threats
        "linux_persistence": {
            "patterns": [
                rb"/etc/crontab", rb"/etc/rc.local", rb"/.bashrc",
                rb"/etc/init.d/", rb"systemctl enable",
            ],
            "weight": 15,
            "category": "persistence",
            "description": "Linux persistence mechanism detected",
        },
        # Mobile threats
        "mobile_suspicious": {
            "patterns": [
                rb"android.permission.SEND_SMS",
                rb"android.permission.READ_CONTACTS",
                rb"android.permission.RECORD_AUDIO",
                rb"android.permission.CAMERA",
                rb"getDeviceId", rb"getSubscriberId",
            ],
            "weight": 10,
            "category": "mobile_threat",
            "description": "Suspicious mobile permissions/API usage",
        },
    }

    # ── Suspicious PE header characteristics ─────────────────────────────────
    PE_CHECKS = {
        "tiny_code_section": {
            "weight": 15,
            "description": "Abnormally small code section (possible packer stub)",
        },
        "no_imports": {
            "weight": 20,
            "description": "No import table (dynamic API resolution)",
        },
        "writable_code": {
            "weight": 15,
            "description": "Code section is writable (self-modifying code)",
        },
        "suspicious_section_name": {
            "weight": 10,
            "description": "Non-standard PE section names",
        },
    }

    def analyze_file(self, file_path: Path) -> Optional[HeuristicResult]:
        """Perform full heuristic analysis on a file."""
        try:
            with open(file_path, "rb") as f:
                content = f.read(20 * 1024 * 1024)  # 20MB limit
        except (OSError, PermissionError):
            return None

        triggered_rules: list[HeuristicRule] = []
        total_score = 0

        # String/pattern-based analysis
        for rule_name, rule_def in self.SUSPICIOUS_STRINGS.items():
            for pattern in rule_def["patterns"]:
                if pattern in content:
                    rule = HeuristicRule(
                        rule_id=f"HEUR-{rule_name.upper()}",
                        name=rule_name,
                        description=rule_def["description"],
                        weight=rule_def["weight"],
                        category=rule_def["category"],
                    )
                    rule.triggered = True
                    triggered_rules.append(rule)
                    total_score += rule_def["weight"]
                    break  # Only count each rule once

        # PE header analysis (Windows executables)
        if content[:2] == b"MZ":
            pe_score, pe_rules = self._analyze_pe_header(content)
            total_score += pe_score
            triggered_rules.extend(pe_rules)

        # ELF header analysis (Linux/Android)
        if content[:4] == b"\x7fELF":
            elf_score, elf_rules = self._analyze_elf_header(content)
            total_score += elf_score
            triggered_rules.extend(elf_rules)

        # Mach-O analysis (macOS)
        if content[:4] in (b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf",
                           b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe"):
            macho_score, macho_rules = self._analyze_macho_header(content)
            total_score += macho_score
            triggered_rules.extend(macho_rules)

        # Determine risk level
        if total_score >= HEURISTIC_THRESHOLD_HIGH:
            risk_level = "critical"
        elif total_score >= HEURISTIC_THRESHOLD_MEDIUM:
            risk_level = "high"
        elif total_score >= HEURISTIC_THRESHOLD_LOW:
            risk_level = "suspicious"
        else:
            risk_level = "clean"

        return HeuristicResult(
            file_path=str(file_path),
            total_score=total_score,
            triggered_rules=triggered_rules,
            risk_level=risk_level,
        )

    def _analyze_pe_header(self, content: bytes) -> tuple[int, list[HeuristicRule]]:
        """Analyze PE (Windows executable) header for anomalies."""
        score = 0
        rules: list[HeuristicRule] = []

        try:
            # Get PE header offset
            if len(content) < 64:
                return 0, []
            pe_offset = struct.unpack_from("<I", content, 0x3C)[0]
            if pe_offset > len(content) - 4:
                return 0, []

            # Verify PE signature
            if content[pe_offset:pe_offset + 4] != b"PE\x00\x00":
                return 0, []

            # Check number of sections
            num_sections = struct.unpack_from("<H", content, pe_offset + 6)[0]
            if num_sections == 0 or num_sections > 96:
                rule = HeuristicRule(
                    rule_id="HEUR-PE-SECTIONS",
                    name="abnormal_sections",
                    description=f"Abnormal number of PE sections: {num_sections}",
                    weight=15,
                    category="structure",
                )
                rule.triggered = True
                rules.append(rule)
                score += 15

            # Check optional header for suspicious characteristics
            opt_header_offset = pe_offset + 24
            if len(content) > opt_header_offset + 2:
                magic = struct.unpack_from("<H", content, opt_header_offset)[0]
                if magic in (0x10b, 0x20b):  # PE32 or PE32+
                    # Check entry point
                    entry_rva = struct.unpack_from("<I", content,
                                                   opt_header_offset + 16)[0]
                    if entry_rva == 0:
                        rule = HeuristicRule(
                            rule_id="HEUR-PE-ENTRY",
                            name="zero_entry_point",
                            description="PE entry point is zero",
                            weight=10,
                            category="structure",
                        )
                        rule.triggered = True
                        rules.append(rule)
                        score += 10

        except (struct.error, IndexError):
            pass

        return score, rules

    def _analyze_elf_header(self, content: bytes) -> tuple[int, list[HeuristicRule]]:
        """Analyze ELF (Linux/Android) header for anomalies."""
        score = 0
        rules: list[HeuristicRule] = []

        try:
            if len(content) < 64:
                return 0, []

            # Check ELF class (32 or 64 bit)
            elf_class = content[4]
            if elf_class not in (1, 2):
                rule = HeuristicRule(
                    rule_id="HEUR-ELF-CLASS",
                    name="invalid_elf_class",
                    description="Invalid ELF class byte",
                    weight=15,
                    category="structure",
                )
                rule.triggered = True
                rules.append(rule)
                score += 15

            # Check for stripped binary with unusual section count
            if elf_class == 2:  # 64-bit
                sh_num = struct.unpack_from("<H", content, 60)[0]
                if sh_num == 0:
                    rule = HeuristicRule(
                        rule_id="HEUR-ELF-STRIPPED",
                        name="fully_stripped_elf",
                        description="ELF binary has no sections (fully stripped)",
                        weight=10,
                        category="evasion",
                    )
                    rule.triggered = True
                    rules.append(rule)
                    score += 10

        except (struct.error, IndexError):
            pass

        return score, rules

    def _analyze_macho_header(self, content: bytes
                              ) -> tuple[int, list[HeuristicRule]]:
        """Analyze Mach-O (macOS) header for anomalies."""
        score = 0
        rules: list[HeuristicRule] = []

        try:
            if len(content) < 28:
                return 0, []

            magic = struct.unpack_from("<I", content, 0)[0]
            is_64 = magic in (0xFEEDFACF, 0xCFFAEDFE)

            # Check number of load commands
            ncmds = struct.unpack_from("<I", content, 16)[0]
            if ncmds > 256:
                rule = HeuristicRule(
                    rule_id="HEUR-MACHO-CMDS",
                    name="excessive_load_commands",
                    description=f"Mach-O has {ncmds} load commands (unusual)",
                    weight=10,
                    category="structure",
                )
                rule.triggered = True
                rules.append(rule)
                score += 10

            # Check for unsigned code
            has_codesig = b"__LINKEDIT" in content and b"LC_CODE_SIGNATURE" in content
            if not has_codesig and is_64:
                rule = HeuristicRule(
                    rule_id="HEUR-MACHO-UNSIGNED",
                    name="unsigned_macho",
                    description="Mach-O binary appears to be unsigned",
                    weight=10,
                    category="trust",
                )
                rule.triggered = True
                rules.append(rule)
                score += 10

        except (struct.error, IndexError):
            pass

        return score, rules
