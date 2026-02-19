import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../models/subscription.dart';
import 'package:intl/intl.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final TextEditingController _urlController = TextEditingController();

  void _addSubscription() {
    if (_urlController.text.isEmpty) return;
    context.read<SubscriptionService>().addSubscription(_urlController.text);
    _urlController.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final subService = context.watch<SubscriptionService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Subscriptions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (subService.isChecking)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => subService.checkNewContent(),
              tooltip: 'Check for updates',
            ),
        ],
      ),
      body: Column(
        children: [
          if (subService.newDownloadsCount > 0)
            Container(
              width: double.infinity,
              color: colorScheme.primaryContainer,
              padding: const EdgeInsets.all(8),
              child: Text(
                'Found ${subService.newDownloadsCount} new videos!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: subService.subscriptions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: subService.subscriptions.length,
                    itemBuilder: (context, index) {
                      final sub = subService.subscriptions[index];
                      return _buildSubscriptionCard(context, sub, subService);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Channel/Playlist'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.subscriptions_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No subscriptions yet',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          const Text(
            'Add a channel URL to track new videos',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    Subscription sub,
    SubscriptionService service,
  ) {
    final dateFormat = DateFormat('MMM dd, HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          sub.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              sub.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Last checked: ${dateFormat.format(sub.lastChecked)}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => service.removeSubscription(sub.url),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Subscription'),
        content: TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'Channel or Playlist URL',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _addSubscription, child: const Text('Add')),
        ],
      ),
    );
  }
}
