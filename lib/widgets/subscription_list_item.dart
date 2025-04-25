import 'package:flutter/material.dart';
import 'package:reminding/models/subscription.dart';
import 'package:intl/intl.dart';

class SubscriptionListItem extends StatelessWidget {
  final Subscription subscription;
  final DateTime occurrenceDate; // Add the specific date for this occurrence
  final VoidCallback? onTap; // Optional tap callback for navigation/editing

  const SubscriptionListItem({
    super.key,
    required this.subscription,
    required this.occurrenceDate, // Make it required
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
        // Use the occurrenceDate for display
        'Date: ${DateFormat.yMd().format(occurrenceDate)}'
        '${subscription.price != null ? ' - \$${subscription.price!.toStringAsFixed(2)}' : ''}' // Show price if available
        // Optionally add cycle info: ' (${subscription.billingCycle.name})'
      ),
      trailing: const Icon(Icons.chevron_right), // Indicate tappable
      onTap: onTap,
      // TODO: Add options for edit/delete on long press or swipe
    );
  }
}
