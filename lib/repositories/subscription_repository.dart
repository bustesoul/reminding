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

  // Get subscriptions for a specific day (returns a Future)
  Future<List<Subscription>> getSubscriptionsForDay(DateTime day) async {
    // SQLite doesn't have direct DateTime comparison, use ISO strings or timestamps
    final startOfDay = DateTime(day.year, day.month, day.day).toIso8601String();
    // For 'between', the end date should be the start of the *next* day
    final startOfNextDay = DateTime(day.year, day.month, day.day + 1).toIso8601String();

    final List<Map<String, dynamic>> maps = await _db.query(
      DatabaseHelper.table,
      where: '${DatabaseHelper.columnRenewalDate} >= ? AND ${DatabaseHelper.columnRenewalDate} < ?',
      whereArgs: [startOfDay, startOfNextDay],
      orderBy: '${DatabaseHelper.columnRenewalDate} ASC',
    );
    return List.generate(maps.length, (i) {
      return Subscription.fromMap(maps[i]);
    });
  }

  // Get subscriptions within a date range (useful for calendar events)
  Future<List<Subscription>> getSubscriptionsInDateRange(DateTime start, DateTime end) async {
     final startStr = start.toIso8601String();
     // Adjust end date to be inclusive for the whole day
     final endOfDayStr = DateTime(end.year, end.month, end.day, 23, 59, 59, 999).toIso8601String();

     final List<Map<String, dynamic>> maps = await _db.query(
       DatabaseHelper.table,
       where: '${DatabaseHelper.columnRenewalDate} BETWEEN ? AND ?',
       whereArgs: [startStr, endOfDayStr],
       orderBy: '${DatabaseHelper.columnRenewalDate} ASC',
     );
     return List.generate(maps.length, (i) {
       return Subscription.fromMap(maps[i]);
     });
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
