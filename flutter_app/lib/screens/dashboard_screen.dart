import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omnix_hub/services/rust_bridge.dart';
import 'package:omnix_hub/widgets/security_status_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RustBridge>(
      builder: (context, bridge, _) {
        final health = bridge.healthReport;
        final stats = bridge.scanStats;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => bridge.refreshHealth(),
                tooltip: 'Refresh health status',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => bridge.refreshHealth(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SecurityStatusCard(
                  status: health.overallStatus,
                  uptime: health.uptimeSecs,
                  warnings: health.warnings,
                ),
                const SizedBox(height: 16),
                _buildStatsRow(context, stats),
                const SizedBox(height: 16),
                _buildComponentsCard(context, health.components),
                const SizedBox(height: 16),
                _buildRecentActivityCard(context, bridge.recentEvents),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(BuildContext context, ScanStats stats) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.folder_open,
            label: 'Files Scanned',
            value: '${stats.totalScanned}',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.check_circle,
            label: 'Clean',
            value: '${stats.clean}',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.warning_amber,
            label: 'Suspicious',
            value: '${stats.suspicious}',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.dangerous,
            label: 'Threats',
            value: '${stats.threats}',
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildComponentsCard(
      BuildContext context, List<ComponentHealth> components) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Components',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...components.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _statusIcon(c.status),
                        color: _statusColor(c.status),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(c.name,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Text(c.detail,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(
      BuildContext context, List<EventItem> events) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Events',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('No events yet',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              ...events.take(10).map((e) => ListTile(
                    dense: true,
                    leading: Icon(_eventIcon(e.kind), size: 20),
                    title: Text(e.source,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(e.detail,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(e.timestamp,
                        style: Theme.of(context).textTheme.bodySmall),
                  )),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'HEALTHY':
        return Icons.check_circle;
      case 'DEGRADED':
        return Icons.warning;
      case 'UNHEALTHY':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'HEALTHY':
        return Colors.green;
      case 'DEGRADED':
        return Colors.orange;
      case 'UNHEALTHY':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _eventIcon(String kind) {
    switch (kind) {
      case 'FILE_CREATED':
        return Icons.note_add;
      case 'FILE_MODIFIED':
        return Icons.edit_note;
      case 'FILE_DELETED':
        return Icons.delete;
      case 'THREAT_DETECTED':
        return Icons.warning;
      case 'QUARANTINE_ACTION':
        return Icons.shield;
      default:
        return Icons.event;
    }
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
