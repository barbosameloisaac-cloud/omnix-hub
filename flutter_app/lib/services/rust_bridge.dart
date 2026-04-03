import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Bridge between Flutter UI and the Rust backend.
///
/// Communication happens via the Rust CLI binary's JSON output mode.
/// The backend binary is expected at a platform-appropriate path.
/// All calls are async and non-blocking.
class RustBridge extends ChangeNotifier {
  String? _backendPath;
  HealthReportData _healthReport = HealthReportData.empty();
  ScanStats _scanStats = ScanStats.zero();
  List<QuarantineItem> _quarantinedItems = [];
  List<EventItem> _recentEvents = [];
  List<RiskAssessmentItem> _riskAssessments = [];
  AppConfigData _config = AppConfigData.defaults();

  HealthReportData get healthReport => _healthReport;
  ScanStats get scanStats => _scanStats;
  List<QuarantineItem> get quarantinedItems => _quarantinedItems;
  List<EventItem> get recentEvents => _recentEvents;
  List<RiskAssessmentItem> get riskAssessments => _riskAssessments;
  AppConfigData get config => _config;

  RustBridge() {
    _detectBackend();
  }

  void _detectBackend() {
    // Look for the backend binary in common locations
    final candidates = [
      '../backend/target/release/omnix-hub',
      '../backend/target/debug/omnix-hub',
      'omnix-hub',
    ];

    if (Platform.isWindows) {
      candidates.addAll([
        '../backend/target/release/omnix-hub.exe',
        '../backend/target/debug/omnix-hub.exe',
      ]);
    }

    for (final path in candidates) {
      if (File(path).existsSync()) {
        _backendPath = path;
        break;
      }
    }
  }

  // ---- Scan ----

