import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'subscription.g.dart'; // Isar will generate this file

// Enum to represent the billing cycle
enum BillingCycle { oneTime, monthly, yearly }

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
  late DateTime renewalDate; // Represents the *next* renewal date

  @enumerated // Store enum by index for efficiency
  late BillingCycle billingCycle; // Billing frequency

  int? billingDayOfMonth; // Day of the month for monthly/yearly cycles (1-31)
  int? billingMonthOfYear; // Month of the year for yearly cycles (1-12)

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
    this.billingCycle = BillingCycle.oneTime, // Default to oneTime
    this.billingDayOfMonth,
    this.billingMonthOfYear,
    Map<String, dynamic>? customData,
  }) {
    // Basic validation for billing cycle details
    if (billingCycle == BillingCycle.monthly && billingDayOfMonth == null) {
      throw ArgumentError('billingDayOfMonth is required for monthly billing cycle.');
    }
    if (billingCycle == BillingCycle.yearly && (billingDayOfMonth == null || billingMonthOfYear == null)) {
      throw ArgumentError('billingDayOfMonth and billingMonthOfYear are required for yearly billing cycle.');
    }
    // TODO: Add more robust validation (e.g., day range 1-31, month range 1-12)

    uuid = const Uuid().v4(); // Generate a unique ID
    createdAt = DateTime.now();
    // Note: The initial calculation of the *first* renewalDate based on the cycle
    // might happen here or when saving the object, depending on your logic.
    // For now, the required renewalDate parameter sets the initial next renewal.
    if (customData != null) {
      customFields = jsonEncode(customData); // Encode custom data to JSON string
    }
  }

  // --- Helper Methods ---

  // Helper to get custom data as a Map
  @ignore // Tell Isar to ignore this getter
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
    return 'Subscription(id: $id, uuid: $uuid, name: $name, createdAt: $createdAt, renewalDate: $renewalDate, billingCycle: $billingCycle, billingDayOfMonth: $billingDayOfMonth, billingMonthOfYear: $billingMonthOfYear, category: $category, price: $price, rating: $rating, reminderDays: $reminderDays, customFields: $customFields)';
  }

  // --- Helper method to calculate next renewal date (Example) ---
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
        // Add a month. Be careful with month rollovers (e.g., Jan 31 -> Feb 28/29)
        // Using dayOfMonth ensures we target the correct day.
        int targetDay = billingDayOfMonth!;
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
        int targetDay = billingDayOfMonth!;
        int targetMonth = billingMonthOfYear!;
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
