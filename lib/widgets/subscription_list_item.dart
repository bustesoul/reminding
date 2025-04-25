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
    // Use a Card for better visual separation in lists
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), // Add horizontal margin too
      child: ListTile(
        leading: CircleAvatar( // Keep the avatar
          // Optional: Add background color based on category or other property?
          // backgroundColor: Colors.deepPurple.shade100,
          child: Text(
            subscription.name.isNotEmpty ? subscription.name.substring(0, 1).toUpperCase() : '?',
            // style: TextStyle(color: Colors.deepPurple.shade800),
          ),
        ),
        title: Text(subscription.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          // Display price more prominently if available
          subscription.price != null
              ? '\$${subscription.price!.toStringAsFixed(2)} / ${_billingCycleShortString(subscription.billingCycle)}'
              : _billingCycleShortString(subscription.billingCycle), // Just show cycle if no price
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        // Display the specific occurrence date clearly
        trailing: Text(
          DateFormat.Md().format(occurrenceDate), // Short date format (e.g., 4/25)
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
        onTap: onTap,
        // TODO: Implement Slidable for actions
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
