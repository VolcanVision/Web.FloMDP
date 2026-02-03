import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'config/supabase_config.dart';
import 'screens/login_page.dart';
import 'screens/splash_screen.dart';
import 'services/orders_service.dart';
import 'services/fcm_service.dart';
import 'auth/auth_service.dart';

// Admin
import 'screens/admin/admin_dashboard.dart';
import 'screens/orders_page.dart';
import 'screens/calculator_page.dart';
import 'screens/calendar_page.dart';

// Production
import 'screens/production/production_dashboard.dart';
import 'screens/production/production_queue.dart';
import 'screens/inventory_page.dart';
import 'screens/returned_orders_page.dart';
import 'screens/reports_page.dart';
import 'screens/production/dispatch_page.dart';
import 'screens/production/production_loss_page.dart';

// Accounts
import 'screens/accounts/accounts_dashboard.dart';
import 'screens/accounts/purchase_page.dart';
import 'screens/accounts/orders_page.dart';
import 'screens/accounts/history_page.dart' as accounts_history;
import 'screens/accounts/calendar_page.dart';
import 'screens/accounts/dispatch_tracking_page.dart';

// Admin new pages
import 'screens/admin/history_page.dart';
import 'screens/admin/lab_test_page.dart';
import 'screens/admin/cost_calendar_page.dart';
import 'screens/admin/accounts_page.dart';

// Lab Testing
import 'screens/lab_testing/lab_testing_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );

    // Skip SQLite initialization on web platforms
    debugPrint('Supabase initialized successfully');

    // Initialize Firebase (skip on web for now)
    if (!kIsWeb) {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');

      // Initialize FCM service
      await FCMService().initialize();
      debugPrint('FCM service initialized successfully');
    }

    // Initialize default data
    await OrdersService.instance.initializeDefaultData();
  } catch (e) {
    debugPrint('Error initializing app: $e');
  }

  runApp(SCMApp());
}

class SCMApp extends StatelessWidget {
  const SCMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDPlastics',
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.blueGrey),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginPage(),

        // Admin routes
        '/admin/dashboard': (_) => AdminDashboard(),
        '/admin/new-order': (_) => OrdersPage(),
        '/admin/calculator': (_) => CalculatorPage(),
        '/admin/inventory': (_) => InventoryPage(),
        '/admin/reports': (_) => ReportsPage(),
        '/admin/calendar': (_) => CalendarPage(initialRole: UserRole.admin),
        '/admin/history': (_) => HistoryPage(role: UserRole.admin),
        '/admin/lab-test': (_) => LabTestPage(),
        '/admin/cost-calendar': (_) => CostCalendarPage(),
        '/admin/accounts': (_) => AdminAccountsPage(),

        // Production routes
        '/production/dashboard': (_) => ProductionDashboard(),
        '/production/queue': (_) => ProductionQueuePage(),
        '/production/inventory': (_) => InventoryPage(),
        '/production/calendar':
            (_) => CalendarPage(initialRole: UserRole.production),
        '/production/returned': (_) => ReturnedOrdersPage(),
        '/production/dispatch': (_) => DispatchPage(),
        '/production/loss': (_) => ProductionLossPage(),
        '/production/history': (_) => HistoryPage(role: UserRole.production),

        // Accounts routes
        '/accounts/dashboard': (_) => AccountsDashboard(),
        '/accounts/orders': (_) => AccountsOrdersPage(),
        '/accounts/history': (_) => accounts_history.AccountsHistoryPage(),
        '/accounts/purchase': (_) => PurchasePage(),
        '/accounts/calendar':
            (_) => CalendarPage(initialRole: UserRole.accounts),
        '/accounts/dispatch': (_) => DispatchTrackingPage(),

        // Lab Testing routes
        '/lab_testing/dashboard': (_) => LabTestingDashboard(),
      },
    );
  }
}
