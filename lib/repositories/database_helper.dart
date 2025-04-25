import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "Subscriptions.db";
  static const _databaseVersion = 2; // <<-- Increment version

  static const table = 'subscriptions';

  // Column names
  static const columnId = 'id';
  static const columnUuid = 'uuid';
  static const columnName = 'name';
  static const columnCreatedAt = 'createdAt'; // Store as ISO8601 String
  static const columnStartDate = 'startDate'; // Store as ISO8601 String (Nullable)
  static const columnRenewalDate = 'renewalDate'; // Store as ISO8601 String
  static const columnBillingCycle = 'billingCycle'; // Store as String
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
            $columnStartDate TEXT, // Added startDate column (nullable)
            $columnRenewalDate TEXT NOT NULL,
            $columnBillingCycle TEXT NOT NULL,
            $columnReminderDays INTEGER,
            $columnCategory TEXT,
            $columnRating INTEGER,
            $columnPrice REAL,
            $columnCustomFields TEXT
          )
          ''');
    // Add indexes if needed for performance
    await db.execute('CREATE INDEX idx_renewalDate ON $table ($columnRenewalDate)');
    await db.execute('CREATE INDEX idx_category ON $table ($columnCategory)');
    await db.execute('CREATE INDEX idx_rating ON $table ($columnRating)');
    await db.execute('CREATE INDEX idx_price ON $table ($columnPrice)');
    await db.execute('CREATE INDEX idx_startDate ON $table ($columnStartDate)'); // Index for startDate
  }

  // --- Migration Logic ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from version 1 to 2: Add startDate column
      await db.execute('ALTER TABLE $table ADD COLUMN $columnStartDate TEXT');
      // You might want to populate existing rows with a default startDate
      // based on createdAt or renewalDate if necessary, but NULL is often fine.
      // Example: await db.execute('UPDATE $table SET $columnStartDate = $columnCreatedAt WHERE $columnStartDate IS NULL');
      print("Database upgraded from version $oldVersion to $newVersion: Added $columnStartDate column.");
    }
    // Add more migration steps for future versions here
    // if (oldVersion < 3) { ... }
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
