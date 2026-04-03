import 'package:flutter/material.dart';

class SecurityStatusCard extends StatelessWidget {
  final String status;
  final int uptime;
  final List<String> warnings;

  const SecurityStatusCard({
    super.key,
    required this.status,
    required this.uptime,
    required this.warnings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _bgColor(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(_statusIcon(), color: _iconColor(), size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Status: $status',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Uptime: ${_formatUptime(uptime)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (warnings.isNotEmpty) ...[
              const Divider(height: 24),
              ...warnings.map((w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(w,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  IconData _statusIcon() {
    switch (status) {
      case 'HEALTHY':
        return Icons.verified_user;
      case 'DEGRADED':
        return Icons.warning;
      case 'UNHEALTHY':
        return Icons.gpp_bad;
      default:
        return Icons.help_outline;
    }
  }

  Color _iconColor() {
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

  Color? _bgColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'HEALTHY':
        return Colors.green.withAlpha(20);
      case 'DEGRADED':
        return Colors.orange.withAlpha(20);
      case 'UNHEALTHY':
        return Colors.red.withAlpha(20);
      default:
        return scheme.surfaceContainerHighest;
    }
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}
