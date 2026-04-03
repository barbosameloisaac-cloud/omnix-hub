import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omnix_hub/services/rust_bridge.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RustBridge>(
      builder: (context, bridge, _) {
        final events = bridge.recentEvents;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Event Log'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => bridge.refreshEvents(),
              ),
              if (events.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: () => bridge.clearEvents(),
                  tooltip: 'Clear events',
                ),
            ],
          ),
          body: events.isEmpty
              ? _buildEmptyState(context)
              : _buildEventList(context, events),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withAlpha(100)),
          const SizedBox(height: 16),
          Text('No events recorded',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('Events from scans and monitoring will appear here',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildEventList(BuildContext context, List<EventItem> events) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _EventTile(event: event);
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventItem event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _kindColor(event.kind).withAlpha(30),
          child: Icon(_kindIcon(event.kind),
              color: _kindColor(event.kind), size: 20),
        ),
        title: Text(event.source,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.detail,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(event.kind,
                      style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                const Spacer(),
                if (event.riskScore > 0)
                  Text(
                    'Risk: ${event.riskScore.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: event.riskScore > 5.0
                          ? Colors.red
                          : event.riskScore > 3.0
                              ? Colors.orange
                              : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Text(
          _formatTime(event.timestamp),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Color _kindColor(String kind) {
    switch (kind) {
      case 'FILE_CREATED':
        return Colors.blue;
      case 'FILE_MODIFIED':
        return Colors.amber;
      case 'FILE_DELETED':
        return Colors.grey;
      case 'THREAT_DETECTED':
        return Colors.red;
      case 'QUARANTINE_ACTION':
        return Colors.purple;
      case 'SIGNATURE_UPDATE':
        return Colors.teal;
      case 'HEALTH_CHECK':
        return Colors.green;
      case 'SYSTEM_WARNING':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _kindIcon(String kind) {
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
      case 'SIGNATURE_UPDATE':
        return Icons.update;
      case 'HEALTH_CHECK':
        return Icons.monitor_heart;
      case 'SYSTEM_WARNING':
        return Icons.report_problem;
      default:
        return Icons.event;
    }
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      return timestamp;
    }
  }
}
