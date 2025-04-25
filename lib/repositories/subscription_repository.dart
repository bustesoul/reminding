import 'package:sqflite/sqflite.dart';
import 'package:reminding/models/subscription.dart';
import 'package:reminding/main.dart'; // To access databaseProvider
import 'package:flutter_riverpod/flutter_riverpod.dart'; // To read databaseProvider
import 'database_helper.dart'; // Import the DatabaseHelper

// Repository class to handle SQLite operations for Subscriptions
class SubscriptionRepository {
  final Database _db;

  SubscriptionRepository(this._db);

  // Get all subscriptions (returns a Future, not a Stream)
  Future<List<Subscription>> getAllSubscriptions() async {
    final List<Map<String, dynamic>> maps = await _db.query(
      DatabaseHelper.table,
      orderBy: '${DatabaseHelper.columnStartDate} ASC', // Order by startDate now
    );
    return List.generate(maps.length, (i) {
      return Subscription.fromMap(maps[i]); // fromMap handles new structure
    });
  }

  // Get subscription occurrences for a specific day (returns a Future of Tuples)
  Future<List<(Subscription, DateTime)>> getSubscriptionsForDay(DateTime day) async {
    // Fetch all potentially relevant subscriptions first
    // Optimization: Could filter further based on billing cycle and dates if needed
    final allSubsMaps = await _db.query(DatabaseHelper.table);
    final allSubscriptions = allSubsMaps.map((map) => Subscription.fromMap(map)).toList();

    final List<(Subscription, DateTime)> occurrences = [];
    final dayUtc = DateTime.utc(day.year, day.month, day.day);

    for (final sub in allSubscriptions) {
      if (sub.billingCycle == BillingCycle.oneTime) {
        // One-time subscriptions don't generate recurring events.
        // We might need a separate way to handle/display them if needed on a specific date,
        // but they don't fit the "renewal" model.
        // Perhaps check if sub.startDate matches dayUtc?
        // final startDateUtc = DateTime.utc(sub.startDate.year, sub.startDate.month, sub.startDate.day);
        // if (startDateUtc.isAtSameMomentAs(dayUtc)) {
        //    occurrences.add((sub, sub.startDate));
        // }
        continue; // Skip one-time subs for renewal checks
      }

      // Use the model's logic to get occurrences around the target day
      // Generate occurrences up to the day after the target day to be safe.
      final searchEndDate = dayUtc.add(const Duration(days: 1));
      final subOccurrences = sub.getRenewalOccurrences(maxDate: searchEndDate);

      // Check if any generated occurrence falls exactly on the target day
      for (final occDate in subOccurrences) {
        final occDateUtc = DateTime.utc(occDate.year, occDate.month, occDate.day);
        if (occDateUtc.isAtSameMomentAs(dayUtc)) {
          occurrences.add((sub, occDate));
          // Found the occurrence for this day, move to the next subscription
          break;
        }
        // Optimization: If we've passed the target day, stop checking for this sub
        if (occDateUtc.isAfter(dayUtc)) {
            break;
        }
      }
    }
    // Sort occurrences by the occurrence date (the DateTime part of the tuple)
    occurrences.sort((a, b) => a.$2.compareTo(b.$2));
    return occurrences; // Return list of (Subscription, OccurrenceDate) tuples
  }


  // Get subscription occurrences within a date range (returns a Future of Tuples)
  Future<List<(Subscription, DateTime)>> getSubscriptionsInDateRange(DateTime start, DateTime end) async {
    // Fetch all potentially relevant subscriptions
    // Optimization: Could filter by startDate <= end
    final allSubsMaps = await _db.query(DatabaseHelper.table);
    final allSubscriptions = allSubsMaps.map((map) => Subscription.fromMap(map)).toList();

    final List<(Subscription, DateTime)> occurrences = [];
    // Ensure range dates are UTC date part only for comparison
    final rangeStartUtc = DateTime.utc(start.year, start.month, start.day);
    final rangeEndUtc = DateTime.utc(end.year, end.month, end.day); // End of the day is handled by isBefore/isAfter logic

    for (final sub in allSubscriptions) {
       if (sub.billingCycle == BillingCycle.oneTime) {
         // Skip one-time subs for renewal checks in range
         continue;
       }

       // Use the model's logic to get occurrences up to the end of the range
       final subOccurrences = sub.getRenewalOccurrences(maxDate: rangeEndUtc);

       // Filter occurrences to include only those within the specified range [start, end]
       for (final occDate in subOccurrences) {
         final occDateUtc = DateTime.utc(occDate.year, occDate.month, occDate.day);
         // Check if the occurrence date is on or after the start date
         // AND on or before the end date.
         if (!occDateUtc.isBefore(rangeStartUtc) && !occDateUtc.isAfter(rangeEndUtc)) {
           occurrences.add((sub, occDate));
         }
       }
    }
    // Sort occurrences by the occurrence date (the DateTime part of the tuple)
    occurrences.sort((a, b) => a.$2.compareTo(b.$2));
    return occurrences; // Return list of (Subscription, OccurrenceDate) tuples
  }

  // Helper function _calculateNextOccurrenceDate removed - logic moved to Subscription model


  // Add or update a subscription
  Future<int> saveSubscription(Subscription subscription) async {
    // Use insert with conflictAlgorithm.replace to handle both add and update based on primary key
    // Or check if id exists and call insert or update explicitly
    if (subscription.id == null) {
      // Insert new subscription
      // Ensure UUID is unique before inserting if not handled by DB constraint (it is in helper)
      // The toMap() method now excludes null IDs automatically.
      return await _db.insert(
        DatabaseHelper.table,
        subscription.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail, // Fail if UUID constraint violated
      );
    } else {
      // Update existing subscription
      return await _db.update(
        DatabaseHelper.table,
        subscription.toMap(), // toMap() includes the ID for updates
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [subscription.id],
        // Using replace might be too aggressive if only updating certain fields,
        // but it ensures the UUID constraint isn't violated if the UUID were changed (which it shouldn't be).
        // Consider ConflictAlgorithm.none or .fail if you want more specific error handling.
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }


  // Delete a subscription by its SQLite ID
  Future<int> deleteSubscription(int id) async {
    return await _db.delete(
      DatabaseHelper.table,
      where: '${DatabaseHelper.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Get a single subscription by its SQLite ID
  Future<Subscription?> getSubscriptionById(int id) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      DatabaseHelper.table,
      where: '${DatabaseHelper.columnId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Subscription.fromMap(maps.first);
    }
    return null;
  }
}

// Provider for the SubscriptionRepository
// Reads the Database instance from databaseProvider defined in main.dart
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final db = ref.watch(databaseProvider); // Watch the new database provider
  return SubscriptionRepository(db);
});
