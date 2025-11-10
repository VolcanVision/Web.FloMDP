import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'scm_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create tables in order (parent tables first)

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username VARCHAR(50) NOT NULL UNIQUE,
        email VARCHAR(100) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'production', 'accounts')),
        first_name VARCHAR(50),
        last_name VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_active BOOLEAN DEFAULT 1
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name VARCHAR(255) NOT NULL,
        contact_person VARCHAR(100),
        email VARCHAR(100),
        phone VARCHAR(20),
        address TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_active BOOLEAN DEFAULT 1
      )
    ''');

    // Inventory Items table
    await db.execute('''
      CREATE TABLE inventory_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(255) NOT NULL,
        type VARCHAR(20) NOT NULL CHECK (type IN ('fresh', 'recycled', 'finished', 'spare', 'raw', 'processed')),
        quantity INTEGER NOT NULL DEFAULT 0,
        category VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Orders table (combining Order and PaymentOrder models)
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number VARCHAR(50) UNIQUE NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        product_name VARCHAR(255) NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        total_cost DECIMAL(10,2) NOT NULL,
        advance_paid DECIMAL(10,2) DEFAULT 0.00,
        pending_amount DECIMAL(10,2) GENERATED ALWAYS AS (total_cost - advance_paid) STORED,
        is_advance_paid BOOLEAN DEFAULT 0,
        due_date DATE NOT NULL,
        after_dispatch_days INTEGER DEFAULT 0,
        final_due_date DATE,
        order_status VARCHAR(20) DEFAULT 'pending' CHECK (order_status IN ('pending', 'in_progress', 'completed', 'cancelled')),
        payment_status VARCHAR(20) DEFAULT 'unpaid' CHECK (payment_status IN ('paid', 'partial', 'unpaid', 'overdue')),
        created_by INTEGER REFERENCES users(id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Production Queue table
    await db.execute('''
      CREATE TABLE production_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_number VARCHAR(50) UNIQUE NOT NULL,
        inventory_id INTEGER NOT NULL REFERENCES inventory_items(id),
        order_id INTEGER REFERENCES orders(id),
        status VARCHAR(20) DEFAULT 'queued' CHECK (status IN ('queued', 'in_progress', 'completed', 'paused')),
        progress DECIMAL(5,2) DEFAULT 0.00 CHECK (progress >= 0 AND progress <= 100),
        assigned_to INTEGER REFERENCES users(id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Recipe Items table
    await db.execute('''
      CREATE TABLE recipe_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product VARCHAR(255) NOT NULL,
        cost_per_unit DECIMAL(10,2) NOT NULL,
        required_quantity DECIMAL(10,2) NOT NULL,
        total_cost DECIMAL(10,2) GENERATED ALWAYS AS (cost_per_unit * required_quantity) STORED,
        inventory_item_id INTEGER REFERENCES inventory_items(id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Calendar Tasks table
    await db.execute('''
      CREATE TABLE calendar_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        task_date DATE NOT NULL,
        category VARCHAR(20) NOT NULL CHECK (category IN ('newOrder', 'orderDueDate', 'paymentReceived', 'paymentDueDate', 'productionTodo', 'accountsTodo', 'adminTodo')),
        is_completed BOOLEAN DEFAULT 0,
        assigned_to INTEGER REFERENCES users(id),
        order_id INTEGER REFERENCES orders(id),
        created_by INTEGER REFERENCES users(id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Alerts table
    await db.execute('''
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        alert_type VARCHAR(20) DEFAULT 'info' CHECK (alert_type IN ('info', 'warning', 'error', 'success')),
        is_read BOOLEAN DEFAULT 0,
        target_user_id INTEGER REFERENCES users(id),
        related_order_id INTEGER REFERENCES orders(id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create indexes for performance
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    // User indexes
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await db.execute('CREATE INDEX idx_users_role ON users(role)');

    // Order indexes
    await db.execute('CREATE INDEX idx_orders_customer ON orders(customer_id)');
    await db.execute('CREATE INDEX idx_orders_status ON orders(order_status)');
    await db.execute(
      'CREATE INDEX idx_orders_payment_status ON orders(payment_status)',
    );
    await db.execute('CREATE INDEX idx_orders_due_date ON orders(due_date)');

    // Inventory indexes
    await db.execute(
      'CREATE INDEX idx_inventory_category ON inventory_items(category)',
    );
    await db.execute(
      'CREATE INDEX idx_inventory_type ON inventory_items(type)',
    );

    // Production queue indexes
    await db.execute(
      'CREATE INDEX idx_production_status ON production_queue(status)',
    );
    await db.execute(
      'CREATE INDEX idx_production_order ON production_queue(order_id)',
    );

    // Calendar task indexes
    await db.execute(
      'CREATE INDEX idx_tasks_date ON calendar_tasks(task_date)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_assigned ON calendar_tasks(assigned_to)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_category ON calendar_tasks(category)',
    );
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
