"""
OmniShield REST API Server
FastAPI-powered API serving the web dashboard and providing
scan control, threat management, and real-time status endpoints.
"""

import asyncio
import logging
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from omnishield import __codename__, __version__
from omnishield.config.settings import API_CORS_ORIGINS, API_HOST, API_PORT
from omnishield.core.monitor import RealtimeMonitor
from omnishield.core.scanner import OmniScanner

logger = logging.getLogger("omnishield.api")

# ── App Setup ─────────────────────────────────────────────────────────────────
app = FastAPI(
    title="OmniShield",
    description="Cross-Platform Futuristic Antivirus Engine",
    version=__version__,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=API_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Global State ──────────────────────────────────────────────────────────────
scanner = OmniScanner()
monitor = RealtimeMonitor(scanner=scanner)
_scan_task: Optional[asyncio.Task] = None

# ── Static Files (UI) ────────────────────────────────────────────────────────
UI_DIR = Path(__file__).resolve().parent.parent / "ui"
if UI_DIR.exists():
    app.mount("/css", StaticFiles(directory=str(UI_DIR / "css")), name="css")
    app.mount("/js", StaticFiles(directory=str(UI_DIR / "js")), name="js")


# ── Request Models ────────────────────────────────────────────────────────────
class ScanRequest(BaseModel):
    path: str
    recursive: bool = True
    auto_quarantine: bool = False
    scan_all_files: bool = False


class QuickScanRequest(BaseModel):
    paths: Optional[list[str]] = None
    auto_quarantine: bool = False


class MonitorRequest(BaseModel):
    paths: Optional[list[str]] = None
    auto_quarantine: bool = False
    recursive: bool = True


class QuarantineAction(BaseModel):
    quarantine_id: int


class ScanFileRequest(BaseModel):
    path: str
    auto_quarantine: bool = False


# ── Dashboard ─────────────────────────────────────────────────────────────────
@app.get("/", response_class=HTMLResponse)
async def dashboard():
    """Serve the OmniShield dashboard."""
    index = UI_DIR / "index.html"
    if index.exists():
        return FileResponse(str(index))
    return HTMLResponse("<h1>OmniShield API Active</h1>")


# ── System Status ─────────────────────────────────────────────────────────────
@app.get("/api/status")
async def get_status():
    """Get full system status."""
    return {
        "engine": "OmniShield",
        "version": __version__,
        "codename": __codename__,
        "engines": scanner.get_engine_status(),
        "monitor": monitor.get_status(),
        "scan_active": _scan_task is not None and not _scan_task.done()
                       if _scan_task else False,
    }


@app.get("/api/stats")
async def get_stats():
    """Get threat statistics."""
    return scanner.threat_db.get_stats()


# ── Scanning ──────────────────────────────────────────────────────────────────
@app.post("/api/scan/file")
async def scan_single_file(req: ScanFileRequest):
    """Scan a single file."""
    file_path = Path(req.path)
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    if not file_path.is_file():
        raise HTTPException(status_code=400, detail="Path is not a file")

    result = await asyncio.to_thread(
        scanner.scan_file, file_path, req.auto_quarantine
    )
    return result.to_dict()


@app.post("/api/scan/directory")
async def scan_directory(req: ScanRequest):
    """Start a directory scan."""
    global _scan_task
    target = Path(req.path)
    if not target.exists():
        raise HTTPException(status_code=404, detail="Directory not found")
    if not target.is_dir():
        raise HTTPException(status_code=400, detail="Path is not a directory")

    async def run_scan():
        return await asyncio.to_thread(
            scanner.scan_directory,
            target, req.recursive, req.auto_quarantine, req.scan_all_files,
        )

    _scan_task = asyncio.create_task(run_scan())
    return {
        "message": "Scan started",
        "scan_id": scanner.progress.scan_id if scanner.progress else None,
    }


@app.post("/api/scan/quick")
async def quick_scan(req: QuickScanRequest):
    """Start a quick scan of common locations."""
    global _scan_task

    async def run_scan():
        return await asyncio.to_thread(
            scanner.quick_scan, req.paths, req.auto_quarantine,
        )

    _scan_task = asyncio.create_task(run_scan())
    return {"message": "Quick scan started"}


@app.get("/api/scan/progress")
async def scan_progress():
    """Get current scan progress."""
    if scanner.progress:
        return scanner.progress.to_dict()
    return {"status": "idle", "progress_percent": 0}


@app.post("/api/scan/abort")
async def abort_scan():
    """Abort the current scan."""
    scanner.abort_scan()
    return {"message": "Scan abort requested"}


# ── Threat History ────────────────────────────────────────────────────────────
@app.get("/api/threats")
async def get_threats(limit: int = 50):
    """Get recent threat detections."""
    return scanner.threat_db.get_recent_threats(limit)


@app.get("/api/scans")
async def get_scans(limit: int = 20):
    """Get recent scan history."""
    return scanner.threat_db.get_recent_scans(limit)


# ── Quarantine ────────────────────────────────────────────────────────────────
@app.get("/api/quarantine")
async def list_quarantine():
    """List quarantined files."""
    return scanner.quarantine.list_quarantined()


@app.post("/api/quarantine/restore")
async def restore_quarantine(action: QuarantineAction):
    """Restore a quarantined file."""
    result = scanner.quarantine.restore_file(action.quarantine_id)
    if result:
        return {"message": "File restored", "path": result}
    raise HTTPException(status_code=404, detail="Quarantine entry not found")


@app.post("/api/quarantine/delete")
async def delete_quarantine(action: QuarantineAction):
    """Permanently delete a quarantined file."""
    success = scanner.quarantine.delete_quarantined(action.quarantine_id)
    if success:
        return {"message": "Quarantined file deleted"}
    raise HTTPException(status_code=404, detail="Quarantine entry not found")


# ── Real-time Monitor ────────────────────────────────────────────────────────
@app.post("/api/monitor/start")
async def start_monitor(req: MonitorRequest):
    """Start real-time file monitoring."""
    if monitor.is_running:
        return {"message": "Monitor already running", "status": monitor.get_status()}

    await asyncio.to_thread(
        monitor.start, req.paths, req.recursive,
    )
    monitor.auto_quarantine = req.auto_quarantine
    return {"message": "Real-time monitor started", "status": monitor.get_status()}


@app.post("/api/monitor/stop")
async def stop_monitor():
    """Stop real-time file monitoring."""
    await asyncio.to_thread(monitor.stop)
    return {"message": "Real-time monitor stopped"}


@app.get("/api/monitor/status")
async def monitor_status():
    """Get monitor status."""
    return monitor.get_status()


# ── Server Runner ─────────────────────────────────────────────────────────────
def run_server(host: str = API_HOST, port: int = API_PORT):
    """Run the API server."""
    import uvicorn
    logger.info(f"[API] OmniShield v{__version__} ({__codename__})")
    logger.info(f"[API] Dashboard: http://{host}:{port}")
    uvicorn.run(app, host=host, port=port, log_level="info")
