import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminding/models/subscription.dart';
import 'package:reminding/repositories/subscription_repository.dart';
import 'package:table_calendar/table_calendar.dart'; // For isSameDay

// Provider to watch subscriptions for a specific day
final subscriptionsForDayProvider = StreamProvider.autoDispose.family<List<Subscription>, DateTime>((ref, day) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  return repository.watchSubscriptionsForDay(day);
});

// Provider to get subscription renewal dates for the calendar event loader
// We use FutureProvider here as TableCalendar's eventLoader expects a sync list.
// We'll fetch events for a reasonable range around the focused month.
final subscriptionEventsProvider = FutureProvider.autoDispose.family<List<Subscription>, DateTime>((ref, focusedMonth) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  // Fetch for a range (e.g., +/- 1 month) to cover calendar view changes
  final start = DateTime(focusedMonth.year, focusedMonth.month - 1, 1);
  final end = DateTime(focusedMonth.year, focusedMonth.month + 2, 0, 23, 59, 59, 999); // End of next month
  return repository.getSubscriptionsInDateRange(start, end);
});
