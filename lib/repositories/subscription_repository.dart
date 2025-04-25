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
      orderBy: '${DatabaseHelper.columnRenewalDate} ASC',
    );
    return List.generate(maps.length, (i) {
      return Subscription.fromMap(maps[i]);
    });
  }

  // Get subscription occurrences for a specific day (returns a Future of Tuples)
  Future<List<(Subscription, DateTime)>> getSubscriptionsForDay(DateTime day) async {
    // Fetch all potentially relevant subscriptions first
    // Optimization: Could filter further based on billing cycle and dates if needed
    final allSubsMaps = await _db.query(DatabaseHelper.table);
    final allSubscriptions = allSubsMaps.map((map) => Subscription.fromMap(map)).toList();

    final List<(Subscription, DateTime)> occurrences = []; // Changed list type
    final dayUtc = DateTime.utc(day.year, day.month, day.day);

    for (final sub in allSubscriptions) {
      // Skip if subscription starts after the target day
      if (sub.startDate != null && sub.startDate!.isAfter(day)) {
        continue;
      }

      if (sub.billingCycle == BillingCycle.oneTime) {
        // Check if the single renewal date matches the target day
        final renewalDayUtc = DateTime.utc(sub.renewalDate.year, sub.renewalDate.month, sub.renewalDate.day);
        if (renewalDayUtc.isAtSameMomentAs(dayUtc)) {
          occurrences.add((sub, sub.renewalDate)); // Add tuple
        }
      } else {
        // Calculate recurring occurrences for the target day
        DateTime currentRenewal = sub.renewalDate;
        DateTime effectiveStartDate = sub.startDate ?? sub.createdAt; // Use start date or creation date

        // Determine the anchor date for recurrence calculation
        final anchorDate = effectiveStartDate;

        // Start generating occurrences from the anchor date
        DateTime currentOccurrence = anchorDate;

        // Generate renewals and check if they fall on the target day
        // Limit iterations to prevent infinite loops in edge cases (e.g., 100 years)
        int iterations = 0;
        final maxIterations = 12 * 100; // Max 100 years of iterations

        // Loop forwards from the anchor date
        while (iterations < maxIterations) {
           final currentOccurrenceUtc = DateTime.utc(currentOccurrence.year, currentOccurrence.month, currentOccurrence.day);

           // Stop if the current occurrence is already past the target day
           if (currentOccurrenceUtc.isAfter(dayUtc)) {
              break;
           }

           // Check if the current occurrence matches the target day
           if (currentOccurrenceUtc.isAtSameMomentAs(dayUtc)) {
             // Add the original subscription and the specific occurrence date as a tuple
             occurrences.add((sub, currentRenewal));
             break; // Found occurrence for this day, no need to check further for this sub
           }
           // If current renewal is after the target day, stop checking for this sub
           if (currentRenewal.isAfter(day)) {
              break;
           }
           currentRenewal = _calculateNextBillDate(currentRenewal, sub.billingCycle);
           iterations++;
        }
      }
    }
    // Sort occurrences by the occurrence date (the DateTime part of the tuple)
    occurrences.sort((a, b) => a.$2.compareTo(b.$2));
    return occurrences;
  }


  // Get subscription occurrences within a date range (returns a Future of Tuples)
  Future<List<(Subscription, DateTime)>> getSubscriptionsInDateRange(DateTime start, DateTime end) async {
    // Fetch all potentially relevant subscriptions
    // Optimization: Could filter by startDate <= end
    final allSubsMaps = await _db.query(DatabaseHelper.table);
    final allSubscriptions = allSubsMaps.map((map) => Subscription.fromMap(map)).toList();

    final List<(Subscription, DateTime)> occurrences = []; // Changed list type
    final rangeStartUtc = DateTime.utc(start.year, start.month, start.day); // Use UTC for comparison start
    final rangeEndUtc = DateTime.utc(end.year, end.month, end.day, 23, 59, 59); // Ensure end is inclusive

    for (final sub in allSubscriptions) {
      // Determine the effective start date (anchor for recurrence)
      final effectiveStartDate = sub.startDate ?? sub.createdAt;
      final anchorDate = effectiveStartDate; // Use effectiveStartDate to determine day/month

      // Skip if the subscription's anchor date is already after the range ends
      if (DateTime.utc(anchorDate.year, anchorDate.month, anchorDate.day).isAfter(rangeEndUtc)) {
        continue;
      }

      if (sub.billingCycle == BillingCycle.oneTime) {
        // For one-time, check if the *single* renewalDate falls within the range
        // AND is on or after the effective start date.
        final renewalDateUtc = DateTime.utc(sub.renewalDate.year, sub.renewalDate.month, sub.renewalDate.day);
        final effectiveStartDateUtc = DateTime.utc(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);

        if (!renewalDateUtc.isBefore(rangeStartUtc) &&
            !renewalDateUtc.isAfter(rangeEndUtc) &&
            !renewalDateUtc.isBefore(effectiveStartDateUtc)) {
          occurrences.add((sub, sub.renewalDate)); // Add tuple
        }
      } else {
        // --- Calculate recurring occurrences within the range ---
        DateTime currentOccurrence = anchorDate; // Start generating from the anchor date

        // Limit iterations to prevent infinite loops (e.g., 100 years)
        int iterations = 0;
        final maxIterations = 12 * 100;

        // Loop forwards from the anchor date
        while (iterations < maxIterations) {
          final currentOccurrenceUtc = DateTime.utc(currentOccurrence.year, currentOccurrence.month, currentOccurrence.day);

          // Stop if the current occurrence is already past the range end
          if (currentOccurrenceUtc.isAfter(rangeEndUtc)) {
            break;
          }

          // Check if the current occurrence is within the query range [rangeStartUtc, rangeEndUtc]
          // (It's already guaranteed to be >= anchorDate by starting there)
          if (!currentOccurrenceUtc.isBefore(rangeStartUtc)) {
             // Add the original subscription and the specific occurrence date as a tuple
             occurrences.add((sub, currentOccurrence));
          }

          // Calculate the next occurrence based on the *current* one and the anchor
          DateTime nextOccurrence = _calculateNextOccurrenceDate(currentOccurrence, sub.billingCycle, anchorDate);

          // Safety check: ensure next date is after current date to prevent infinite loop
          if (!nextOccurrence.isAfter(currentOccurrence)) {
              print("Warning: Next occurrence calculation did not advance for sub ${sub.id}. Anchor: $anchorDate, Current: $currentOccurrence. Breaking loop.");
              break; // Avoid potential infinite loop
          }

          currentOccurrence = nextOccurrence;
          iterations++;
        }
      }
    }
     // Sort occurrences by the occurrence date (the DateTime part of the tuple)
    occurrences.sort((a, b) => a.$2.compareTo(b.$2));
    return occurrences;
  }


  // Helper function to calculate the next occurrence date based on the previous one,
  // the billing cycle, and an anchor date (which defines the day/month).
  DateTime _calculateNextOccurrenceDate(DateTime previousOccurrenceDate, BillingCycle cycle, DateTime anchorDate) {
    int anchorDay = anchorDate.day;
    int anchorMonth = anchorDate.month; // Needed for yearly cycle

    if (cycle == BillingCycle.monthly) {
      int year = previousOccurrenceDate.year;
      int month = previousOccurrenceDate.month + 1;
      if (month > 12) {
        month = 1;
        year++;
      }
      // Use anchorDay, but adjust if it doesn't exist in the target month
      int daysInTargetMonth = DateTime(year, month + 1, 0).day;
      int day = (anchorDay > daysInTargetMonth) ? daysInTargetMonth : anchorDay;
      // Use time components from anchorDate for consistency
      return DateTime(year, month, day, anchorDate.hour, anchorDate.minute, anchorDate.second);

    } else if (cycle == BillingCycle.yearly) {
      int year = previousOccurrenceDate.year + 1;
      // Use anchorMonth and anchorDay
      int month = anchorMonth;
      int day = anchorDay;
      // Handle leap year case for Feb 29th anchor
      if (month == 2 && day == 29) {
        // Check if target year is a leap year (Feb has 29 days)
        if (DateTime(year, 3, 0).day != 29) {
          day = 28; // Not a leap year, adjust to Feb 28th
        }
      } else {
         // Check if anchorDay exists in anchorMonth for the target year (e.g., Feb 30/31 doesn't exist)
         int daysInTargetMonth = DateTime(year, month + 1, 0).day;
         if (day > daysInTargetMonth) {
             day = daysInTargetMonth; // Adjust to last day of month
         }
      }
      // Use time components from anchorDate
      return DateTime(year, month, day, anchorDate.hour, anchorDate.minute, anchorDate.second);
    } else {
      // OneTime: Should not be called for this cycle in the recurring logic.
      // Return the same date to potentially break loops if called incorrectly.
      return previousOccurrenceDate;
    }
  }

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
