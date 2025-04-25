import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:reminding/repositories/database_helper.dart'; // Import for column names

// Removed Isar imports
// part 'subscription.g.dart'; // No longer needed

// Enum to represent the billing cycle
enum BillingCycle { oneTime, monthly, yearly }

// Removed Isar annotations
class Subscription {
  // SQLite's auto-incrementing ID (nullable for new objects)
  int? id;

  // Basic Fields
  // Removed Isar index annotations
  late String uuid; // Unique identifier for syncing or external reference
  late String name;
  late DateTime createdAt;

  // Framework Fields
  // Removed Isar index annotations
  late DateTime renewalDate; // Represents the *next* renewal date

  // Removed Isar enumerated annotation
  late BillingCycle billingCycle; // Billing frequency

  int? reminderDays; // Days before renewal to remind
  String? category;
  int? rating; // e.g., 1-5 stars
  double? price;

  // Extension Field
  String? customFields; // Store custom data as a JSON string

  // --- Constructors ---

  Subscription({
    this.id, // Allow setting ID when reading from DB
    required this.name,
    required this.renewalDate,
    required this.billingCycle,
    String? uuid, // Allow setting UUID when reading from DB
    DateTime? createdAt, // Allow setting createdAt when reading from DB
    this.category,
    this.rating,
    this.price,
    this.reminderDays,
    Map<String, dynamic>? customData,
  })  : uuid = uuid ?? const Uuid().v4(), // Generate UUID if not provided
        createdAt = createdAt ?? DateTime.now() { // Set creation time if not provided
    if (customData != null) {
      customFields = jsonEncode(customData); // Encode custom data to JSON string
    }
  }

  // --- Helper Methods ---

  // Helper to get custom data as a Map
  // Removed Isar ignore annotation
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

  // --- Conversion Methods for SQLite ---

  // Convert a Subscription object into a Map for SQLite
  Map<String, dynamic> toMap() {
    // Create a map, but exclude the ID if it's null (for inserts)
    final map = <String, dynamic>{
      // DatabaseHelper.columnId: id, // Excluded if null
      DatabaseHelper.columnUuid: uuid,
      DatabaseHelper.columnName: name,
      DatabaseHelper.columnCreatedAt: createdAt.toIso8601String(), // Store as String
      DatabaseHelper.columnRenewalDate: renewalDate.toIso8601String(), // Store as String
      DatabaseHelper.columnBillingCycle: billingCycle.name, // Store enum name as String
      DatabaseHelper.columnReminderDays: reminderDays,
      DatabaseHelper.columnCategory: category,
      DatabaseHelper.columnRating: rating,
      DatabaseHelper.columnPrice: price,
      DatabaseHelper.columnCustomFields: customFields,
    };
    // Only include the ID in the map if it's not null (for updates)
    if (id != null) {
      map[DatabaseHelper.columnId] = id;
    }
    return map;
  }


  // Create a Subscription object from a Map retrieved from SQLite
  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map[DatabaseHelper.columnId] as int?,
      uuid: map[DatabaseHelper.columnUuid] as String,
      name: map[DatabaseHelper.columnName] as String,
      createdAt: DateTime.parse(map[DatabaseHelper.columnCreatedAt] as String), // Parse from String
      renewalDate: DateTime.parse(map[DatabaseHelper.columnRenewalDate] as String), // Parse from String
      billingCycle: BillingCycle.values.byName(map[DatabaseHelper.columnBillingCycle] as String), // Parse enum from String
      reminderDays: map[DatabaseHelper.columnReminderDays] as int?,
      category: map[DatabaseHelper.columnCategory] as String?,
      rating: map[DatabaseHelper.columnRating] as int?,
      price: map[DatabaseHelper.columnPrice] as double?,
      customFields: map[DatabaseHelper.columnCustomFields] as String?,
    );
  }

  // --- toString for debugging ---
  @override
  String toString() {
    return 'Subscription(id: $id, uuid: $uuid, name: $name, createdAt: $createdAt, renewalDate: $renewalDate, billingCycle: $billingCycle, category: $category, price: $price, rating: $rating, reminderDays: $reminderDays, customFields: $customFields)';
  }

  // --- Helper method to calculate next renewal date (Example) ---
  // This logic remains the same, but ensure renewalDate is correctly handled
  // This logic might be better placed in a service or repository
  // depending on how you manage subscription updates.
  DateTime calculateNextRenewalDate() {
    if (billingCycle == BillingCycle.oneTime) {
      // For one-time, the renewal date doesn't change automatically.
      // Or perhaps it should throw an error if called? Depends on use case.
      return renewalDate;
    }

    DateTime nextDate = renewalDate;
    DateTime now = DateTime.now();

    // Ensure we calculate based on the *current* renewal date, moving forward
    // until we find a date in the future.
    while (nextDate.isBefore(now)) {
      if (billingCycle == BillingCycle.monthly) {
        // Add a month. Derive the target day from the current renewalDate.
        int targetDay = nextDate.day; // Use the day from the current renewal date
        int year = nextDate.year;
        int month = nextDate.month + 1;
        if (month > 12) {
          month = 1;
          year++;
        }
        // Check if the target day exists in the next month
        int daysInNextMonth = DateTime(year, month + 1, 0).day;
        if (targetDay > daysInNextMonth) {
          targetDay = daysInNextMonth; // Adjust to the last day if needed
        }
        nextDate = DateTime(year, month, targetDay, nextDate.hour, nextDate.minute, nextDate.second);

      } else if (billingCycle == BillingCycle.yearly) {
        // Derive target day and month from the current renewalDate
        int targetDay = nextDate.day;
        int targetMonth = nextDate.month;
        int year = nextDate.year + 1; // Simply add a year first

        // Check if the target day exists in the target month of the next year (for leap years)
        int daysInTargetMonth = DateTime(year, targetMonth + 1, 0).day;
        if (targetDay > daysInTargetMonth) {
          targetDay = daysInTargetMonth; // Adjust to the last day if needed
        }
        nextDate = DateTime(year, targetMonth, targetDay, nextDate.hour, nextDate.minute, nextDate.second);
      }
    }
    return nextDate;
  }
}
