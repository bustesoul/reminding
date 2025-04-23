import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // For date formatting

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Calendar'),
        // TODO: Add button to navigate to subscription list/add screen
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2010, 10, 16), // Example start date
            lastDay: DateTime.utc(2030, 3, 14), // Example end date
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              // Use `selectedDayPredicate` to determine which day is currently selected.
              // If this returns true, then `day` will be marked as selected.
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                // Call `setState()` when updating the selected day
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay; // update `_focusedDay` here as well
                });
                // TODO: Load subscriptions for the selected day
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
              // No need to call `setState()` here
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.5),
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
            // TODO: Add event loader to mark days with renewals
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _buildSubscriptionList(),
          ),
        ],
      ),
      // TODO: Add FloatingActionButton to add new subscriptions
    );
  }

  Widget _buildSubscriptionList() {
    // TODO: Fetch and display subscriptions for _selectedDay using Riverpod
    if (_selectedDay == null) {
      return const Center(child: Text('Select a day'));
    }
    // Placeholder for subscription list
    return Center(
      child: Text(
        'Subscriptions for ${DateFormat.yMd().format(_selectedDay!)}',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
    // Replace with actual list view later
  }
}
