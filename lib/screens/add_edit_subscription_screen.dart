import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminding/models/subscription.dart';

class AddEditSubscriptionScreen extends ConsumerStatefulWidget {
  final Subscription? subscription; // Pass existing subscription for editing

  const AddEditSubscriptionScreen({super.key, this.subscription});

  @override
  ConsumerState<AddEditSubscriptionScreen> createState() => _AddEditSubscriptionScreenState();
}

class _AddEditSubscriptionScreenState extends ConsumerState<AddEditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  // TODO: Add TextEditingControllers for form fields
  // TODO: Initialize controllers if editing (widget.subscription != null)

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subscription != null;
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
              // TODO: Add TextFormField widgets for name, renewalDate, price, category, etc.
              // TODO: Add date picker for renewalDate
              // TODO: Add fields for custom JSON data if needed
              Text(isEditing ? 'Editing: ${widget.subscription!.name}' : 'Add New Subscription Form'),
            ],
          ),
        ),
      ),
    );
  }

  void _saveForm() {
    // TODO: Validate form
    // TODO: Create/Update Subscription object
    // TODO: Use repository to save the subscription
    // TODO: Pop screen
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Placeholder for save logic
      print('Form saved!');
      Navigator.of(context).pop();
    }
  }
}
