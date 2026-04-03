import 'package:flutter/foundation.dart';
import 'package:omnix_hub/services/rust_bridge.dart';

/// Service layer for managing signature updates.
/// Wraps RustBridge update calls with state management for the UI.
class UpdateService extends ChangeNotifier {
  final RustBridge _bridge;

  bool _isChecking = false;
  List<UpdateManifestItem> _pendingUpdates = [];
  List<UpdateHistoryRecord> _history = [];
  String? _currentVersion;

  bool get isChecking => _isChecking;
  List<UpdateManifestItem> get pendingUpdates => _pendingUpdates;
  List<UpdateHistoryRecord> get history => _history;
  String? get currentVersion => _currentVersion;
  int get signatureCount => _bridge.signatureCount;

  UpdateService(this._bridge);

  Future<void> refreshAll() async {
    _isChecking = true;
    notifyListeners();

    try {
      _pendingUpdates = await _bridge.getPendingUpdates();
      _history = await _bridge.getUpdateHistory();
      _currentVersion =
          _history.isNotEmpty ? _history.first.version : null;
    } catch (e) {
      debugPrint('Update refresh error: $e');
    }

    _isChecking = false;
    notifyListeners();
  }

  Future<void> applyUpdate(String version) async {
    _isChecking = true;
    notifyListeners();

    try {
      await _bridge.applyUpdate(version);
      await refreshAll();
    } catch (e) {
      _isChecking = false;
      notifyListeners();
      rethrow;
    }
  }
}
