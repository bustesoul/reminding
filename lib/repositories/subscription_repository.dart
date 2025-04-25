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

        // Adjust initial check date based on start date
        while (currentRenewal.isBefore(effectiveStartDate)) {
           currentRenewal = _calculateNextBillDate(currentRenewal, sub.billingCycle);
        }

        // Generate renewals and check if they fall on the target day
        // Limit iterations to prevent infinite loops in edge cases (e.g., 100 years)
        int iterations = 0;
        final maxIterations = 12 * 100; // Max 100 years of iterations

        // Find the first renewal date >= effectiveStartDate
        while (currentRenewal.isBefore(effectiveStartDate) && iterations < maxIterations) {
          currentRenewal = _calculateNextBillDate(currentRenewal, sub.billingCycle);
          iterations++;
        }

        // Now check if this or future renewals match the target day
        iterations = 0; // Reset iteration count for the main loop
        while (currentRenewal.isBefore(day.add(const Duration(days: 1))) && iterations < maxIterations) {
           final currentRenewalDayUtc = DateTime.utc(currentRenewal.year, currentRenewal.month, currentRenewal.day);
           if (currentRenewalDayUtc.isAtSameMomentAs(dayUtc)) {
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
    final rangeEnd = DateTime.utc(end.year, end.month, end.day, 23, 59, 59); // Ensure end is inclusive

    for (final sub in allSubscriptions) {
      // Skip if subscription starts after the range ends
      if (sub.startDate != null && sub.startDate!.isAfter(rangeEnd)) {
        continue;
      }

      if (sub.billingCycle == BillingCycle.oneTime) {
        // Check if the single renewal date is within the range and after start date
        final effectiveStartDate = sub.startDate ?? sub.createdAt;
        if (sub.renewalDate.isAfter(start.subtract(const Duration(days: 1))) &&
            sub.renewalDate.isBefore(rangeEnd.add(const Duration(days: 1))) &&
            !sub.renewalDate.isBefore(effectiveStartDate)) {
          occurrences.add((sub, sub.renewalDate)); // Add tuple
        }
      } else {
        // Calculate recurring occurrences within the range
        DateTime currentRenewal = sub.renewalDate;
        DateTime effectiveStartDate = sub.startDate ?? sub.createdAt; // Use start date or creation date

        // Limit iterations to prevent infinite loops (e.g., 100 years)
        int iterations = 0;
        final maxIterations = 12 * 100;

        // Find the first renewal date >= effectiveStartDate
        while (currentRenewal.isBefore(effectiveStartDate) && iterations < maxIterations) {
          currentRenewal = _calculateNextBillDate(currentRenewal, sub.billingCycle);
          iterations++;
        }


        // Generate renewals and add those within the range [start, rangeEnd]
        iterations = 0; // Reset iteration count
        while (currentRenewal.isBefore(rangeEnd.add(const Duration(days: 1))) && iterations < maxIterations) {
          // Check if the current renewal is within the query range [start, rangeEnd]
          // and also on or after the effective start date
          if (!currentRenewal.isBefore(start) && !currentRenewal.isBefore(effectiveStartDate)) {
             // Add the original subscription and the specific occurrence date as a tuple
             occurrences.add((sub, currentRenewal));
          }
          // Stop if the next renewal would definitely be after the range end
          if (currentRenewal.isAfter(rangeEnd)) {
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

  // Helper function to calculate the next billing date based on cycle
  // NOTE: This is a simplified calculation. Consider edge cases like end-of-month.
  DateTime _calculateNextBillDate(DateTime currentBillDate, BillingCycle cycle) {
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
