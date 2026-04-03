import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omnix_hub/services/rust_bridge.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RustBridge>(
      builder: (context, bridge, _) {
        final config = bridge.config;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scanner Settings',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      _buildSliderSetting(
                        context,
                        label: 'Max File Size (MB)',
                        value: config.maxFileSizeMb.toDouble(),
                        min: 1,
                        max: 500,
                        divisions: 499,
                        onChanged: (v) =>
                            bridge.updateConfig(maxFileSizeMb: v.toInt()),
                      ),
                      const SizedBox(height: 16),
                      _buildSliderSetting(
                        context,
                        label:
                            'Heuristic Threshold (${config.heuristicThreshold.toStringAsFixed(2)})',
                        value: config.heuristicThreshold,
                        min: 0.1,
                        max: 2.0,
                        divisions: 19,
                        onChanged: (v) =>
                            bridge.updateConfig(heuristicThreshold: v),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Scan hidden files'),
                        subtitle: const Text('Include files starting with .'),
                        value: config.scanHiddenFiles,
                        onChanged: (v) =>
                            bridge.updateConfig(scanHiddenFiles: v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monitor Settings',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      _buildSliderSetting(
                        context,
                        label:
                            'Poll Interval (${config.monitorIntervalSecs}s)',
                        value: config.monitorIntervalSecs.toDouble(),
                        min: 5,
                        max: 300,
                        divisions: 59,
                        onChanged: (v) =>
                            bridge.updateConfig(monitorIntervalSecs: v.toInt()),
                      ),
                      const SizedBox(height: 16),
                      _buildSliderSetting(
                        context,
                        label:
                            'Event Dedup Window (${config.dedupWindowSecs}s)',
                        value: config.dedupWindowSecs.toDouble(),
                        min: 5,
                        max: 120,
                        divisions: 23,
                        onChanged: (v) =>
                            bridge.updateConfig(dedupWindowSecs: v.toInt()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paths',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _infoRow('Database', config.databasePath),
                      _infoRow('Quarantine', config.quarantineDir),
                      _infoRow('Logs', config.logDir),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('About',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _infoRow('Version', '0.1.0'),
                      _infoRow('Backend', 'Rust + SQLite'),
                      _infoRow('Purpose',
                          'Defensive file security scanner (educational)'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliderSetting(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
