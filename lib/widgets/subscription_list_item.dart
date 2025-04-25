import 'package:flutter/material.dart';
import 'package:reminding/models/subscription.dart';
import 'package:intl/intl.dart';

class SubscriptionListItem extends StatelessWidget {
  final Subscription subscription;
  final DateTime occurrenceDate; // The specific date for this occurrence
  final VoidCallback? onTap; // Optional tap callback for navigation/editing
  final bool isPast; // Flag to indicate if the occurrence date is in the past

  const SubscriptionListItem({
    super.key,
    required this.subscription,
    required this.occurrenceDate,
    this.isPast = false, // Default to false
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color pastColor = Colors.grey.shade500; // Color for past items
    final Color futureColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black; // Default text color

    // Use a Card for better visual separation in lists
    return Card(
      elevation: isPast ? 0.5 : 1.5, // Reduce elevation for past items
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      color: isPast ? Colors.grey.shade100 : null, // Slightly grey background for past items
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPast ? Colors.grey.shade300 : Theme.of(context).colorScheme.primaryContainer, // Dim avatar background
          child: Text(
            subscription.name.isNotEmpty ? subscription.name.substring(0, 1).toUpperCase() : '?',
            style: TextStyle(color: isPast ? pastColor : Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(
          subscription.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isPast ? pastColor : null, // Dim title color
                decoration: isPast ? TextDecoration.lineThrough : null, // Add strikethrough
              ),
        ),
        subtitle: Text(
          subscription.price != null
              ? '\$${subscription.price!.toStringAsFixed(2)} / ${_billingCycleShortString(subscription.billingCycle)}'
              : _billingCycleShortString(subscription.billingCycle),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isPast ? pastColor : null, // Dim subtitle color
              ),
        ),
        trailing: Text(
          DateFormat.Md().format(occurrenceDate),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isPast ? pastColor : Colors.grey.shade600, // Dim trailing date color
              ),
        ),
        onTap: onTap,
        enabled: !isPast, // Disable tap interaction for past items if desired
      ),
    );
  }

  // Helper for short billing cycle string
  String _billingCycleShortString(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.oneTime: return 'one time';
      case BillingCycle.monthly: return 'mo';
      case BillingCycle.quarterly: return 'qtr';
      case BillingCycle.semiAnnually: return '6mo';
      case BillingCycle.yearly: return 'yr';
      case BillingCycle.everyTwoYears: return '2yr';
      case BillingCycle.everyThreeYears: return '3yr';
      default: return cycle.name;
    }
  }
}
