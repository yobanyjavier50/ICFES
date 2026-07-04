import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../services/google_sheets.dart';
import 'real_quiz_screen.dart';
import 'student_results_screen.dart';
import 'login_screen.dart';
import '../services/audio_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String _nombreUsuario = "Student";
  List<String> _tiposDebiles = [];

  final Color bgColorOscuro = const Color(0xFFD6DBE8);
  final Color azulProfundo = const Color(0xFF090B22);
  final Color amarilloBoton = const Color(0xFFFFCA28);
  final Color grisCampos = const Color(0xFFF0F0F5);

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  void _cargarUsuario() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔥 Sincronización silenciosa:
    // si volvió internet, sube resultados y estados pendientes.
    GoogleSheetsService.sincronizarColaResultados();

    String? nombreGuardado = prefs.getString('email');

    List<String> debiles = [];
    List<String> tipos = ['1', '2', '3', '4', '5', '6', '7'];

    for (String tipo in tipos) {
      int total = prefs.getInt('total_tipo_$tipo') ?? 0;
      int errores = prefs.getInt('errores_tipo_$tipo') ?? 0;

      if (total > 0) {
        if ((errores / total) >= 0.6) {
          debiles.add(tipo);
        }
      }
    }

    if (!mounted) return;

    setState(() {
      if (nombreGuardado != null && nombreGuardado.trim().isNotEmpty) {
        _nombreUsuario = nombreGuardado
            .split(' ')
            .map(
              (w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1)}'
              : '',
        )
            .join(' ');
      } else {
        _nombreUsuario = "Student";
      }

      _tiposDebiles = debiles;
    });
  }

  void _iniciarPrueba(BuildContext context, String categoria) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );

    // 🔥 Si es examen real, valida online u offline.
    if (categoria == 'real') {
      final prefs = await SharedPreferences.getInstance();
      final miCorreo = prefs.getString('email') ?? "";

      final habilitado =
      await GoogleSheetsService.verificarIntentoHabilitado(miCorreo);

      if (!habilitado) {
        if (context.mounted) {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "No tienes intentos habilitados. Pídele a tu profesor que te habilite uno.",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }

        return;
      }
    }

    final todasLasPreguntas =
    await GoogleSheetsService.obtenerPreguntas(categoria);

    List<dynamic> preguntasFinales = [];
    Map<String, List<dynamic>> bloques = {};

    for (var p in todasLasPreguntas) {
      bloques.putIfAbsent(p['bloqueId'].toString(), () => []).add(p);
    }

    Map<String, List<String>> bloquesPorTipo = {};

    bloques.forEach((bId, listaPreg) {
      bloquesPorTipo
          .putIfAbsent(listaPreg.first['tipoGrupo'].toString(), () => [])
          .add(bId);
    });

    final random = Random();

    List<String> tiposRequeridos = ['1', '2', '3', '4', '5', '6', '7'];

    for (String tipo in tiposRequeridos) {
      if (bloquesPorTipo.containsKey(tipo) &&
          bloquesPorTipo[tipo]!.isNotEmpty) {
        String bloqueElegido = bloquesPorTipo[tipo]![
        random.nextInt(bloquesPorTipo[tipo]!.length)];

        preguntasFinales.addAll(bloques[bloqueElegido]!);
      }
    }

    if (context.mounted) {
      Navigator.pop(context);

      if (preguntasFinales.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No hay preguntas para '$categoria'."),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RealQuizScreen(
            preguntas: preguntasFinales,
            esReal: categoria == 'real',
          ),
        ),
      ).then((_) {
        _cargarUsuario();
      });
    }
  }

  void _iniciarPruebaDebil(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );

    final todasLasPreguntas =
    await GoogleSheetsService.obtenerPreguntas('practica');

    List<dynamic> preguntasFinales = [];

    for (var p in todasLasPreguntas) {
      String tipoGrupo = p['tipoGrupo'].toString();

      if (_tiposDebiles.contains(tipoGrupo)) {
        preguntasFinales.add(p);
      }
    }

    if (context.mounted) {
      Navigator.pop(context);

      if (preguntasFinales.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No hay preguntas de práctica disponibles para esas secciones aún.",
            ),
          ),
        );

        return;
      }

      preguntasFinales.shuffle();

      if (preguntasFinales.length > 20) {
        preguntasFinales = preguntasFinales.sublist(0, 20);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RealQuizScreen(
            preguntas: preguntasFinales,
            esReal: false,
          ),
        ),
      ).then((_) {
        _cargarUsuario();
      });
    }
  }

  void _cerrarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('email');
    await prefs.remove('nombre');
    await prefs.remove('grupo');
    await prefs.remove('esAdmin');

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColorOscuro,
      body: Stack(
        children: [
          Positioned.fill(
            top: 40,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topRight: Radius.circular(100)),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                color: azulProfundo,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.elliptical(400, 180),
                ),
                image: DecorationImage(
                  image: const AssetImage('assets/estudiante.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    azulProfundo.withValues(alpha: 0.7),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Dashboard",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: amarilloBoton,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                        onPressed: () => _cerrarSesion(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: amarilloBoton,
                                  width: 2,
                                ),
                              ),
                              child: const CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.white,
                                backgroundImage:
                                AssetImage('assets/cara.png'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Hello, $_nombreUsuario!",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: azulProfundo,
                                    ),
                                  ),
                                  const Text(
                                    "Ready to practice?",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 35),

                        if (_tiposDebiles.isNotEmpty)
                          _buildMenuCard(
                            "Weak Points Practice",
                            "Vas a practicar solo las partes: ${_tiposDebiles.join(', ')}",
                            Icons.local_fire_department,
                            Colors.deepOrangeAccent,
                                () => _iniciarPruebaDebil(context),
                          ),

                        _buildMenuCard(
                          "Practice Mode",
                          "Study at your own pace with feedback.",
                          Icons.edit_note,
                          const Color(0xFF80CBC4),
                              () => _iniciarPrueba(context, 'practica'),
                        ),

                        _buildMenuCard(
                          "Saber 11 Mock Test",
                          "Real time exam. Official structure.",
                          Icons.timer,
                          const Color(0xFFF48FB1),
                              () => _iniciarPrueba(context, 'real'),
                        ),

                        _buildMenuCard(
                          "My Progress",
                          "Check your stats and history.",
                          Icons.bar_chart,
                          const Color(0xFFCE93D8),
                              () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentResultsScreen(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: () {
        AudioService.playClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                size: 30,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: azulProfundo,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}