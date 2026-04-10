#!/usr/bin/env python3
"""
OmniShield — Cross-Platform Futuristic Antivirus
Main entry point with CLI interface.

Usage:
    python -m omnishield                    # Launch dashboard (API + UI)
    python -m omnishield scan <path>        # Scan a file or directory
    python -m omnishield quick              # Quick scan common locations
    python -m omnishield monitor [path]     # Start real-time monitoring
    python -m omnishield status             # Show engine status
"""

import argparse
import json
import logging
import sys
from pathlib import Path

from omnishield import __codename__, __version__

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("omnishield")

# ── Banner ────────────────────────────────────────────────────────────────────
BANNER = f"""
\033[96m
   ____                  _ ____  _     _      _     _
  / __ \\                (_) __ \\| |   (_)    | |   | |
 | |  | |_ __ ___  _ __  | |__) | |__  _  ___| | __| |
 | |  | | '_ ` _ \\| '_ \\ |  ___/| '_ \\| |/ _ \\ |/ _` |
 | |__| | | | | | | | | || |    | | | | |  __/ | (_| |
  \\____/|_| |_| |_|_| |_||_|    |_| |_|_|\\___|_|\\__,_|
\033[0m
  \033[95mv{__version__}\033[0m | \033[93m{__codename__}\033[0m | Cross-Platform Antivirus Engine
  ─────────────────────────────────────────────────────
"""


def cmd_dashboard(args):
    """Launch the web dashboard."""
    from omnishield.api.server import run_server
    print(BANNER)
    host = args.host if hasattr(args, 'host') else "0.0.0.0"
    port = args.port if hasattr(args, 'port') else 7443
    logger.info(f"Launching OmniShield Dashboard on http://{host}:{port}")
    logger.info("Open this URL in any browser (phone, tablet, computer, MacBook)")
    run_server(host=host, port=port)


def cmd_scan(args):
    """Scan a file or directory."""
    from omnishield.core.scanner import OmniScanner
    print(BANNER)

    scanner = OmniScanner()
    target = Path(args.path).resolve()

    if not target.exists():
        logger.error(f"Path not found: {target}")
        sys.exit(1)

    if target.is_file():
        logger.info(f"Scanning file: {target}")
        result = scanner.scan_file(target, auto_quarantine=args.quarantine)
        print_file_result(result)
    elif target.is_dir():
        logger.info(f"Scanning directory: {target}")
        progress = scanner.scan_directory(
            target,
            recursive=not args.no_recursive,
            auto_quarantine=args.quarantine,
            scan_all_files=args.all_files,
        )
        print_scan_summary(progress)
    else:
        logger.error(f"Invalid path: {target}")
        sys.exit(1)


def cmd_quick(args):
    """Quick scan common locations."""
    from omnishield.core.scanner import OmniScanner
    print(BANNER)

    scanner = OmniScanner()
    logger.info("Starting quick scan of common locations...")
    progress = scanner.quick_scan(auto_quarantine=args.quarantine)
    print_scan_summary(progress)


def cmd_monitor(args):
    """Start real-time file monitoring."""
    from omnishield.core.monitor import RealtimeMonitor
    from omnishield.core.scanner import OmniScanner, ScanResult
    print(BANNER)

    def on_threat(result: ScanResult):
        logger.warning(
            f"\033[91m[THREAT] {result.risk_level.upper()}: "
            f"{result.file_path} (score: {result.risk_score})\033[0m"
        )
        for t in result.threats:
            logger.warning(f"  -> {t.get('name', 'Unknown')}: {t.get('description', '')}")

    scanner = OmniScanner()
    monitor = RealtimeMonitor(
        scanner=scanner,
        auto_quarantine=args.quarantine,
        on_threat=on_threat,
    )

    paths = [args.path] if args.path else None
    monitor.start(paths=paths)

    logger.info("Real-time protection is ACTIVE. Press Ctrl+C to stop.")
    try:
        import time
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("\nStopping real-time monitor...")
        monitor.stop()
        logger.info("Monitor stopped. Goodbye!")


