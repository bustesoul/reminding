import 'package:flutter/material.dart';
import 'package:reminding/models/subscription.dart';
import 'package:intl/intl.dart';

class SubscriptionListItem extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback? onTap; // Optional tap callback for navigation/editing

  const SubscriptionListItem({
    super.key,
    required this.subscription,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar( // Simple leading icon/indicator
        child: Text(subscription.name.substring(0, 1).toUpperCase()), // First letter
      ),
      title: Text(subscription.name),
      subtitle: Text(
        'Renews: ${DateFormat.yMd().format(subscription.renewalDate)}'
        '${subscription.price != null ? ' - \$${subscription.price!.toStringAsFixed(2)}' : ''}' // Show price if available
      ),
      trailing: const Icon(Icons.chevron_right), // Indicate tappable
      onTap: onTap,
      // TODO: Add options for edit/delete on long press or swipe
    );
  }
}
