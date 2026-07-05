import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icfes/screens/login_screen.dart';
import 'package:icfes/screens/student_dashboard.dart';
import 'package:icfes/screens/admin_screen.dart';
import 'package:icfes/services/audio_service.dart';

void main() async {
  // Necesario para leer la memoria antes de lanzar la app
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService.inicializar();
  final prefs = await SharedPreferences.getInstance();

  final String? email = prefs.getString('email');
  final bool esAdmin = prefs.getBool('esAdmin') ?? false;

  Widget pantallaInicial;
  if (email == null) {
    pantallaInicial = const LoginScreen();
  } else {
    pantallaInicial = esAdmin ? const AdminScreen() : const StudentDashboard();
  }

  runApp(AplicacionPrincipal(proximaPantalla: pantallaInicial));
}

class AplicacionPrincipal extends StatelessWidget {
  final Widget proximaPantalla;
  const AplicacionPrincipal({super.key, required this.proximaPantalla});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Champ App 2026 by Hernan and Brandon',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4DB6AC)),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.w900),
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black, width: 2),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFCC80),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF4DB6AC), width: 3),
          ),
        ),
      ),
      home: proximaPantalla,
    );
  }
}