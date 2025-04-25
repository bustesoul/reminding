import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // For date formatting and potential future use
import 'package:reminding/repositories/database_helper.dart'; // Import for column names

// Enum to represent the billing cycle
enum BillingCycle {
  oneTime,
  monthly,
  quarterly, // Every 3 months
  semiAnnually, // Every 6 months
  yearly,
  everyTwoYears,
  everyThreeYears,
  // Consider adding 'custom' later if needed, with separate fields for value/unit
}

// Helper function to get the number of days in a month
int _daysInMonth(int year, int month) {
  // Handles month rollover correctly for December -> January
  return DateTime.utc(year, month + 1, 0).day;
}

// Helper function to add months, handling year rollovers and day clamping
DateTime _addMonths(DateTime date, int months, int anchorDay) {
  // Calculate target year and month
  int year = date.year + (date.month + months - 1) ~/ 12;
  int month = (date.month + months - 1) % 12 + 1;

  // Determine the day, clamping to the last day of the target month if anchorDay is too large
  int daysInTargetMonth = _daysInMonth(year, month);
  int day = (anchorDay > daysInTargetMonth) ? daysInTargetMonth : anchorDay;

  // Return new date, preserving time components (use UTC)
  return DateTime.utc(year, month, day, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
}

// Helper function to add years, handling leap years for anchor day
DateTime _addYears(DateTime date, int years, int anchorMonth, int anchorDay) {
    int year = date.year + years;
    int month = anchorMonth;
    int day = anchorDay;

    // Handle leap year case for Feb 29th anchor
    if (month == 2 && day == 29) {
      if (!_isLeapYear(year)) {
        day = 28; // Adjust to Feb 28th in non-leap years
      }
    } else {
       // Clamp day for other months if needed (e.g., anchor day 31 for April)
       int daysInTargetMonth = _daysInMonth(year, month);
       if (day > daysInTargetMonth) {
         day = daysInTargetMonth;
       }
    }
    // Return new date, preserving time components (use UTC)
    return DateTime.utc(year, month, day, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
}

// Helper to check for leap year
bool _isLeapYear(int year) {
  return (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
}


class Subscription {
  // SQLite's auto-incrementing ID (nullable for new objects)
  int? id;

  // Basic Fields
  late String uuid; // Unique identifier for syncing or external reference
  late String name;
  late DateTime createdAt;
  // startDate is crucial: it's the anchor date for calculating renewals.
  // Make it non-nullable for rule-based renewals.
  late DateTime startDate; // Changed from nullable

  // Framework Fields
  late BillingCycle billingCycle; // Billing frequency

  // Renewal Rule Fields (replace renewalDate)
  int? renewalAnchorDay; // Day of the month (1-31) for monthly, quarterly, etc. Required for recurring cycles.
  int? renewalAnchorMonth; // Month of the year (1-12) for yearly cycles. Required for yearly+.

  int? reminderDays; // Days before renewal to remind
  String? category;
  int? rating; // e.g., 1-5 stars
  double? price;

  // Extension Field
  String? customFields; // Store custom data as a JSON string

  // --- Constructors ---

  // --- Constructors ---

  Subscription({
    this.id, // Allow setting ID when reading from DB
    required this.name,
    required this.startDate, // Make startDate required as it's the anchor
    required this.billingCycle,
    this.renewalAnchorDay, // Required for recurring cycles
    this.renewalAnchorMonth, // Required for yearly+ cycles
    String? uuid, // Allow setting UUID when reading from DB
    DateTime? createdAt, // Allow setting createdAt when reading from DB
    this.category,
    this.rating,
    this.price,
    this.reminderDays,
    Map<String, dynamic>? customData,
  })  : uuid = uuid ?? const Uuid().v4(), // Generate UUID if not provided
        createdAt = createdAt ?? DateTime.now() { // Set creation time if not provided
    // --- Validation ---
    if (billingCycle != BillingCycle.oneTime) {
      if (renewalAnchorDay == null || renewalAnchorDay! < 1 || renewalAnchorDay! > 31) {
        throw ArgumentError('renewalAnchorDay must be provided (1-31) for recurring billing cycles.');
      }
      if ((billingCycle == BillingCycle.yearly ||
           billingCycle == BillingCycle.everyTwoYears ||
           billingCycle == BillingCycle.everyThreeYears) &&
          (renewalAnchorMonth == null || renewalAnchorMonth! < 1 || renewalAnchorMonth! > 12)) {
        throw ArgumentError('renewalAnchorMonth must be provided (1-12) for yearly+ billing cycles.');
      }
      // Removed the specific day/month combination check here.
      // Basic range checks (day 1-31, month 1-12) are sufficient.
      // The date calculation logic (`_addYears`, `_addMonths`) handles clamping
      // and leap year adjustments correctly when generating occurrences.
    }
    // --- End Validation ---

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
      DatabaseHelper.columnStartDate: startDate.toIso8601String(), // Store non-nullable startDate as String
      // DatabaseHelper.columnRenewalDate: renewalDate.toIso8601String(), // Removed
      DatabaseHelper.columnBillingCycle: billingCycle.name, // Store enum name as String
      DatabaseHelper.columnRenewalAnchorDay: renewalAnchorDay, // Store rule
      DatabaseHelper.columnRenewalAnchorMonth: renewalAnchorMonth, // Store rule
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
    // Decode customFields JSON string back to a Map
    Map<String, dynamic>? customDataMap;
    final customFieldsString = map[DatabaseHelper.columnCustomFields] as String?;
    if (customFieldsString != null && customFieldsString.isNotEmpty) {
      try {
        customDataMap = jsonDecode(customFieldsString) as Map<String, dynamic>?;
      } catch (e) {
        print("Error decoding customFields from DB for map $map: $e");
        // Decide how to handle invalid JSON from DB: null, empty map, or throw?
        customDataMap = null;
      }
    }

    return Subscription(
      id: map[DatabaseHelper.columnId] as int?,
      uuid: map[DatabaseHelper.columnUuid] as String,
      name: map[DatabaseHelper.columnName] as String,
      createdAt: DateTime.parse(map[DatabaseHelper.columnCreatedAt] as String), // Parse from String
      startDate: DateTime.parse(map[DatabaseHelper.columnStartDate] as String), // Parse non-nullable startDate
      // renewalDate: DateTime.parse(map[DatabaseHelper.columnRenewalDate] as String), // Removed
      billingCycle: BillingCycle.values.byName(map[DatabaseHelper.columnBillingCycle] as String), // Parse enum from String
      renewalAnchorDay: map[DatabaseHelper.columnRenewalAnchorDay] as int?, // Parse rule
      renewalAnchorMonth: map[DatabaseHelper.columnRenewalAnchorMonth] as int?, // Parse rule
      reminderDays: map[DatabaseHelper.columnReminderDays] as int?,
      category: map[DatabaseHelper.columnCategory] as String?,
      rating: map[DatabaseHelper.columnRating] as int?,
      price: map[DatabaseHelper.columnPrice] as double?,
      customData: customDataMap, // Pass the decoded map here
    );
  }

  // --- toString for debugging ---
  // --- toString for debugging ---
  @override
  String toString() {
    return 'Subscription(id: $id, uuid: $uuid, name: $name, createdAt: $createdAt, startDate: $startDate, billingCycle: $billingCycle, renewalAnchorDay: $renewalAnchorDay, renewalAnchorMonth: $renewalAnchorMonth, category: $category, price: $price, rating: $rating, reminderDays: $reminderDays, customFields: $customFields)';
  }

  // --- New Renewal Calculation Logic ---

  /// Calculates the sequence of renewal dates for this subscription,
  /// starting from the `startDate`.
  ///
  /// - [maxDate]: Optional limit to stop generating dates.
  /// Returns an empty list for `BillingCycle.oneTime`.
  List<DateTime> getRenewalOccurrences({DateTime? maxDate}) {
    if (billingCycle == BillingCycle.oneTime) {
      return [];
    }
    // Validation: Ensure anchor day/month are set for recurring cycles
    if (renewalAnchorDay == null) {
        print("Error: renewalAnchorDay is null for recurring subscription $name (ID: $id)");
        return []; // Cannot calculate without anchor day
    }
    bool needsMonth = billingCycle == BillingCycle.yearly ||
                      billingCycle == BillingCycle.everyTwoYears ||
                      billingCycle == BillingCycle.everyThreeYears;
    if (needsMonth && renewalAnchorMonth == null) {
        print("Error: renewalAnchorMonth is null for yearly+ subscription $name (ID: $id)");
        return []; // Cannot calculate without anchor month
    }

    final occurrences = <DateTime>[];
    // Start calculation from the subscription's startDate (ensure it's UTC for consistency)
    // Use only the date part of startDate for the initial calculation base.
    DateTime calculationBase = DateTime.utc(startDate.year, startDate.month, startDate.day);

    // Determine the *first* actual renewal date on or after the calculationBase,
    // based on the anchor day/month.
    DateTime currentRenewal;

    int initialYear = calculationBase.year;
    int initialMonth = calculationBase.month;

    switch (billingCycle) {
      case BillingCycle.monthly:
      case BillingCycle.quarterly:
      case BillingCycle.semiAnnually:
        // Adjust initial date to the *first* occurrence on or after startDate
        // using the anchor day.
        int targetDay = renewalAnchorDay!;
        int daysInStartMonth = _daysInMonth(initialYear, initialMonth);
        if (targetDay > daysInStartMonth) targetDay = daysInStartMonth; // Clamp day

        DateTime firstPossible = DateTime.utc(initialYear, initialMonth, targetDay);
        if (firstPossible.isBefore(calculationBase)) {
          // If the anchor day in the start month is already passed, move to the next applicable month's anchor day
          currentRenewal = _addMonths(firstPossible, 1, renewalAnchorDay!);
        } else {
          currentRenewal = firstPossible;
        }
        break;
      case BillingCycle.yearly:
      case BillingCycle.everyTwoYears:
      case BillingCycle.everyThreeYears:
        // Adjust initial date to the *first* occurrence on or after startDate
        // using the anchor month and day.
        int targetMonth = renewalAnchorMonth!;
        int targetDay = renewalAnchorDay!;

        // Check if the anchor day is valid for the anchor month in the initial year
        int daysInTargetMonthInitial = _daysInMonth(initialYear, targetMonth);
         if (targetDay > daysInTargetMonthInitial) {
             // This case should ideally be caught by constructor validation,
             // but if data is somehow invalid, we might clamp or log error.
             // Let's clamp for robustness in calculation.
             print("Warning: Anchor day $targetDay invalid for anchor month $targetMonth in year $initialYear for sub $name. Clamping to $daysInTargetMonthInitial.");
             targetDay = daysInTargetMonthInitial;
         }
         // Handle leap year specifically for Feb 29 anchor
         if (targetMonth == 2 && renewalAnchorDay == 29 && !_isLeapYear(initialYear)) {
             targetDay = 28; // Adjust day for the first check if start year is not leap
         }


        DateTime firstPossible = DateTime.utc(initialYear, targetMonth, targetDay);

        if (firstPossible.isBefore(calculationBase)) {
          // If the anchor date in the start year is already passed, move to the next applicable year's anchor date
           int yearsToAdd = 1; // Start by checking next year
           currentRenewal = _addYears(firstPossible, yearsToAdd, renewalAnchorMonth!, renewalAnchorDay!);
        } else {
          currentRenewal = firstPossible;
        }
        break;
      case BillingCycle.oneTime:
        return []; // Handled above, but good for exhaustiveness
    }


    // Generate subsequent occurrences up to maxDate
    while (maxDate == null || !currentRenewal.isAfter(maxDate)) {
      occurrences.add(currentRenewal);

      // Calculate the *next* renewal date based on the current one
      switch (billingCycle) {
        case BillingCycle.monthly:
          currentRenewal = _addMonths(currentRenewal, 1, renewalAnchorDay!);
          break;
        case BillingCycle.quarterly:
          currentRenewal = _addMonths(currentRenewal, 3, renewalAnchorDay!);
          break;
        case BillingCycle.semiAnnually:
          currentRenewal = _addMonths(currentRenewal, 6, renewalAnchorDay!);
          break;
        case BillingCycle.yearly:
           currentRenewal = _addYears(currentRenewal, 1, renewalAnchorMonth!, renewalAnchorDay!);
          break;
        case BillingCycle.everyTwoYears:
           currentRenewal = _addYears(currentRenewal, 2, renewalAnchorMonth!, renewalAnchorDay!);
          break;
        case BillingCycle.everyThreeYears:
           currentRenewal = _addYears(currentRenewal, 3, renewalAnchorMonth!, renewalAnchorDay!);
          break;
        case BillingCycle.oneTime:
          // Should not be reached
          break; // Exit loop
      }
    }

    return occurrences;
  }


  /// Calculates the *next* single renewal date strictly after a given date.
  /// Returns null if the subscription is oneTime or no future renewal exists.
  DateTime? getNextRenewalDate({required DateTime afterDate}) {
     if (billingCycle == BillingCycle.oneTime) {
       return null;
     }
     // Ensure afterDate is UTC date part only for comparison
     final afterDateUtc = DateTime.utc(afterDate.year, afterDate.month, afterDate.day);

     // Use getRenewalOccurrences. We need to find the first date in the sequence
     // that is strictly after 'afterDateUtc'.
     // We can generate occurrences starting from startDate up to a reasonable future limit.

     DateTime futureLimit;
     // Calculate a limit far enough to likely contain the next date.
     // Add a buffer (e.g., 4 cycles) beyond the 'afterDate' to be safe.
     switch (billingCycle) {
         case BillingCycle.monthly:
             futureLimit = _addMonths(afterDateUtc, 4, renewalAnchorDay ?? 1); // Look ahead 4 months
             break;
         case BillingCycle.quarterly:
             futureLimit = _addMonths(afterDateUtc, 4 * 3, renewalAnchorDay ?? 1); // Look ahead 4 quarters
             break;
         case BillingCycle.semiAnnually:
             futureLimit = _addMonths(afterDateUtc, 4 * 6, renewalAnchorDay ?? 1); // Look ahead 4 half-years
             break;
         case BillingCycle.yearly:
             futureLimit = _addYears(afterDateUtc, 4, renewalAnchorMonth ?? 1, renewalAnchorDay ?? 1); // Look ahead 4 years
             break;
         case BillingCycle.everyTwoYears:
             futureLimit = _addYears(afterDateUtc, 4 * 2, renewalAnchorMonth ?? 1, renewalAnchorDay ?? 1); // Look ahead 4 cycles
             break;
         case BillingCycle.everyThreeYears:
             futureLimit = _addYears(afterDateUtc, 4 * 3, renewalAnchorMonth ?? 1, renewalAnchorDay ?? 1); // Look ahead 4 cycles
             break;
         case BillingCycle.oneTime: return null; // Should not happen
     }


     final occurrences = getRenewalOccurrences(maxDate: futureLimit);

     // Find the first occurrence strictly after afterDateUtc
     for (final occurrence in occurrences) {
       // Ensure comparison is date-only UTC
       final occurrenceUtc = DateTime.utc(occurrence.year, occurrence.month, occurrence.day);
       if (occurrenceUtc.isAfter(afterDateUtc)) {
         return occurrence; // Return the full DateTime object
       }
     }

     // If no occurrence found within the calculated limit, it might mean the subscription
     // effectively ended before 'afterDate' or there's an issue.
     print("Warning: Could not find next renewal date for $name (ID: $id) after ${DateFormat.yMd().format(afterDateUtc)} within limit ${DateFormat.yMd().format(futureLimit)}.");
     return null;
  }

}
