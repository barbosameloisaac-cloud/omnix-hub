import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omnix_hub/services/rust_bridge.dart';

class QuarantineScreen extends StatefulWidget {
  const QuarantineScreen({super.key});

  @override
  State<QuarantineScreen> createState() => _QuarantineScreenState();
}

class _QuarantineScreenState extends State<QuarantineScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<RustBridge>().refreshQuarantine());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RustBridge>(
      builder: (context, bridge, _) {
        final items = bridge.quarantinedItems;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Quarantine'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => bridge.refreshQuarantine(),
              ),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Chip(
                    label: Text('${items.length} item(s)'),
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                  ),
                ),
            ],
          ),
          body: items.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _buildQuarantineCard(context, bridge, items[index]),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user,
              size: 80,
              color: Colors.green.withAlpha(100)),
          const SizedBox(height: 16),
          Text('No quarantined files',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('Threat files will appear here when isolated',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildQuarantineCard(
      BuildContext context, RustBridge bridge, QuarantineItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.originalPath,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('ID', item.id),
            _infoRow('SHA-256', item.sha256),
            _infoRow('Reason', item.reason),
            _infoRow('Quarantined', item.quarantinedAt),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _confirmRestore(context, bridge, item),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Restore'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _confirmDelete(context, bridge, item),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Delete'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: TextStyle(
                    color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(
      BuildContext context, RustBridge bridge, QuarantineItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore File?'),
        content: Text(
            'This will restore the file to its original location:\n${item.originalPath}\n\nAre you sure this is a false positive?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await bridge.restoreFromQuarantine(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restored: ${item.originalPath}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, RustBridge bridge, QuarantineItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete?'),
        content: Text(
            'This will permanently delete the quarantined file.\nThis action cannot be undone.\n\nOriginal: ${item.originalPath}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await bridge.deleteQuarantined(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File permanently deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
