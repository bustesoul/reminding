import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminding/models/subscription.dart';
import 'package:reminding/repositories/subscription_repository.dart';
// import 'package:table_calendar/table_calendar.dart'; // isSameDay is used in home_screen

// Provider to get subscription occurrences for a specific day (returns FutureProvider of Tuples)
// Note: This will not automatically update. UI needs to refresh it.
final subscriptionsForDayProvider = FutureProvider.autoDispose.family<List<(Subscription, DateTime)>, DateTime>((ref, day) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  // Call the repository method which now returns tuples
  return repository.getSubscriptionsForDay(day);
});

// Provider to get subscription occurrences for the calendar event loader (returns FutureProvider of Tuples)
// We'll fetch events for a reasonable range around the focused month.
final subscriptionEventsProvider = FutureProvider.autoDispose.family<List<(Subscription, DateTime)>, DateTime>((ref, focusedMonth) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  // Fetch for a range (e.g., +/- 1 month) to cover calendar view changes
  final start = DateTime(focusedMonth.year, focusedMonth.month - 1, 1);
  final end = DateTime(focusedMonth.year, focusedMonth.month + 2, 0, 23, 59, 59, 999); // End of next month
  return repository.getSubscriptionsInDateRange(start, end);
});
