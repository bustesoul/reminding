import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "Subscriptions.db";
  static const _databaseVersion = 3; // <<-- Incremented version

  static const table = 'subscriptions';

  // Column names
  static const columnId = 'id';
  static const columnUuid = 'uuid';
  static const columnName = 'name';
  static const columnCreatedAt = 'createdAt'; // Store as ISO8601 String
  static const columnStartDate = 'startDate'; // Store as ISO8601 String (NOT NULL in v3)
  // static const columnRenewalDate = 'renewalDate'; // Removed in v3
  static const columnBillingCycle = 'billingCycle'; // Store as String
  static const columnRenewalAnchorDay = 'renewalAnchorDay'; // Added in v3 (INTEGER Nullable)
  static const columnRenewalAnchorMonth = 'renewalAnchorMonth'; // Added in v3 (INTEGER Nullable)
  static const columnReminderDays = 'reminderDays'; // Store as INTEGER
  static const columnCategory = 'category'; // Store as TEXT
  static const columnRating = 'rating'; // Store as INTEGER
  static const columnPrice = 'price'; // Store as REAL
  static const columnCustomFields = 'customFields'; // Store as TEXT

  // Make this a singleton class.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only have a single app-wide reference to the database.
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    // Lazily instantiate the db the first time it is accessed
    _database = await _initDatabase();
    return _database!;
  }

  // Open the database and create it if it doesn't exist.
  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Add migration logic
    );
  }

  // SQL code to create the database table.
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnUuid TEXT NOT NULL UNIQUE,
            $columnName TEXT NOT NULL,
            $columnCreatedAt TEXT NOT NULL,
            $columnStartDate TEXT NOT NULL, // Changed to NOT NULL in v3
            $columnBillingCycle TEXT NOT NULL,
            $columnRenewalAnchorDay INTEGER, // Added anchor day in v3
            $columnRenewalAnchorMonth INTEGER, // Added anchor month in v3
            $columnReminderDays INTEGER,
            $columnCategory TEXT,
            $columnRating INTEGER,
            $columnPrice REAL,
            $columnCustomFields TEXT
          )
          ''');
    // Add indexes if needed for performance
    // await db.execute('CREATE INDEX idx_renewalDate ON $table ($columnRenewalDate)'); // Removed index in v3
    await db.execute('CREATE INDEX idx_category ON $table ($columnCategory)');
    await db.execute('CREATE INDEX idx_rating ON $table ($columnRating)');
    await db.execute('CREATE INDEX idx_price ON $table ($columnPrice)');
    await db.execute('CREATE INDEX idx_startDate ON $table ($columnStartDate)');
    // Optional: Add indices for new anchor columns if queries often filter/sort by them
    // await db.execute('CREATE INDEX idx_anchorDay ON $table ($columnRenewalAnchorDay)');
    // await db.execute('CREATE INDEX idx_anchorMonth ON $table ($columnRenewalAnchorMonth)');
  }

  // --- Migration Logic ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print("Attempting database upgrade from version $oldVersion to $newVersion...");
    if (oldVersion < 2) {
      // Migration from version 1 to 2: Add startDate column
      print(" Applying upgrade from v1 to v2...");
      await db.execute('ALTER TABLE $table ADD COLUMN $columnStartDate TEXT');
      // Populate existing rows with a default startDate (using createdAt as fallback)
      await db.execute('UPDATE $table SET $columnStartDate = $columnCreatedAt WHERE $columnStartDate IS NULL');
      print("  Added $columnStartDate column and populated null values.");
    }
    if (oldVersion < 3) {
      // Migration from version 2 to 3:
      // - Make startDate NOT NULL (already handled if migrating from v1)
      // - Add renewalAnchorDay, renewalAnchorMonth
      // - Remove renewalDate
      // - Populate anchor columns based on old startDate (preferred) or renewalDate
      print(" Applying upgrade from v2 to v3...");
      await db.transaction((txn) async {
        // Step 1: Ensure startDate is NOT NULL (should be populated by v1->v2 migration if applicable)
        // We'll rely on the previous step or assume data is clean for v2.

        // Step 2: Create a temporary table with the new schema (v3)
        final tempTable = '${table}_temp_v3';
        await txn.execute('''
          CREATE TABLE $tempTable (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnUuid TEXT NOT NULL UNIQUE,
            $columnName TEXT NOT NULL,
            $columnCreatedAt TEXT NOT NULL,
            $columnStartDate TEXT NOT NULL, -- Now NOT NULL
            $columnBillingCycle TEXT NOT NULL,
            $columnRenewalAnchorDay INTEGER, -- New column
            $columnRenewalAnchorMonth INTEGER, -- New column
            $columnReminderDays INTEGER,
            $columnCategory TEXT,
            $columnRating INTEGER,
            $columnPrice REAL,
            $columnCustomFields TEXT
          )
        ''');
        print("  Step 2/5: Created temporary table $tempTable.");

        // Step 3: Copy data from the old table to the temporary table, transforming as needed
        // Extract day/month from startDate (preferred anchor source) for anchors.
        // SQLite date functions are limited. Parsing ISO strings ('YYYY-MM-DDTHH:MM:SS.sssZ')
        // Day: substr(date_string, 9, 2)
        // Month: substr(date_string, 6, 2)
        await txn.execute('''
          INSERT INTO $tempTable (
            $columnId, $columnUuid, $columnName, $columnCreatedAt, $columnStartDate,
            $columnBillingCycle, $columnRenewalAnchorDay, $columnRenewalAnchorMonth,
            $columnReminderDays, $columnCategory, $columnRating, $columnPrice, $columnCustomFields
          )
          SELECT
            $columnId, $columnUuid, $columnName, $columnCreatedAt, $columnStartDate,
            $columnBillingCycle,
            -- Extract anchor day from startDate (cast to INTEGER)
            CAST(substr($columnStartDate, 9, 2) AS INTEGER),
            -- Extract anchor month from startDate (cast to INTEGER) for yearly+ cycles
            CASE
              WHEN $columnBillingCycle = 'yearly' OR
                   $columnBillingCycle = 'everyTwoYears' OR -- Include new cycles
                   $columnBillingCycle = 'everyThreeYears' -- Include new cycles
              THEN CAST(substr($columnStartDate, 6, 2) AS INTEGER)
              ELSE NULL -- Month is not needed for monthly, quarterly, semiAnnually, oneTime
            END,
            $columnReminderDays, $columnCategory, $columnRating, $columnPrice, $columnCustomFields
          FROM $table
        ''');
        print("  Step 3/5: Copied and transformed data to $tempTable.");

        // Step 4: Drop the old table (which still has renewalDate)
        await txn.execute('DROP TABLE $table');
        print("  Step 4/5: Dropped old table $table.");

        // Step 5: Rename the temporary table to the original name
        await txn.execute('ALTER TABLE $tempTable RENAME TO $table');
        print("  Step 5/5: Renamed $tempTable to $table.");

        // Recreate indices on the new table (excluding the old renewalDate index)
        await txn.execute('CREATE INDEX idx_category ON $table ($columnCategory)');
        await txn.execute('CREATE INDEX idx_rating ON $table ($columnRating)');
        await txn.execute('CREATE INDEX idx_price ON $table ($columnPrice)');
        await txn.execute('CREATE INDEX idx_startDate ON $table ($columnStartDate)');
        // Optional: Add indices for new anchor columns
        // await txn.execute('CREATE INDEX idx_anchorDay ON $table ($columnRenewalAnchorDay)');
        // await txn.execute('CREATE INDEX idx_anchorMonth ON $table ($columnRenewalAnchorMonth)');
        print("  Recreated indices on new table $table.");

      });
      print(" Database upgrade from v2 to v3 completed successfully.");
    }
    // Add more migration steps for future versions here
    // if (oldVersion < 4) { ... }
    print("Database upgrade process finished for target version $newVersion.");
  }


  // --- Helper Methods for CRUD Operations (can be moved to Repository) ---
  // These are examples; the repository will likely contain the main logic.

  // Future<int> insert(Map<String, dynamic> row) async {
  //   Database db = await instance.database;
  //   return await db.insert(table, row);
  // }

  // Future<List<Map<String, dynamic>>> queryAllRows() async {
  //   Database db = await instance.database;
  //   return await db.query(table);
  // }

  // Future<int> update(Map<String, dynamic> row) async {
  //   Database db = await instance.database;
  //   int id = row[columnId];
  //   return await db.update(table, row, where: '$columnId = ?', whereArgs: [id]);
  // }

  // Future<int> delete(int id) async {
  //   Database db = await instance.database;
  //   return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  // }
}