  Future<List<ScanResultItem>> scanPath(String path) async {
    final output = await _runBackend(['scan', '--json', path]);
    if (output == null) return _mockScanResults(path);

    try {
      final json = jsonDecode(output) as Map<String, dynamic>;
      final results = (json['results'] as List?)
              ?.map((r) => ScanResultItem.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [];

      _scanStats = ScanStats(
        totalScanned: json['total_files'] as int? ?? results.length,
        clean: json['clean'] as int? ?? 0,
        suspicious: json['suspicious'] as int? ?? 0,
        threats: json['threats'] as int? ?? 0,
      );
      notifyListeners();
      return results;
    } catch (_) {
      return _mockScanResults(path);
    }
  }

  // ---- Quarantine ----

  Future<void> quarantineFile(String filePath) async {
    await _runBackend(['quarantine', '--isolate', filePath]);
    await refreshQuarantine();
  }

  Future<void> restoreFromQuarantine(String id) async {
    await _runBackend(['quarantine', '--restore', id]);
    await refreshQuarantine();
  }

  Future<void> deleteQuarantined(String id) async {
    await _runBackend(['quarantine', '--delete', id]);
    await refreshQuarantine();
  }

  Future<void> refreshQuarantine() async {
    final output = await _runBackend(['quarantine', '--list', '--json']);
    if (output != null) {
      try {
        final list = jsonDecode(output) as List;
        _quarantinedItems =
            list.map((j) => QuarantineItem.fromJson(j as Map<String, dynamic>)).toList();
        notifyListeners();
        return;
      } catch (_) {}
    }
    // Keep current state if backend unavailable
    notifyListeners();
  }

  // ---- Health ----

  Future<void> refreshHealth() async {
    final output = await _runBackend(['health', '--json']);
    if (output != null) {
      try {
        final json = jsonDecode(output) as Map<String, dynamic>;
        _healthReport = HealthReportData.fromJson(json);
        notifyListeners();
        return;
      } catch (_) {}
    }
    // Fallback: mark as healthy with no data
    _healthReport = HealthReportData.empty();
    notifyListeners();
  }

  // ---- Events ----

  Future<void> refreshEvents() async {
    final output = await _runBackend(['events', '--json']);
    if (output != null) {
      try {
        final list = jsonDecode(output) as List;
        _recentEvents =
            list.map((j) => EventItem.fromJson(j as Map<String, dynamic>)).toList();
        notifyListeners();
        return;
      } catch (_) {}
    }
    notifyListeners();
  }

  void clearEvents() {
    _recentEvents = [];
    notifyListeners();
  }

  // ---- Risk ----

  Future<void> refreshRisk() async {
    final output = await _runBackend(['risk', '--json']);
    if (output != null) {
      try {
        final list = jsonDecode(output) as List;
        _riskAssessments = list
            .map((j) => RiskAssessmentItem.fromJson(j as Map<String, dynamic>))
            .toList();
        notifyListeners();
        return;
      } catch (_) {}
    }
    notifyListeners();
  }

  // ---- Updates ----

  Future<List<UpdateManifestItem>> getPendingUpdates() async {
    final output = await _runBackend(['update', '--list-pending', '--json']);
    if (output != null) {
      try {
        final list = jsonDecode(output) as List;
        return list
            .map((j) => UpdateManifestItem.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  Future<List<UpdateHistoryRecord>> getUpdateHistory() async {
    final output = await _runBackend(['update', '--history', '--json']);
    if (output != null) {
      try {
        final list = jsonDecode(output) as List;
        return list
            .map((j) => UpdateHistoryRecord.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> applyUpdate(String version) async {
    await _runBackend(['update', '--apply', version]);
  }

  int get signatureCount => 2; // matches current Rust SignatureDatabase

  // ---- Config ----

  void updateConfig({
    int? maxFileSizeMb,
    double? heuristicThreshold,
    bool? scanHiddenFiles,
    int? monitorIntervalSecs,
    int? dedupWindowSecs,
  }) {
    _config = _config.copyWith(
      maxFileSizeMb: maxFileSizeMb,
      heuristicThreshold: heuristicThreshold,
      scanHiddenFiles: scanHiddenFiles,
      monitorIntervalSecs: monitorIntervalSecs,
      dedupWindowSecs: dedupWindowSecs,
    );
    notifyListeners();
    // Persist to backend
    _runBackend([
      'config',
      '--set',
      jsonEncode(_config.toJson()),
    ]);
  }

  // ---- Backend process runner ----

  Future<String?> _runBackend(List<String> args) async {
    if (_backendPath == null) return null;

    try {
      final result = await Process.run(_backendPath!, args,
          environment: {'RUST_LOG': 'warn'});
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
      debugPrint('Backend error: ${result.stderr}');
      return null;
    } catch (e) {
      debugPrint('Failed to run backend: $e');
      return null;
    }
  }

  // ---- Mock data for when backend is not available ----

  List<ScanResultItem> _mockScanResults(String path) {
    _scanStats = ScanStats.zero();
    return [];
  }
}

// ---- Data Models ----

class ScanStats {
  final int totalScanned;
  final int clean;
  final int suspicious;
  final int threats;

  ScanStats({
    required this.totalScanned,
    required this.clean,
    required this.suspicious,
    required this.threats,
  });

  factory ScanStats.zero() =>
      ScanStats(totalScanned: 0, clean: 0, suspicious: 0, threats: 0);
}

class ScanResultItem {
  final String filePath;
  final String fileName;
  final String sha256;
  final String fileSize;
  final String verdict;
  final String? signatureMatch;
  final double heuristicScore;
  final List<IndicatorItem> indicators;

  ScanResultItem({
    required this.filePath,
    required this.fileName,
    required this.sha256,
    required this.fileSize,
    required this.verdict,
    this.signatureMatch,
    required this.heuristicScore,
    required this.indicators,
  });

  factory ScanResultItem.fromJson(Map<String, dynamic> json) {
    final path = json['file_path'] as String? ?? '';
    return ScanResultItem(
      filePath: path,
      fileName: path.split(Platform.pathSeparator).last,
      sha256: json['sha256'] as String? ?? '',
      fileSize: _humanSize(json['file_size'] as int? ?? 0),
      verdict: json['verdict'] as String? ?? 'CLEAN',
      signatureMatch: json['signature_match'] as String?,
      heuristicScore: (json['heuristic_score'] as num?)?.toDouble() ?? 0.0,
      indicators: (json['indicators'] as List?)
              ?.map((i) => IndicatorItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class IndicatorItem {
  final String rule;
  final String description;
  final double score;

  IndicatorItem(
      {required this.rule, required this.description, required this.score});

  factory IndicatorItem.fromJson(Map<String, dynamic> json) => IndicatorItem(
        rule: json['rule'] as String? ?? '',
        description: json['description'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
      );
}

class QuarantineItem {
  final String id;
  final String originalPath;
  final String sha256;
  final String reason;
  final String quarantinedAt;

  QuarantineItem({
    required this.id,
    required this.originalPath,
    required this.sha256,
    required this.reason,
    required this.quarantinedAt,
  });

  factory QuarantineItem.fromJson(Map<String, dynamic> json) => QuarantineItem(
        id: json['id'] as String? ?? '',
        originalPath: json['original_path'] as String? ?? '',
        sha256: json['sha256'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        quarantinedAt: json['quarantined_at'] as String? ?? '',
      );
}

class EventItem {
  final String id;
  final String kind;
  final String source;
  final String detail;
  final String timestamp;
  final double riskScore;

  EventItem({
    required this.id,
    required this.kind,
    required this.source,
    required this.detail,
    required this.timestamp,
    required this.riskScore,
  });

  factory EventItem.fromJson(Map<String, dynamic> json) => EventItem(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? 'UNKNOWN',
        source: json['source'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        timestamp: json['timestamp'] as String? ?? '',
        riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      );
}

class HealthReportData {
  final String overallStatus;
  final int uptimeSecs;
  final List<ComponentHealth> components;
  final List<String> warnings;

  HealthReportData({
    required this.overallStatus,
    required this.uptimeSecs,
    required this.components,
    required this.warnings,
  });

  factory HealthReportData.empty() => HealthReportData(
        overallStatus: 'HEALTHY',
        uptimeSecs: 0,
        components: [],
        warnings: [],
      );

  factory HealthReportData.fromJson(Map<String, dynamic> json) =>
      HealthReportData(
        overallStatus: json['overall_status'] as String? ?? 'UNKNOWN',
        uptimeSecs: json['uptime_secs'] as int? ?? 0,
        components: (json['components'] as List?)
                ?.map((c) =>
                    ComponentHealth.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        warnings: (json['warnings'] as List?)
                ?.map((w) => w.toString())
                .toList() ??
            [],
      );
}

class ComponentHealth {
  final String name;
  final String status;
  final String detail;

  ComponentHealth(
      {required this.name, required this.status, required this.detail});

  factory ComponentHealth.fromJson(Map<String, dynamic> json) =>
      ComponentHealth(
        name: json['name'] as String? ?? '',
        status: json['status'] as String? ?? 'UNKNOWN',
        detail: json['detail'] as String? ?? '',
      );
}

class RiskAssessmentItem {
  final String subject;
  final double totalScore;
  final String level;
  final List<RiskFactorItem> factors;

  RiskAssessmentItem({
    required this.subject,
    required this.totalScore,
    required this.level,
    required this.factors,
  });

  factory RiskAssessmentItem.fromJson(Map<String, dynamic> json) =>
      RiskAssessmentItem(
        subject: json['subject'] as String? ?? '',
        totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
        level: json['level'] as String? ?? 'NONE',
        factors: (json['factors'] as List?)
                ?.map((f) =>
                    RiskFactorItem.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class RiskFactorItem {
  final String name;
  final double contribution;
  final String explanation;

  RiskFactorItem({
    required this.name,
    required this.contribution,
    required this.explanation,
  });

  factory RiskFactorItem.fromJson(Map<String, dynamic> json) =>
      RiskFactorItem(
        name: json['name'] as String? ?? '',
        contribution: (json['contribution'] as num?)?.toDouble() ?? 0.0,
        explanation: json['explanation'] as String? ?? '',
      );
}

class UpdateManifestItem {
  final String version;
  final String description;
  final int signaturesCount;

  UpdateManifestItem({
    required this.version,
    required this.description,
    required this.signaturesCount,
  });

  factory UpdateManifestItem.fromJson(Map<String, dynamic> json) =>
      UpdateManifestItem(
        version: json['version'] as String? ?? '',
        description: json['description'] as String? ?? '',
        signaturesCount: json['signatures_count'] as int? ?? 0,
      );
}

class UpdateHistoryRecord {
  final String version;
  final String appliedAt;
  final int signaturesAdded;
  final String status;

  UpdateHistoryRecord({
    required this.version,
    required this.appliedAt,
    required this.signaturesAdded,
    required this.status,
  });

  factory UpdateHistoryRecord.fromJson(Map<String, dynamic> json) =>
      UpdateHistoryRecord(
        version: json['version'] as String? ?? '',
        appliedAt: json['applied_at'] as String? ?? '',
        signaturesAdded: json['signatures_added'] as int? ?? 0,
        status: json['status'] as String? ?? '',
      );
}

class AppConfigData {
  final int maxFileSizeMb;
  final double heuristicThreshold;
  final bool scanHiddenFiles;
  final int monitorIntervalSecs;
  final int dedupWindowSecs;
  final String databasePath;
  final String quarantineDir;
  final String logDir;

  AppConfigData({
    required this.maxFileSizeMb,
    required this.heuristicThreshold,
    required this.scanHiddenFiles,
    required this.monitorIntervalSecs,
    required this.dedupWindowSecs,
    required this.databasePath,
    required this.quarantineDir,
    required this.logDir,
  });

  factory AppConfigData.defaults() => AppConfigData(
        maxFileSizeMb: 100,
        heuristicThreshold: 0.7,
        scanHiddenFiles: false,
        monitorIntervalSecs: 30,
        dedupWindowSecs: 60,
        databasePath: 'omnix_hub.db',
        quarantineDir: 'quarantine',
        logDir: 'logs',
      );

  AppConfigData copyWith({
    int? maxFileSizeMb,
    double? heuristicThreshold,
    bool? scanHiddenFiles,
    int? monitorIntervalSecs,
    int? dedupWindowSecs,
  }) =>
      AppConfigData(
        maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
        heuristicThreshold: heuristicThreshold ?? this.heuristicThreshold,
        scanHiddenFiles: scanHiddenFiles ?? this.scanHiddenFiles,
        monitorIntervalSecs: monitorIntervalSecs ?? this.monitorIntervalSecs,
        dedupWindowSecs: dedupWindowSecs ?? this.dedupWindowSecs,
        databasePath: databasePath,
        quarantineDir: quarantineDir,
        logDir: logDir,
      );

  Map<String, dynamic> toJson() => {
        'max_file_size_mb': maxFileSizeMb,
        'heuristic_threshold': heuristicThreshold,
        'scan_hidden_files': scanHiddenFiles,
        'monitor_interval_secs': monitorIntervalSecs,
        'dedup_window_secs': dedupWindowSecs,
      };
}

String _humanSize(int bytes) {
  if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
