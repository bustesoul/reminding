import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'subscription.g.dart'; // Isar will generate this file

@collection
class Subscription {
  // Isar's auto-incrementing ID
  Id id = Isar.autoIncrement;

  // Basic Fields
  @Index(unique: true, replace: true) // Ensure UUID is unique
  late String uuid; // Unique identifier for syncing or external reference

  late String name;
  late DateTime createdAt;

  // Framework Fields
  @Index() // Index for querying by renewal date
  late DateTime renewalDate;

  int? reminderDays; // Days before renewal to remind

  @Index() // Index for querying by category
  String? category;

  @Index() // Index for querying by rating
  int? rating; // e.g., 1-5 stars

  @Index() // Index for querying by price
  double? price;

  // Extension Field
  String? customFields; // Store custom data as a JSON string

  // --- Constructors ---

  Subscription({
    required this.name,
    required this.renewalDate,
    this.category,
    this.rating,
    this.price,
    this.reminderDays,
    Map<String, dynamic>? customData,
  }) {
    uuid = const Uuid().v4(); // Generate a unique ID
    createdAt = DateTime.now();
    if (customData != null) {
      customFields = jsonEncode(customData); // Encode custom data to JSON string
    }
  }

  // --- Helper Methods ---

  // Helper to get custom data as a Map
  Map<String, dynamic>? get customDataMap {
    if (customFields == null || customFields!.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(customFields!);
    } catch (e) {
      // Handle potential JSON decoding errors
      print("Error decoding customFields for subscription $name: $e");
      return null;
    }
  }

  // Helper to set custom data from a Map
  set customDataMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      customFields = null;
    } else {
      customFields = jsonEncode(data);
    }
  }

  // --- toString for debugging ---
  @override
  String toString() {
    return 'Subscription(id: $id, uuid: $uuid, name: $name, createdAt: $createdAt, renewalDate: $renewalDate, category: $category, price: $price, rating: $rating, reminderDays: $reminderDays, customFields: $customFields)';
  }
}
