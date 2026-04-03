import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omnix_hub/services/rust_bridge.dart';
import 'package:omnix_hub/services/update_service.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  late final UpdateService _updateService;

  @override
  void initState() {
    super.initState();
    _updateService = UpdateService(context.read<RustBridge>());
    _updateService.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signature Updates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _updateService.refreshAll(),
            tooltip: 'Check for updates',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _updateService,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCurrentVersionCard(context),
              const SizedBox(height: 16),
              _buildPendingUpdatesCard(context),
              const SizedBox(height: 16),
              _buildHistoryCard(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentVersionCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.verified,
                color: Theme.of(context).colorScheme.primary, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Signature Database',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      'Version: ${_updateService.currentVersion ?? "initial"}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                      'Signatures loaded: ${_updateService.signatureCount}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingUpdatesCard(BuildContext context) {
    final pending = _updateService.pendingUpdates;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Pending Updates',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (pending.isNotEmpty)
                  Badge(
                    label: Text('${pending.length}'),
                    child: const Icon(Icons.download),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_updateService.isChecking)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('No pending updates',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              ...pending.map((update) => ListTile(
                    leading: const Icon(Icons.new_releases,
                        color: Colors.amber),
                    title: Text('v${update.version}'),
                    subtitle: Text(
                        '${update.signaturesCount} signatures - ${update.description}'),
                    trailing: FilledButton(
                      onPressed: () => _applyUpdate(update),
                      child: const Text('Apply'),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
    final history = _updateService.history;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update History',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('No update history',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              ...history.map((record) => ListTile(
                    leading: Icon(
                      record.status == 'applied'
                          ? Icons.check_circle
                          : Icons.error,
                      color: record.status == 'applied'
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: Text('v${record.version}'),
                    subtitle: Text(
                        '${record.signaturesAdded} sigs - ${record.appliedAt}'),
                    trailing: Chip(
                      label: Text(record.status,
                          style: const TextStyle(fontSize: 11)),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _applyUpdate(UpdateManifestItem update) async {
    try {
      await _updateService.applyUpdate(update.version);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Applied update v${update.version}')),
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
