import 'package:flutter/material.dart';

// Importaciones de pantallas esenciales
import 'screens/account_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/cuadre_screen.dart';
import 'screens/customer_statement_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_customer_screen.dart';
import 'screens/sales_order_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panda AutoVentas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD4AF37),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      // Ruta inicial de la aplicación
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
        '/customers': (context) => const CustomersScreen(),
        '/new_customer': (context) => const NewCustomerScreen(),
        '/statement': (context) => const CustomerStatementScreen(customer: '', customerLabel: ''),
        '/sales': (context) => const SalesOrderScreen(idCliente: '', nombreCliente: ''),
        '/expenses': (context) => const ExpensesScreen(),
        '/cuadre': (context) => const CuadreScreen(),
        '/account': (context) => const AccountScreen(),
      },
    );
  }
}
