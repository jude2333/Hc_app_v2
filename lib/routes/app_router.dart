import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/shell/main_shell.dart';
import 'package:anderson_crm_flutter/views/login_view.dart';
// import 'package:anderson_crm_flutter/screens/loading_screen.dart';
import 'package:anderson_crm_flutter/features/users/screens/Users.dart';
import '../screens/search_screen.dart';
import 'package:anderson_crm_flutter/screens/Notifications.dart';
import 'package:anderson_crm_flutter/features/dashboard/screens/dashboardScreen.dart';
// import 'package:anderson_crm_flutter/screens/billingWorkOrder.dart';
// import '../powersync/servicess/screens/work_order_page2.dart';
// import 'package:anderson_crm_flutter/powersync/screens/manager/manager_work_order.dart';
import 'package:anderson_crm_flutter/powersync/screens/technicians/technician_work_order.dart';
import 'package:anderson_crm_flutter/features/billing_work_order/screens/billing_work_order_page.dart';
import 'package:anderson_crm_flutter/features/manager_work_order/screens/manager_work_order_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) => '/dashboard',
        ),
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen2(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsPage(),
        ),
        GoRoute(
          path: '/work_orders',
          name: 'work_orders',
          builder: (context, state) => const ManagerWorkOrderPage(),
        ),
        GoRoute(
          path: '/my_work_orders',
          name: 'my_work_orders',
          builder: (context, state) => const TechnicianWorkOrderPage(),
        ),
        GoRoute(
          path: '/billing_work_orders',
          name: 'billing_work_orders',
          builder: (context, state) => const BillingWorkOrderPage(),
        ),
        GoRoute(
          path: '/users',
          name: 'users',
          builder: (context, state) => const UsersPage(),
        ),
        GoRoute(
          path: '/home',
          redirect: (context, state) => '/dashboard',
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('Path: ${state.uri}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    ),
  ),
);
