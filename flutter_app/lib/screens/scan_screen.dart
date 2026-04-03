import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:omnix_hub/services/rust_bridge.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _scanning = false;
  List<ScanResultItem> _results = [];
  String? _scanPath;

  Future<void> _pickAndScan() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select directory to scan',
    );

    if (result == null) return;

    setState(() {
      _scanning = true;
      _scanPath = result;
      _results = [];
    });

    final bridge = context.read<RustBridge>();
    try {
      final results = await bridge.scanPath(result);
      setState(() {
        _results = results;
        _scanning = false;
      });
    } catch (e) {
      setState(() => _scanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Scanner'),
        actions: [
          if (_results.isNotEmpty)
            Chip(
              label: Text(
                  '${_results.length} file(s)',
                  style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _pickAndScan,
        icon: _scanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.play_arrow),
        label: Text(_scanning ? 'Scanning...' : 'Start Scan'),
      ),
      body: _results.isEmpty
          ? _buildEmptyState()
          : _buildResults(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _scanning
                ? 'Scanning $_scanPath ...'
                : 'Select a directory to scan',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (_scanning) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildResults() {
    final threats = _results.where((r) => r.verdict == 'THREAT').toList();
    final suspicious =
        _results.where((r) => r.verdict == 'SUSPICIOUS').toList();
    final clean = _results.where((r) => r.verdict == 'CLEAN').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(threats.length, suspicious.length, clean.length),
        const SizedBox(height: 16),
        if (threats.isNotEmpty) ...[
          _sectionHeader('Threats', Colors.red, threats.length),
          ...threats.map(_buildResultTile),
          const SizedBox(height: 12),
        ],
        if (suspicious.isNotEmpty) ...[
          _sectionHeader('Suspicious', Colors.orange, suspicious.length),
          ...suspicious.map(_buildResultTile),
          const SizedBox(height: 12),
        ],
        _sectionHeader('Clean', Colors.green, clean.length),
        ...clean.map(_buildResultTile),
      ],
    );
  }

  Widget _buildSummaryCard(int threats, int suspicious, int clean) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryChip(Icons.dangerous, '$threats', 'Threats', Colors.red),
            _summaryChip(
                Icons.warning, '$suspicious', 'Suspicious', Colors.orange),
            _summaryChip(
                Icons.check_circle, '$clean', 'Clean', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String count, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(count,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _sectionHeader(String title, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          const SizedBox(width: 8),
          Text('($count)', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildResultTile(ScanResultItem item) {
    final color = item.verdict == 'THREAT'
        ? Colors.red
        : item.verdict == 'SUSPICIOUS'
            ? Colors.orange
            : Colors.green;

    return Card(
      child: ExpansionTile(
        leading: Icon(
          item.verdict == 'CLEAN' ? Icons.check_circle : Icons.warning,
          color: color,
        ),
        title: Text(
          item.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(item.verdict, style: TextStyle(color: color)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Path', item.filePath),
                _detailRow('SHA-256', item.sha256),
                _detailRow('Size', item.fileSize),
                _detailRow('Heuristic Score',
                    item.heuristicScore.toStringAsFixed(2)),
                if (item.signatureMatch != null)
                  _detailRow('Signature', item.signatureMatch!),
                if (item.indicators.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Indicators:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...item.indicators.map((ind) => Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right, size: 16),
                            Expanded(
                              child: Text(
                                  '${ind.rule}: ${ind.description} (${ind.score.toStringAsFixed(1)})'),
                            ),
                          ],
                        ),
                      )),
                ],
                if (item.verdict == 'THREAT') ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _quarantine(item),
                    icon: const Icon(Icons.shield),
                    label: const Text('Quarantine'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: 'monospace'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Future<void> _quarantine(ScanResultItem item) async {
    final bridge = context.read<RustBridge>();
    try {
      await bridge.quarantineFile(item.filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quarantined: ${item.fileName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