def cmd_status(args):
    """Show engine status."""
    from omnishield.core.scanner import OmniScanner
    print(BANNER)

    scanner = OmniScanner()
    status = scanner.get_engine_status()
    print(json.dumps(status, indent=2))


def print_file_result(result):
    """Print scan result for a single file."""
    if result.clean:
        print(f"\n  \033[92m[CLEAN]\033[0m {result.file_path}")
        print(f"  Scan time: {result.scan_time_ms:.1f}ms\n")
    else:
        print(f"\n  \033[91m[THREAT]\033[0m {result.file_path}")
        print(f"  Risk Level: \033[91m{result.risk_level.upper()}\033[0m")
        print(f"  Risk Score: {result.risk_score}/100")
        for t in result.threats:
            print(f"  -> {t.get('name', 'Unknown')}: {t.get('description', '')}")
        print(f"  Scan time: {result.scan_time_ms:.1f}ms\n")


def print_scan_summary(progress):
    """Print scan summary."""
    print(f"\n{'='*60}")
    print(f"  SCAN COMPLETE — {progress.status.upper()}")
    print(f"{'='*60}")
    print(f"  Files scanned:  {progress.scanned_files}")
    print(f"  Threats found:  {progress.threats_found}")
    print(f"  Duration:       {progress.elapsed_seconds}s")

    if progress.threats_found > 0:
        print(f"\n  \033[91mThreats detected:\033[0m")
        for result in progress.results:
            if not result.clean:
                print(f"    [{result.risk_level.upper()}] {result.file_path}")
                for t in result.threats:
                    print(f"      -> {t.get('name', 'Unknown')}")
    else:
        print(f"\n  \033[92mNo threats detected. System is clean.\033[0m")
    print()


# ── Argument Parser ───────────────────────────────────────────────────────────
def build_parser():
    parser = argparse.ArgumentParser(
        prog="omnishield",
        description="OmniShield — Cross-Platform Futuristic Antivirus Engine",
    )
    parser.add_argument("--version", action="version",
                        version=f"OmniShield v{__version__} ({__codename__})")

    subparsers = parser.add_subparsers(dest="command")

    # Dashboard
    dash_parser = subparsers.add_parser("dashboard", help="Launch web dashboard")
    dash_parser.add_argument("--host", default="0.0.0.0", help="Bind host")
    dash_parser.add_argument("--port", type=int, default=7443, help="Bind port")

    # Scan
    scan_parser = subparsers.add_parser("scan", help="Scan a file or directory")
    scan_parser.add_argument("path", help="Path to scan")
    scan_parser.add_argument("-q", "--quarantine", action="store_true",
                             help="Auto-quarantine threats")
    scan_parser.add_argument("--no-recursive", action="store_true",
                             help="Don't scan subdirectories")
    scan_parser.add_argument("--all-files", action="store_true",
                             help="Scan all file types")

    # Quick scan
    quick_parser = subparsers.add_parser("quick", help="Quick scan common locations")
    quick_parser.add_argument("-q", "--quarantine", action="store_true",
                              help="Auto-quarantine threats")

    # Monitor
    mon_parser = subparsers.add_parser("monitor", help="Start real-time monitoring")
    mon_parser.add_argument("path", nargs="?", default=None,
                            help="Path to monitor (default: ~/Downloads)")
    mon_parser.add_argument("-q", "--quarantine", action="store_true",
                            help="Auto-quarantine threats")

    # Status
    subparsers.add_parser("status", help="Show engine status")

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    commands = {
        "dashboard": cmd_dashboard,
        "scan": cmd_scan,
        "quick": cmd_quick,
        "monitor": cmd_monitor,
        "status": cmd_status,
    }

    if args.command in commands:
        commands[args.command](args)
    else:
        # Default: launch dashboard
        print(BANNER)
        logger.info("No command specified. Launching dashboard...")
        logger.info("Use 'omnishield --help' for all commands.")

        # Default launch
        args.host = "0.0.0.0"
        args.port = 7443
        cmd_dashboard(args)


if __name__ == "__main__":
    main()
