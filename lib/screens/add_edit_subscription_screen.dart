import 'dart:convert'; // For JSON handling if needed for custom fields
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting
// import 'package:reminding/models/subscription.dart'; // Duplicate removed
import 'package:reminding/models/subscription.dart'; // Ensure model is imported
import 'package:reminding/repositories/subscription_repository.dart'; // Import repository
// No longer need dart:convert explicitly here unless used elsewhere

class AddEditSubscriptionScreen extends ConsumerStatefulWidget {
  final Subscription? subscription; // Existing subscription if editing
  final DateTime? initialDate; // Optional initial date passed from HomeScreen

  const AddEditSubscriptionScreen({
    super.key,
    this.subscription,
    this.initialDate, // Add initialDate parameter
  });

  @override
  ConsumerState<AddEditSubscriptionScreen> createState() => _AddEditSubscriptionScreenState();
}

class _AddEditSubscriptionScreenState extends ConsumerState<AddEditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;
  late TextEditingController _customFieldsController; // For raw JSON editing initially
  late DateTime _selectedStartDate; // Changed to non-nullable, mandatory
  // DateTime? _selectedRenewalDate; // Removed
  int? _selectedRenewalAnchorDay; // Added for renewal rule
  int? _selectedRenewalAnchorMonth; // Added for renewal rule
  int? _selectedRating; // For rating stars
  int? _reminderDays; // For reminder days input

  // State for billing cycle
  BillingCycle _selectedBillingCycle = BillingCycle.oneTime; // Default
  // _selectedBillingDayOfMonth and _selectedBillingMonthOfYear removed

  bool get isEditing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    final sub = widget.subscription; // Existing subscription, if any
    final initialDate = widget.initialDate; // Date passed from HomeScreen, if any
    final now = DateTime.now();
    final defaultDate = DateTime.utc(now.year, now.month, now.day); // Fallback date

    _nameController = TextEditingController(text: sub?.name ?? '');
    _priceController = TextEditingController(text: sub?.price?.toString() ?? '');
    _categoryController = TextEditingController(text: sub?.category ?? '');

    // Determine the initial start date:
    // 1. Use existing subscription's start date if editing.
    // 2. Use initialDate passed from HomeScreen if adding and it's provided.
    // 3. Use today's date as fallback if adding without initialDate.
    _selectedStartDate = sub?.startDate ?? (initialDate != null ? DateTime.utc(initialDate.year, initialDate.month, initialDate.day) : defaultDate);

    _selectedRating = sub?.rating;
    _reminderDays = sub?.reminderDays;
    // Initialize billing cycle field
    _selectedBillingCycle = sub?.billingCycle ?? BillingCycle.monthly; // Default to monthly for new

    // Initialize anchor fields:
    // 1. Use existing subscription's anchors if editing.
    // 2. Use the determined _selectedStartDate's parts if adding.
    _selectedRenewalAnchorDay = sub?.renewalAnchorDay ?? _selectedStartDate.day;
    _selectedRenewalAnchorMonth = sub?.renewalAnchorMonth ?? _selectedStartDate.month;

    // Initialize custom fields controller - display existing JSON or empty
    _customFieldsController = TextEditingController(text: _getPrettyJson(sub?.customFields));

    // Consistency check removed as dependent fields are gone
  } // End of initState

  // --- Widgets for Billing Cycle ---

  Widget _buildBillingCycleSelector() {
    return DropdownButtonFormField<BillingCycle>(
      value: _selectedBillingCycle,
      decoration: const InputDecoration(labelText: 'Billing Cycle'),
      items: BillingCycle.values.map((cycle) {
        return DropdownMenuItem(
          value: cycle,
          child: Text(_billingCycleToString(cycle)), // Helper for display text
        );
      }).toList(),
      onChanged: (BillingCycle? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedBillingCycle = newValue;
            // Reset anchor month if switching to a cycle that doesn't need it
            bool needsMonth = _selectedBillingCycle == BillingCycle.yearly ||
                              _selectedBillingCycle == BillingCycle.everyTwoYears ||
                              _selectedBillingCycle == BillingCycle.everyThreeYears;
            if (!needsMonth) {
               _selectedRenewalAnchorMonth = null; // Reset month if not needed
            }
            // Ensure default day/month are set if switching TO a cycle that needs them
            // and they are currently null (might happen if switching from oneTime)
            if (_selectedBillingCycle != BillingCycle.oneTime && _selectedRenewalAnchorDay == null) {
                _selectedRenewalAnchorDay = _selectedStartDate.day;
            }
             if (needsMonth && _selectedRenewalAnchorMonth == null) {
                 _selectedRenewalAnchorMonth = _selectedStartDate.month;
             }
          });
        }
      },
      validator: (value) {
        if (value == null) {
          return 'Please select a billing cycle';
        }
        return null;
      },
    );
  }

  // Widget _buildBillingDetailsSelectors() removed as it's no longer needed

  // Helper to get display string for BillingCycle enum
  String _billingCycleToString(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.oneTime: return 'One Time';
      case BillingCycle.monthly: return 'Monthly';
      case BillingCycle.quarterly: return 'Quarterly';
      case BillingCycle.semiAnnually: return 'Semi-Annually';
      case BillingCycle.yearly: return 'Yearly';
      case BillingCycle.everyTwoYears: return 'Every 2 Years';
      case BillingCycle.everyThreeYears: return 'Every 3 Years';
      // default: return cycle.name; // Fallback if needed
    }
  }

  // --- End Widgets for Billing Cycle ---

  // Helper to format JSON nicely for editing
  String _getPrettyJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return '';
    try {
      final decoded = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  '); // Indent with 2 spaces
      return encoder.convert(decoded);
    } catch (e) {
      // If JSON is invalid, return the raw string
      return jsonString;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _customFieldsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Subscription' : 'Add Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // Use ListView for potentially long forms
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Subscription Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildBillingCycleSelector(),
              const SizedBox(height: 16),
              _buildRenewalRuleInputs(), // Add Renewal Rule Inputs
              const SizedBox(height: 16),
              _buildStartDatePicker(), // Keep Start Date Picker (now mandatory)
              const SizedBox(height: 16),
              // _buildRenewalDatePicker() removed
              TextFormField( // Keep Price
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (Optional)', prefixText: '\$'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), // Allow digits and decimal point (max 2 decimal places)
                ],
                // No validator needed as it's optional, but could add format validation
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category (Optional)'),
              ),
              const SizedBox(height: 16),
              // TODO: Add Rating Input (e.g., stars)
              // TODO: Add Reminder Days Input (e.g., number input)
              TextFormField(
                 controller: _customFieldsController,
                 decoration: const InputDecoration(
                   labelText: 'Custom Fields (JSON Format - Optional)',
                   hintText: '{\n  "key": "value",\n  "another_key": 123\n}',
                   alignLabelWithHint: true, // Better alignment for multi-line hint
                 ),
                 maxLines: 5, // Allow multiple lines for JSON editing
                 keyboardType: TextInputType.multiline,
                 validator: (value) {
                   if (value != null && value.isNotEmpty) {
                     try {
                       jsonDecode(value); // Try parsing to validate JSON
                     } catch (e) {
                       return 'Invalid JSON format';
                     }
                   }
                   return null; // No error if empty or valid JSON
                 },
               ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets for Renewal Rules ---

  Widget _buildRenewalRuleInputs() {
    // Don't show rule inputs for one-time subscriptions
    if (_selectedBillingCycle == BillingCycle.oneTime) {
      return const SizedBox.shrink(); // Return empty space
    }

    bool needsMonth = _selectedBillingCycle == BillingCycle.yearly ||
                      _selectedBillingCycle == BillingCycle.everyTwoYears ||
                      _selectedBillingCycle == BillingCycle.everyThreeYears;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Renewal Rule:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align dropdowns at the top
          children: [
            // Month Dropdown (Conditional)
            if (needsMonth)
              Expanded(
                flex: 2, // Give month dropdown more space
                child: DropdownButtonFormField<int>(
                  value: _selectedRenewalAnchorMonth,
                  decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text(DateFormat('MMMM').format(DateTime(0, month))), // Display full month name
                    );
                  }),
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedRenewalAnchorMonth = newValue;
                    });
                  },
                  validator: (value) {
                    if (needsMonth && value == null) {
                      return 'Select month';
                    }
                    // Add validation for day/month combo if needed (e.g., 31 for Feb)
                    // This is complex here, better done in _saveForm or model constructor
                    return null;
                  },
                ),
              ),
            if (needsMonth) const SizedBox(width: 8), // Spacer between dropdowns

            // Day Dropdown (Always shown for recurring)
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<int>(
                value: _selectedRenewalAnchorDay,
                decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
                items: List.generate(31, (index) {
                  final day = index + 1;
                  return DropdownMenuItem(
                    value: day,
                    child: Text(day.toString()),
                  );
                }),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedRenewalAnchorDay = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Select day';
                  }
                  // Basic day range validation
                  if (value < 1 || value > 31) {
                    return 'Invalid day';
                  }
                  // More complex validation (day valid for selected month) in _saveForm
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Determines the day (and month for yearly+) the subscription renews, based on the Start Date.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }


  // --- End Widgets for Renewal Rules ---


  // Widget to build the START date picker row (Now Mandatory)
  Widget _buildStartDatePicker() {
    return Row(
      children: [
        Expanded(
          child: Text(
            // _selectedStartDate == null // No longer possible
            //     ? 'Start Date (Optional): Not Set'
            'Starts: ${DateFormat.yMd().format(_selectedStartDate)}', // Now non-nullable
          ),
        ),
        TextButton(
          onPressed: () => _presentDatePicker(), // Simplified call
          child: const Text('Change Start Date'), // Updated text
        ),
        // Clear button removed as start date is mandatory
        // if (_selectedStartDate != null) ...
      ],
    );
  }


  // Widget _buildRenewalDatePicker() removed


  // Function to show the date picker dialog - SIMPLIFIED for Start Date only
  void _presentDatePicker() async {
    final now = DateTime.now();
    final initialDate = _selectedStartDate;
    // Allow setting start date in the past
    final firstDate = DateTime(now.year - 20, now.month, now.day); // Allow further back?
    final lastDate = DateTime(now.year + 20, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null && pickedDate != _selectedStartDate) {
      setState(() {
         // Ensure picked date is stored as UTC date part only
        _selectedStartDate = DateTime.utc(pickedDate.year, pickedDate.month, pickedDate.day);
        // Optional: Update default anchor day/month if user hasn't set them explicitly?
        // This might be confusing, so let's not do it automatically. User can change anchors if needed.
        // if (_selectedRenewalAnchorDay == null) _selectedRenewalAnchorDay = _selectedStartDate.day;
        // if (_selectedRenewalAnchorMonth == null) _selectedRenewalAnchorMonth = _selectedStartDate.month;
      });
    }
  }


  void _saveForm() async {
    // // Ensure renewal date is set // Removed
    // if (_selectedRenewalDate == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Please select the next renewal date.')),
    //    );
    //    return;
    //  }

    if (_formKey.currentState!.validate()) {
      // Additional validation for anchor day/month combination
      if (_selectedBillingCycle != BillingCycle.oneTime) {
        if (_selectedRenewalAnchorDay == null) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Please select a renewal day.')),
           );
           return;
        }
        bool needsMonth = _selectedBillingCycle == BillingCycle.yearly ||
                          _selectedBillingCycle == BillingCycle.everyTwoYears ||
                          _selectedBillingCycle == BillingCycle.everyThreeYears;
        if (needsMonth && _selectedRenewalAnchorMonth == null) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Please select a renewal month.')),
           );
           return;
        }
        // Validate day exists in month (ignoring leap year for simplicity here, model handles it)
        if (_selectedRenewalAnchorMonth != null) {
            // Use a non-leap year like 2023 for validation check
            final daysInMonth = DateTime.utc(2023, _selectedRenewalAnchorMonth! + 1, 0).day;
            if (_selectedRenewalAnchorDay! > daysInMonth) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Invalid day ($_selectedRenewalAnchorDay) for the selected month.')),
                 );
                 return;
            }
        }
      }


      _formKey.currentState!.save(); // Triggers onSaved for fields if needed

      final repository = ref.read(subscriptionRepositoryProvider);
      final double? price = double.tryParse(_priceController.text);
      final String? category = _categoryController.text.isNotEmpty ? _categoryController.text : null;
      final String? customFields = _customFieldsController.text.isNotEmpty ? _customFieldsController.text : null;

      // Validate JSON again before saving (optional, but good practice)
      if (customFields != null) {
        try {
          jsonDecode(customFields);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot save due to invalid JSON in Custom Fields.')),
          );
          return; // Prevent saving invalid JSON
        }
      }


      // --- Create or Update Subscription ---
      final finalSubscription = Subscription(
        id: isEditing ? widget.subscription!.id : null,
        uuid: isEditing ? widget.subscription!.uuid : null, // Keep existing UUID if editing
        createdAt: isEditing ? widget.subscription!.createdAt : null, // Keep existing createdAt
        name: _nameController.text,
        startDate: _selectedStartDate, // Pass the selected start date (now mandatory)
        billingCycle: _selectedBillingCycle,
        // Pass anchor day/month based on cycle type
        renewalAnchorDay: _selectedBillingCycle == BillingCycle.oneTime ? null : _selectedRenewalAnchorDay,
        renewalAnchorMonth: (_selectedBillingCycle == BillingCycle.yearly ||
                             _selectedBillingCycle == BillingCycle.everyTwoYears ||
                             _selectedBillingCycle == BillingCycle.everyThreeYears)
                            ? _selectedRenewalAnchorMonth
                            : null,
        price: price,
        category: category,
        rating: _selectedRating,
        reminderDays: _reminderDays,
        // customFields is set below
      );

      // Set custom fields directly (constructor handles encoding if needed, but we have the string)
      finalSubscription.customFields = customFields;


      try {
        await repository.saveSubscription(finalSubscription);
        if (mounted) { // Check if the widget is still in the tree
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Subscription ${isEditing ? 'updated' : 'added'}!')),
           );
          // Pop with a result to indicate success
          Navigator.of(context).pop(true); // Pass true back
        }
      } catch (e) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error saving subscription: $e')),
           );
         }
      }
    }
  }
}
