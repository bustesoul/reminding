import 'dart:convert'; // For JSON handling if needed for custom fields
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting
// import 'package:reminding/models/subscription.dart'; // Duplicate removed
import 'package:reminding/models/subscription.dart'; // Ensure model is imported
import 'package:reminding/repositories/subscription_repository.dart'; // Import repository
// No longer need dart:convert explicitly here unless used elsewhere

class AddEditSubscriptionScreen extends ConsumerStatefulWidget { // Added class declaration
  final Subscription? subscription; // Added field declaration inside class

  const AddEditSubscriptionScreen({super.key, this.subscription});

  @override
  ConsumerState<AddEditSubscriptionScreen> createState() => _AddEditSubscriptionScreenState();
}

class _AddEditSubscriptionScreenState extends ConsumerState<AddEditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;
  late TextEditingController _customFieldsController; // For raw JSON editing initially
  DateTime? _selectedStartDate; // Added state for start date
  DateTime? _selectedRenewalDate;
  int? _selectedRating; // For rating stars
  int? _reminderDays; // For reminder days input

  // State for billing cycle
  BillingCycle _selectedBillingCycle = BillingCycle.oneTime; // Default
  // _selectedBillingDayOfMonth and _selectedBillingMonthOfYear removed

  bool get isEditing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    final sub = widget.subscription;
    _nameController = TextEditingController(text: sub?.name ?? '');
    _priceController = TextEditingController(text: sub?.price?.toString() ?? '');
    _categoryController = TextEditingController(text: sub?.category ?? '');
    _selectedStartDate = sub?.startDate; // Initialize start date (can be null)
    _selectedRenewalDate = sub?.renewalDate ?? DateTime.now();
    _selectedRating = sub?.rating;
    _reminderDays = sub?.reminderDays;
    // Initialize billing cycle field
    _selectedBillingCycle = sub?.billingCycle ?? BillingCycle.oneTime;
    // _selectedBillingDayOfMonth and _selectedBillingMonthOfYear initialization removed
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
        setState(() {
          _selectedBillingCycle = newValue!;
          // Resetting dependent fields is no longer needed
        });
      },
    );
  }

  // Widget _buildBillingDetailsSelectors() removed as it's no longer needed

  // Helper to get display string for BillingCycle enum
  String _billingCycleToString(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.oneTime:
        return 'One Time';
      case BillingCycle.monthly:
        return 'Monthly';
      case BillingCycle.yearly:
        return 'Yearly';
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
              _buildBillingCycleSelector(), // Keep Billing Cycle Selector
              const SizedBox(height: 16),
              // _buildBillingDetailsSelectors() removed from here
              _buildStartDatePicker(), // Add Start Date Picker
              const SizedBox(height: 16),
              _buildRenewalDatePicker(), // Renamed Renewal Date Picker
              const SizedBox(height: 16),
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

  // Widget to build the START date picker row
  Widget _buildStartDatePicker() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _selectedStartDate == null
                ? 'Start Date (Optional): Not Set'
                : 'Starts: ${DateFormat.yMd().format(_selectedStartDate!)}',
          ),
        ),
        TextButton(
          onPressed: () => _presentDatePicker(isStartDate: true),
          child: Text(_selectedStartDate == null ? 'Set Start Date' : 'Change Start'),
        ),
        if (_selectedStartDate != null) // Add a clear button
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            tooltip: 'Clear Start Date',
            onPressed: () {
              setState(() {
                _selectedStartDate = null;
              });
            },
          ),
      ],
    );
  }


  // Widget to build the RENEWAL date picker row
  Widget _buildRenewalDatePicker() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _selectedRenewalDate == null
                ? 'Next Renewal Date: Not Set' // Should always have a value before saving
                : 'Next Renews: ${DateFormat.yMd().format(_selectedRenewalDate!)}',
          ),
        ),
        TextButton(
          onPressed: () => _presentDatePicker(isStartDate: false),
          child: const Text('Choose Renewal'),
        ),
      ],
    );
  }

  // Function to show the date picker dialog - MODIFIED to handle both dates
  void _presentDatePicker({required bool isStartDate}) async {
    final now = DateTime.now();
    final initialDate = isStartDate
        ? (_selectedStartDate ?? _selectedRenewalDate ?? now)
        : (_selectedRenewalDate ?? now);
    // Allow setting start date in the past, renewal date maybe not? Adjust as needed.
    final firstDate = DateTime(now.year - 10, now.month, now.day);
    final lastDate = DateTime(now.year + 20, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = pickedDate;
          // Optional: If start date is after renewal date, maybe adjust renewal date?
          // if (_selectedRenewalDate != null && pickedDate.isAfter(_selectedRenewalDate!)) {
          //   _selectedRenewalDate = pickedDate;
          // }
        } else {
          _selectedRenewalDate = pickedDate;
          // Optional: If renewal date is before start date, maybe adjust start date?
          // if (_selectedStartDate != null && pickedDate.isBefore(_selectedStartDate!)) {
          //   _selectedStartDate = pickedDate;
          // }
        }
      });
    }
  }


  void _saveForm() async {
    // Ensure renewal date is set
    if (_selectedRenewalDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the next renewal date.')),
       );
       return;
     }

    if (_formKey.currentState!.validate()) {
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
      // Pass existing id, uuid, createdAt if editing, otherwise they'll be generated/set by constructor/db
      final finalSubscription = Subscription(
        id: isEditing ? widget.subscription!.id : null,
        uuid: isEditing ? widget.subscription!.uuid : null,
        createdAt: isEditing ? widget.subscription!.createdAt : null,
        startDate: _selectedStartDate, // Pass the selected start date
        name: _nameController.text,
        renewalDate: _selectedRenewalDate!,
        billingCycle: _selectedBillingCycle,
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
