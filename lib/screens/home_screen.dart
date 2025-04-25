import 'dart:collection'; // For LinkedHashMap

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Make sure table_calendar is still imported if needed elsewhere, or remove if not
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // For date formatting

import 'package:reminding/models/subscription.dart';
import 'package:reminding/providers/subscription_providers.dart';
import 'package:reminding/widgets/subscription_list_item.dart';
import 'add_edit_subscription_screen.dart';

// Placeholder screens (Create these files later)
// import 'subscription_list_screen.dart';
// import 'settings_screen.dart';

// Helper function to get events for a specific day (No longer needed)
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
  // State for BottomNavigationBar
  int _selectedIndex = 0; // 0: Calendar, 1: List, 2: Settings

  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late int _currentYear; // For year dropdown

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _currentYear = _focusedDay.year;
  }

  // Using LinkedHashMap for TableCalendar's event loader
  // The value is now a list of tuples (Subscription, OccurrenceDate)
  final LinkedHashMap<DateTime, List<(Subscription, DateTime)>> _eventsMap = LinkedHashMap(
    equals: isSameDay,
    hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
  );

  @override
  Widget build(BuildContext context) {
    // Removed redundant watch for eventsAsyncValue here.
    // It's watched inside _buildCalendarView where it's needed.

    // Populate the events map when data (list of tuples) is available
    // NOTE: This population logic remains here as _eventsMap is used by TableCalendar's eventLoader,
    // and the provider needs to be watched somewhere to trigger the population.
    // Watching it here ensures the map is updated even if _buildCalendarView isn't called immediately.
    ref.watch(subscriptionEventsProvider(_focusedDay)).whenData((eventTuples) {
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
        title: Text(_getAppBarTitle()), // Dynamic title based on selected tab
        // Actions can be added later (e.g., search for list view)
      ),
      // Use IndexedStack to keep state of each view when switching tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          _buildCalendarView(), // Calendar view in a separate method
          _buildPlaceholderView('Subscription List'), // Placeholder for List
          _buildPlaceholderView('Settings'), // Placeholder for Settings
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Subscriptions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple, // Match theme accent
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0 ? _buildAddFab() : null, // Show FAB only on Calendar tab
    );
  }

  // --- Helper Methods for Building Views ---

  // Builds the main calendar view content
  Widget _buildCalendarView() {
     // Watch the events provider for the current focused month
    final eventsAsyncValue = ref.watch(subscriptionEventsProvider(_focusedDay));

    // Populate the events map when data (list of tuples) is available
    eventsAsyncValue.whenData((eventTuples) {
      _eventsMap.clear();
      for (final tuple in eventTuples) {
        final occurrenceDate = tuple.$2; // Access the occurrence date
        final day = DateTime.utc(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day);
        final existingEvents = _eventsMap[day] ?? [];
        existingEvents.add(tuple);
        _eventsMap[day] = existingEvents;
      }
      // Trigger rebuild if map population happens after initial build
      // This might be needed if the provider updates asynchronously
      if (mounted) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
           if (mounted) setState(() {});
         });
      }
    });

    return Column(
      children: [
        TableCalendar<(Subscription, DateTime)>(
          firstDay: DateTime.utc(2010, 10, 16),
          lastDay: DateTime.utc(2030, 3, 14),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          // eventLoader uses the map
          eventLoader: (day) => _eventsMap[day] ?? [],
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              if (!mounted) return;
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _currentYear = focusedDay.year; // Update year on focus change too
              });
              ref.invalidate(subscriptionsForDayProvider(_selectedDay!));
            }
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              if (!mounted) return;
              setState(() { _calendarFormat = format; });
            }
          },
          onPageChanged: (focusedDay) {
            if (!mounted) return;
            setState(() {
              _focusedDay = focusedDay;
              _currentYear = focusedDay.year; // Update year dropdown on page change
            });
            ref.invalidate(subscriptionEventsProvider(_focusedDay));
          },
          calendarStyle: CalendarStyle(
            // Improved styling
            todayDecoration: BoxDecoration(
              color: Colors.deepPurple.shade100, // Lighter purple for today
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.deepPurple.shade400, // Slightly stronger selected color
              shape: BoxShape.circle,
            ),
             markerDecoration: BoxDecoration( // Default marker style
               color: Colors.orange.shade600,
               shape: BoxShape.circle,
             ),
             markersMaxCount: 1, // Show only one dot even if multiple events
             // weekendTextStyle: TextStyle(color: Colors.redAccent), // Optional: Highlight weekends
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) => DateFormat.MMMM(locale).format(date), // Only show Month name
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isNotEmpty) {
                final today = DateTime.now();
                final todayUtc = DateTime.utc(today.year, today.month, today.day);
                final dayUtc = DateTime.utc(day.year, day.month, day.day);
                final bool isPastDay = dayUtc.isBefore(todayUtc);

                final baseDecoration = CalendarStyle().markerDecoration;

                return Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    decoration: baseDecoration is BoxDecoration
                        ? baseDecoration.copyWith(
                            color: isPastDay ? Colors.grey.shade400 : Colors.orange.shade600,
                          )
                        : null,
                    width: 7.0,
                    height: 7.0,
                    margin: const EdgeInsets.symmetric(horizontal: 0.3),
                  ),
                );
              }
              return null;
            },
            headerTitleBuilder: (context, day) {
              return _buildCalendarHeader(day);
            },
          ),
        ),
        const Divider(height: 1), // Separator
        Expanded(
          child: _buildSubscriptionListForSelectedDay(),
        ),
      ],
    );
  }

  // Builds the header with month title and year dropdown
  Widget _buildCalendarHeader(DateTime day) {
    // Generate list of years (e.g., +/- 5 years from current focused year)
    final currentYear = day.year;
    final startYear = currentYear - 5;
    final endYear = currentYear + 5;
    final years = List.generate(endYear - startYear + 1, (index) => startYear + index);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Month Name (make tappable)
        InkWell(
          onTap: () => _selectMonth(context, day), // Call month selection dialog
          child: Padding(
            // Add padding for better tap area
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text(
              DateFormat.MMMM().format(day), // Only Month
              style: Theme.of(context).textTheme.titleMedium, // Use theme style
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Year Dropdown (wrapped to hide icon)
        DropdownButtonHideUnderline( // Hide the default underline
          child: DropdownButton<int>(
            value: _currentYear,
            iconSize: 0.0, // Hide the default dropdown icon
            items: years.map((int year) {
              return DropdownMenuItem<int>(
              value: year,
              child: Text(year.toString()),
            );
          }).toList(),
          onChanged: (int? newYear) {
            if (newYear != null && newYear != _currentYear) {
              setState(() {
                _currentYear = newYear;
                // Calculate the new focused day keeping the month and day
                final currentMonth = _focusedDay.month;
                final currentDay = _focusedDay.day;
                // Handle potential day issues (e.g., Feb 29)
                final daysInNewMonth = DateTime(newYear, currentMonth + 1, 0).day;
                final newDay = (currentDay > daysInNewMonth) ? daysInNewMonth : currentDay;
                _focusedDay = DateTime.utc(newYear, currentMonth, newDay);
                // Also update selected day if one is chosen
                if (_selectedDay != null) {
                  _selectedDay = DateTime.utc(newYear, currentMonth, newDay);
                  // Refresh the list for the newly selected day in the new year
                  ref.invalidate(subscriptionsForDayProvider(_selectedDay!));
                }
                // Refresh events for the new focused day/month/year
                ref.invalidate(subscriptionEventsProvider(_focusedDay));
              }); // End setState
            }
          },
            // underline: Container(), // Removed by DropdownButtonHideUnderline
            style: Theme.of(context).textTheme.titleMedium, // Match month style
          ),
        ),
      ],
    );
  }


  // Builds a placeholder view for tabs that are not yet implemented
  Widget _buildPlaceholderView(String title) {
    return Center(
      child: Text(
        '$title Screen\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey),
      ),
    );
  }

  // Builds the FloatingActionButton for adding subscriptions
  Widget _buildAddFab() {
    return FloatingActionButton(
      onPressed: () async {
        final initialDate = _selectedDay;
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => AddEditSubscriptionScreen(
              initialDate: initialDate,
            ),
          ),
        );
        if (result == true && mounted) {
          _refreshData();
        }
      },
      tooltip: 'Add Subscription',
      child: const Icon(Icons.add),
    );
  }

  // --- End Helper Methods for Building Views ---


  // --- Event Handlers ---

  // Handles BottomNavigationBar tap
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- End Event Handlers ---


  // --- Utility Methods ---

  // Gets the AppBar title based on the selected tab
  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return 'Subscription Calendar';
      case 1: return 'All Subscriptions';
      case 2: return 'Settings';
      default: return 'Reminding';
    }
  }

  // Method to refresh data providers
  void _refreshData() {
     // Refresh events for the calendar view
     ref.invalidate(subscriptionEventsProvider(_focusedDay));
     // Refresh the list for the selected day (if a day is selected)
     if (_selectedDay != null) {
       ref.invalidate(subscriptionsForDayProvider(_selectedDay!));
     }
     // TODO: Add invalidation for the full subscription list provider when implemented
  }

  // --- Month Selection Dialog ---
  Future<void> _selectMonth(BuildContext context, DateTime currentFocusedDay) async {
    final selectedMonth = await showModalBottomSheet<int>(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300, // Adjust height as needed
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 months per row
              childAspectRatio: 2.5, // Adjust aspect ratio
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final monthDate = DateTime(currentFocusedDay.year, month);
              final isSelectedMonth = month == currentFocusedDay.month;
              return InkWell(
                onTap: () => Navigator.of(context).pop(month), // Return selected month number
                child: Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelectedMonth ? Theme.of(context).colorScheme.primaryContainer : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateFormat.MMM().format(monthDate), // Short month name (e.g., Jan)
                    style: TextStyle(
                      fontWeight: isSelectedMonth ? FontWeight.bold : FontWeight.normal,
                      color: isSelectedMonth ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (selectedMonth != null && selectedMonth != currentFocusedDay.month) {
      setState(() {
        // Calculate the new focused day keeping the year and day
        final currentYear = _focusedDay.year;
        final currentDay = _focusedDay.day;
        // Handle potential day issues (e.g., switching to Feb from Mar 31)
        final daysInNewMonth = DateTime(currentYear, selectedMonth + 1, 0).day;
        final newDay = (currentDay > daysInNewMonth) ? daysInNewMonth : currentDay;
        _focusedDay = DateTime.utc(currentYear, selectedMonth, newDay);
        // _currentYear remains the same unless logic changes
      });
      // Refresh events for the new focused day/month/year
      ref.invalidate(subscriptionEventsProvider(_focusedDay));
    }
  }
  // --- End Month Selection Dialog ---


  // Widget to build the small marker indicating events on a day
  // The 'events' parameter is now List<(Subscription, DateTime)>
  // NOTE: This custom marker is replaced by using markerBuilder with CalendarStyle's markerDecoration
  /*
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
  */


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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No subscriptions renewing on\n${DateFormat.yMMMEd().format(_selectedDay!)}', // More detailed date format
                 textAlign: TextAlign.center,
                 style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
              ),
            ),
          );
        }
        // Add some padding around the list
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListView.builder(
            itemCount: occurrences.length,
            itemBuilder: (context, index) {
              final tuple = occurrences[index];
              final subscription = tuple.$1; // Get the original subscription
              final occurrenceDate = tuple.$2; // Get the specific date for this list item

              // Determine if the occurrence is in the past BEFORE building the widget
              final today = DateTime.now();
              final todayUtc = DateTime.utc(today.year, today.month, today.day);
              final occurrenceDateUtc = DateTime.utc(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day);
              final bool isPastOccurrence = occurrenceDateUtc.isBefore(todayUtc);

              // Wrap item in a Card for better visual separation
              // The Card itself is returned, containing the SubscriptionListItem
              return SubscriptionListItem( // Return the item directly (it includes the Card)
                subscription: subscription,
                occurrenceDate: occurrenceDate,
                isPast: isPastOccurrence, // Pass the flag
                onTap: () async {
                  // Allow tapping even on past items to view details
                  final result = await Navigator.push<bool>(
                       context,
                       MaterialPageRoute(
                         builder: (context) => AddEditSubscriptionScreen(subscription: subscription),
                       ),
                     );
                     if (result == true && mounted) {
                       _refreshData();
                     }
                   },
                 );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error loading subscriptions: $error')),
    );
  }
}
// --- The duplicate code block below this line will be removed ---
