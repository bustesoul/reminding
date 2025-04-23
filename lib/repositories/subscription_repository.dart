import 'package:isar/isar.dart';
import 'package:reminding/models/subscription.dart';
import 'package:reminding/main.dart'; // To access isarProvider
import 'package:flutter_riverpod/flutter_riverpod.dart'; // To read isarProvider

// Simple repository class to handle Isar operations for Subscriptions
class SubscriptionRepository {
  final Isar _isar;

  SubscriptionRepository(this._isar);

  // Watch all subscriptions (returns a stream)
  Stream<List<Subscription>> watchAllSubscriptions() {
    // Using watchLazy to be notified of any changes in the collection
    return _isar.subscriptions.watchLazy().asyncMap(
          (_) => _isar.subscriptions.where().sortByRenewalDate().findAll(),
        );
  }

  // Watch subscriptions for a specific day (returns a stream)
  Stream<List<Subscription>> watchSubscriptionsForDay(DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

    // Watch the query for changes
    return _isar.subscriptions
        .filter()
        .renewalDateBetween(startOfDay, endOfDay)
        .watch(fireImmediately: true); // fireImmediately to get initial data
  }

  // Get subscriptions within a date range (useful for calendar events)
  // Returns a Future, but could be adapted to a Stream if needed
  Future<List<Subscription>> getSubscriptionsInDateRange(DateTime start, DateTime end) {
     return _isar.subscriptions
        .filter()
        .renewalDateBetween(start, end)
        .findAll();
  }

  // Add or update a subscription
  Future<void> saveSubscription(Subscription subscription) async {
    await _isar.writeTxn(() async {
      await _isar.subscriptions.put(subscription);
    });
  }

  // Delete a subscription by its Isar ID
  Future<bool> deleteSubscription(Id id) async {
    return await _isar.writeTxn(() async {
      return await _isar.subscriptions.delete(id);
    });
  }

  // Get a single subscription by its Isar ID (useful for editing)
  Future<Subscription?> getSubscriptionById(Id id) async {
    return await _isar.subscriptions.get(id);
  }
}

// Provider for the SubscriptionRepository
// Reads the Isar instance from isarProvider defined in main.dart
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return SubscriptionRepository(isar);
});
