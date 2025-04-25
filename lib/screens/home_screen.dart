import 'dart:collection'; // For LinkedHashMap

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Make sure table_calendar is still imported if needed elsewhere, or remove if not
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // For date formatting

import 'package:reminding/models/subscription.dart';
import 'package:reminding/providers/subscription_providers.dart';
import 'package:reminding/widgets/subscription_list_item.dart';
import 'add_edit_subscription_screen.dart'; // Import the new screen

// Helper function to get events for a specific day from the list of all events (No longer needed with new map structure)
// List<Subscription> _getEventsForDay(DateTime day, List<Subscription>? allEvents) {
//   if (allEvents == null) return [];
//   return allEvents.where((event) => isSameDay(event.renewalDate, day)).toList();
// }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // Using LinkedHashMap is important for TableCalendar's event loader
  // The value is now a list of tuples (Subscription, OccurrenceDate)
  final LinkedHashMap<DateTime, List<(Subscription, DateTime)>> _eventsMap = LinkedHashMap(
    equals: isSameDay,
    hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
  );

  @override
  Widget build(BuildContext context) {
    // Watch the events provider for the current focused month
    final eventsAsyncValue = ref.watch(subscriptionEventsProvider(_focusedDay));

    // Populate the events map when data (list of tuples) is available
    eventsAsyncValue.whenData((eventTuples) {
      _eventsMap.clear();
      for (final tuple in eventTuples) {
        // final subscription = tuple.$1; // Access the subscription object
        final occurrenceDate = tuple.$2; // Access the occurrence date
        // Use the occurrenceDate for the map key
        final day = DateTime.utc(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day);
        final existingEvents = _eventsMap[day] ?? [];
        existingEvents.add(tuple); // Add the whole tuple to the list for that day
        _eventsMap[day] = existingEvents;
      }
    });


    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Calendar'),
        // TODO: Add button to navigate to a full subscription list/management screen
      ),
      body: Column(
        children: [
          TableCalendar<(Subscription, DateTime)>( // Changed generic type to tuple
            firstDay: DateTime.utc(2010, 10, 16), // Example start date
            lastDay: DateTime.utc(2030, 3, 14), // Example end date
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            // eventLoader uses the map; the value is List<(Subscription, DateTime)>
            // TableCalendar's markerBuilder just needs to know if the list is empty or not.
            eventLoader: (day) => _eventsMap[day] ?? [],
            selectedDayPredicate: (day) {
              // Use `selectedDayPredicate` to determine which day is currently selected.
              // If this returns true, then `day` will be marked as selected.
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                // Call `setState()` when updating the selected day
                // Check if the widget is still mounted before calling setState
                if (!mounted) return;
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay; // update `_focusedDay` here as well
                });
                // Refresh the provider for the newly selected day's list
                ref.invalidate(subscriptionsForDayProvider(_selectedDay!));
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                // Call `setState()` when updating calendar format
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              // Update focused day and potentially refresh events if needed
              // Check if the widget is still mounted before calling setState
              if (!mounted) return;
              setState(() {
                 _focusedDay = focusedDay;
              });
              // Refresh the events provider for the new visible month range
              ref.invalidate(subscriptionEventsProvider(_focusedDay));
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.deepPurple.withAlpha((0.5 * 255).round()),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false, // Hide format button for simplicity
              titleCentered: true,
              titleTextFormatter: (date, locale) => DateFormat.yMMMM(locale).format(date),
            ),
             calendarBuilders: CalendarBuilders( // Add builders for customization
              // markerBuilder receives the list returned by eventLoader for the day
              markerBuilder: (context, day, events) { // events is List<(Subscription, DateTime)>
                if (events.isNotEmpty) {
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: _buildEventsMarker(day, events),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _buildSubscriptionListForSelectedDay(), // Renamed method
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Pass the selected day to the AddEdit screen when adding
          final initialDate = _selectedDay; // Use the currently selected day

          // Navigate and wait for result to potentially refresh
          final result = await Navigator.push<bool>( // Expect a boolean indicating if save occurred
            context,
            MaterialPageRoute(
              builder: (context) => AddEditSubscriptionScreen(
                // Pass initialDate only when adding a new subscription
                initialDate: initialDate,
              ),
            ),
          );
          // If result is true (meaning save happened), refresh relevant data
          if (result == true && mounted) {
             _refreshData();
          }
        },
        tooltip: 'Add Subscription',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Method to refresh data providers
  void _refreshData() {
     // Refresh events for the calendar view
     ref.invalidate(subscriptionEventsProvider(_focusedDay));
     // Refresh the list for the selected day (if a day is selected)
     if (_selectedDay != null) {
       ref.invalidate(subscriptionsForDayProvider(_selectedDay!));
     }
  }


  // Widget to build the small marker indicating events on a day
  // The 'events' parameter is now List<(Subscription, DateTime)>
  Widget _buildEventsMarker(DateTime day, List<(Subscription, DateTime)> events) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.deepPurple[400],
      ),
      width: 16.0,
      height: 16.0,
      child: Center(
        child: Text(
          '${events.length}',
          style: const TextStyle().copyWith(
            color: Colors.white,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }


  // Build the list of subscriptions for the currently selected day
  Widget _buildSubscriptionListForSelectedDay() {
    if (_selectedDay == null) {
      return const Center(child: Text('Select a day'));
    }

    // Watch the provider for the selected day's subscription occurrences (tuples)
    final occurrencesAsyncValue = ref.watch(subscriptionsForDayProvider(_selectedDay!));

    return occurrencesAsyncValue.when(
      data: (occurrences) { // Now a list of tuples
        if (occurrences.isEmpty) {
          return Center(
            child: Text(
              'No subscriptions renewing on ${DateFormat.yMd().format(_selectedDay!)}',
            ),
          );
        }
        return ListView.builder(
          itemCount: occurrences.length,
          itemBuilder: (context, index) {
            final tuple = occurrences[index];
            final subscription = tuple.$1; // Get the original subscription
            final occurrenceDate = tuple.$2; // Get the specific date for this list item

            return SubscriptionListItem(
              subscription: subscription, // Pass the original subscription
              occurrenceDate: occurrenceDate, // Pass the specific occurrence date
              onTap: () async {
                // Navigate to edit screen, passing the ORIGINAL subscription
                // Navigate to edit and wait for result
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditSubscriptionScreen(subscription: subscription),
                  ),
                );
                // If result is true (save happened), refresh data
                if (result == true && mounted) {
                  _refreshData();
                }
              },
              // TODO: Add delete functionality (e.g., via Slidable or long-press menu)
              // Example using Dismissible:
              // key: Key(subscription.uuid), // Use a unique key
              // background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), child: Icon(Icons.delete, color: Colors.white)),
              // direction: DismissDirection.endToStart,
              // onDismissed: (direction) async {
              //   if (subscription.id == null) return; // Should not happen if displayed
              //   try {
              //     final repo = ref.read(subscriptionRepositoryProvider);
              //     await repo.deleteSubscription(subscription.id!);
              //     if (mounted) {
              //        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${subscription.name} deleted')));
              //        _refreshData(); // Refresh after delete
              //     }
              //   } catch (e) {
              //     if (mounted) {
              //        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
              //        // Optionally re-fetch data even on error to ensure consistency
              //        _refreshData();
              //     }
              //   }
              // },
              // child: SubscriptionListItem(...) // Your original item
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error loading subscriptions: $error')),
    );
  }
}
