import 'dart:convert'; // For JSON handling if needed for custom fields
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:reminding/models/subscription.dart';
import 'package:reminding/repositories/subscription_repository.dart'; // Import repository

class AddEditSubscriptionScreen extends ConsumerStatefulWidget {
  final Subscription? subscription; // Pass existing subscription for editing

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
  DateTime? _selectedRenewalDate;
  int? _selectedRating; // For rating stars
  int? _reminderDays; // For reminder days input

  // State for billing cycle
  BillingCycle _selectedBillingCycle = BillingCycle.oneTime; // Default
  int? _selectedBillingDayOfMonth;
  int? _selectedBillingMonthOfYear;


  bool get isEditing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    final sub = widget.subscription;
    _nameController = TextEditingController(text: sub?.name ?? '');
    _priceController = TextEditingController(text: sub?.price?.toString() ?? '');
    _categoryController = TextEditingController(text: sub?.category ?? '');
    _selectedRenewalDate = sub?.renewalDate ?? DateTime.now();
    _selectedRating = sub?.rating;
    _reminderDays = sub?.reminderDays;
    // Initialize billing cycle fields
    _selectedBillingCycle = sub?.billingCycle ?? BillingCycle.oneTime;
    _selectedBillingDayOfMonth = sub?.billingDayOfMonth;
    _selectedBillingMonthOfYear = sub?.billingMonthOfYear;
    // Initialize custom fields controller - display existing JSON or empty
    _customFieldsController = TextEditingController(text: _getPrettyJson(sub?.customFields));

    // Ensure initial state consistency for billing details
    if (_selectedBillingCycle == BillingCycle.oneTime) {
      _selectedBillingDayOfMonth = null;
      _selectedBillingMonthOfYear = null;
    } else if (_selectedBillingCycle == BillingCycle.monthly) {
      _selectedBillingMonthOfYear = null;
    }

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
           // Reset dependent fields when cycle changes
           if (_selectedBillingCycle == BillingCycle.oneTime) {
             _selectedBillingDayOfMonth = null;
             _selectedBillingMonthOfYear = null;
           } else if (_selectedBillingCycle == BillingCycle.monthly) {
             _selectedBillingMonthOfYear = null;
             // Optionally set a default day or leave null for user selection
             // _selectedBillingDayOfMonth = _selectedBillingDayOfMonth ?? 1;
           } else {
              // Optionally set defaults for yearly
              // _selectedBillingDayOfMonth = _selectedBillingDayOfMonth ?? 1;
              // _selectedBillingMonthOfYear = _selectedBillingMonthOfYear ?? 1;
           }
         });
       },
     );
   }

   Widget _buildBillingDetailsSelectors() {
     // Only show day/month selectors if needed
     if (_selectedBillingCycle == BillingCycle.oneTime) {
       return const SizedBox.shrink(); // Return empty space
     }

     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // --- Day of Month Selector (for Monthly and Yearly) ---
         if (_selectedBillingCycle == BillingCycle.monthly || _selectedBillingCycle == BillingCycle.yearly)
           DropdownButtonFormField<int>(
             value: _selectedBillingDayOfMonth,
             hint: const Text('Select Billing Day'),
             decoration: const InputDecoration(labelText: 'Day of Month'),
             items: List.generate(31, (index) => index + 1).map((day) { // 1 to 31
               return DropdownMenuItem(
                 value: day,
                 child: Text(day.toString()),
               );
             }).toList(),
             onChanged: (int? newValue) {
               setState(() {
                 _selectedBillingDayOfMonth = newValue;
               });
             },
             validator: (value) {
               if ((_selectedBillingCycle == BillingCycle.monthly || _selectedBillingCycle == BillingCycle.yearly) && value == null) {
                 return 'Please select a billing day';
               }
               // TODO: Add validation for days in month (e.g., Feb 30 is invalid) - complex, might need context of renewal date
               return null;
             },
           ),
         const SizedBox(height: 16), // Spacing

         // --- Month of Year Selector (for Yearly only) ---
         if (_selectedBillingCycle == BillingCycle.yearly)
           DropdownButtonFormField<int>(
             value: _selectedBillingMonthOfYear,
             hint: const Text('Select Billing Month'),
             decoration: const InputDecoration(labelText: 'Month of Year'),
             items: List.generate(12, (index) => index + 1).map((month) { // 1 to 12
               return DropdownMenuItem(
                 value: month,
                 child: Text(DateFormat('MMMM').format(DateTime(0, month))), // Display month name
               );
             }).toList(),
             onChanged: (int? newValue) {
               setState(() {
                 _selectedBillingMonthOfYear = newValue;
               });
             },
             validator: (value) {
               if (_selectedBillingCycle == BillingCycle.yearly && value == null) {
                 return 'Please select a billing month';
               }
               return null;
             },
           ),
          if (_selectedBillingCycle == BillingCycle.yearly) const SizedBox(height: 16), // Spacing if month is shown
       ],
     );
   }

   // Helper to get display string for BillingCycle enum
   String _billingCycleToString(BillingCycle cycle) {
     switch (cycle) {
       case BillingCycle.oneTime:
         return 'One Time';
       case BillingCycle.monthly:
         return 'Monthly';
       case BillingCycle.yearly:
         return 'Yearly';
       default:
         return '';
     }
   }

   // --- End Widgets for Billing Cycle ---


   void _saveForm() async {

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
              _buildBillingCycleSelector(), // Add Billing Cycle Selector
              const SizedBox(height: 16),
              _buildBillingDetailsSelectors(), // Add Day/Month Selectors (conditional)
              const SizedBox(height: 16),
              _buildDatePicker(), // Keep Renewal Date Picker
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

  // Widget to build the date picker row
  Widget _buildDatePicker() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _selectedRenewalDate == null
                ? 'No Renewal Date Set'
                : 'Renews: ${DateFormat.yMd().format(_selectedRenewalDate!)}',
          ),
        ),
        TextButton(
          onPressed: _presentDatePicker,
          child: const Text('Choose Date'),
        ),
      ],
    );
  }

  // Function to show the date picker dialog
  void _presentDatePicker() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5, now.month, now.day); // Allow past dates? Adjust as needed
    final lastDate = DateTime(now.year + 20, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedRenewalDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (pickedDate != null) {
      setState(() {
        _selectedRenewalDate = pickedDate;
      });
    }
  }


  void _saveForm() async {
    if (_selectedRenewalDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please select a renewal date.')),
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
      final subscriptionToSave = Subscription(
        name: _nameController.text,
        renewalDate: _selectedRenewalDate!, // Ensure this is validated above
        billingCycle: _selectedBillingCycle,
        billingDayOfMonth: _selectedBillingDayOfMonth,
        billingMonthOfYear: _selectedBillingMonthOfYear,
        price: price,
        category: category,
        rating: _selectedRating,
        reminderDays: _reminderDays,
        // Custom fields are handled separately below
      );

      // Set custom fields directly on the object
      subscriptionToSave.customFields = customFields;


      // If editing, preserve the original ID and UUID, createdAt
      if (isEditing) {
        subscriptionToSave.id = widget.subscription!.id;
        subscriptionToSave.uuid = widget.subscription!.uuid;
        subscriptionToSave.createdAt = widget.subscription!.createdAt;
      }

      try {
        await repository.saveSubscription(subscriptionToSave);
        if (mounted) { // Check if the widget is still in the tree
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Subscription ${isEditing ? 'updated' : 'added'}!')),
           );
          Navigator.of(context).pop(); // Go back after saving
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
