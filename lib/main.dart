// ignore_for_file: depend_on_referenced_packages // Required for intl setup

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart'; // Import sqflite
import 'package:path/path.dart'; // Import path
import 'package:path_provider/path_provider.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import for date formatting initialization

// Removed Isar import
// import 'models/subscription.dart'; // Schema no longer needed here
import 'repositories/database_helper.dart'; // Import the new DatabaseHelper
import 'screens/home_screen.dart'; // Import the new home screen

// Provider to hold the Database instance
// We use late final because it will be initialized in main() before runApp()
late final Provider<Database> databaseProvider;

// We make main async to allow for initialization steps (like SQLite)
Future<void> main() async {
  // Ensure Flutter bindings are initialized (needed for async main and path_provider)
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for the default locale
  // Must be called before `runApp` or any date formatting.
  await initializeDateFormatting();

  // --- SQLite Initialization ---
  final dbHelper = DatabaseHelper.instance;
  final database = await dbHelper.database; // This initializes the database
  // --- End SQLite Initialization ---

  // Assign the initialized Database instance to the provider
  databaseProvider = Provider<Database>((ref) => database);

  // Wrap the entire app in a ProviderScope for Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget { // Changed to ConsumerWidget for Riverpod
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) { // Add WidgetRef ref here
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(), // Use the new HomeScreen
    );
  }
}
