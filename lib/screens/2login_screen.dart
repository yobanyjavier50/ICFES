import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_sheets.dart';
import 'admin_screen.dart';
import 'student_dashboard.dart';
import '../services/audio_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _nombre = TextEditingController();
  final _key = TextEditingController();

  bool _isAdmin = false;
  String? _grupoSeleccionado;
  List<String> _grupos = [];
  bool _cargando = false;

  final Color bgColorOscuro = const Color(0xFFD6DBE8);
  final Color azulProfundo = const Color(0xFF090B22);
  final Color amarilloBoton = const Color(0xFFFFCA28);
  final Color grisCampos = const Color(0xFFF0F0F5);

  @override
  void initState() {
    super.initState();
    _cargarGrupos();
  }

  void _cargarGrupos() async {
    final grupos = await GoogleSheetsService.obtenerGrupos();

    if (mounted) {
      setState(() {
        _grupos = grupos.where((g) => g.trim().isNotEmpty).toSet().toList();

        if (_grupoSeleccionado != null &&
            !_grupos.contains(_grupoSeleccionado)) {
          _grupoSeleccionado = null;
        }
      });
    }
  }

  Future<void> _prepararModoOffline(String usuarioLimpio) async {
    try {
      // Estas llamadas guardan caché local en GoogleSheetsService.
      await GoogleSheetsService.obtenerGrupos();
      await GoogleSheetsService.obtenerPreguntas('practica');
      await GoogleSheetsService.obtenerPreguntas('real');
      await GoogleSheetsService.obtenerResultados();

      // Guarda localmente si el examen real está habilitado.
      await GoogleSheetsService.verificarIntentoHabilitado(usuarioLimpio);

      // Si había resultados o estados pendientes, intenta subirlos.
      await GoogleSheetsService.sincronizarColaResultados();
    } catch (e) {
      print("No se pudo preparar completamente el modo offline: $e");
    }
  }

  void _acceder() async {
    if (_email.text.trim().isEmpty) return;

    setState(() => _cargando = true);

    final prefs = await SharedPreferences.getInstance();

    if (_isAdmin) {
      if (_key.text == "teacher2026") {
        await prefs.setString('email', _email.text.trim());
        await prefs.setBool('esAdmin', true);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminScreen()),
          );
        }
      } else {
        setState(() => _cargando = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Clave incorrecta")),
        );
      }

      return;
    }

    if (_nombre.text.trim().isEmpty || _grupoSeleccionado == null) {
      setState(() => _cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );

      return;
    }

    final usuarioLimpio = _email.text.toLowerCase().trim();
    final passLimpio = _nombre.text.trim();

    final check = await GoogleSheetsService.verificarUsuario(usuarioLimpio);

    if (check['success'] == true) {
      if (check['usuario']['nombre'].toString() == passLimpio &&
          check['usuario']['grupo'] == _grupoSeleccionado) {
        await prefs.setString('email', usuarioLimpio);
        await prefs.setString('nombre', passLimpio);
        await prefs.setString('grupo', _grupoSeleccionado!);
        await prefs.setBool('esAdmin', false);

        await prefs.setString(
          'perfil_offline_$usuarioLimpio',
          json.encode(check['usuario']),
        );

        // 🔥 Deja la app lista para funcionar offline después del primer login.
        await _prepararModoOffline(usuarioLimpio);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentDashboard()),
          );
        }
      } else {
        setState(() => _cargando = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Contraseña o grupo incorrecto",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() => _cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            check['message']?.toString() ??
                "Usuario no encontrado. Solo usuarios registrados pueden acceder.",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
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
              height: 280,
              decoration: BoxDecoration(
                color: azulProfundo,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.elliptical(400, 180),
                ),
                image: DecorationImage(
                  image: const AssetImage('assets/planeta.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    azulProfundo.withOpacity(0.6),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 70),
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () {
                        AudioService.playClick();
                        SystemNavigator.pop();
                      },
                      child: CircleAvatar(
                        backgroundColor: amarilloBoton,
                        radius: 22,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 2.0),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: CircleAvatar(
                      radius: 120,
                      backgroundColor: grisCampos,
                      backgroundImage: const AssetImage('assets/logo.jpeg'),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "WELCOME BACK",
                    style: TextStyle(
                      color: azulProfundo,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const Text(
                    "SIGN IN",
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildTextField(
                    controller: _email,
                    label: "Nombre",
                    icon: Icons.person_outline,
                  ),

                  if (!_isAdmin) ...[
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _nombre,
                      label: "Contraseña (Tu código)",
                      icon: Icons.lock_outline,
                      obscure: true,
                    ),
                    const SizedBox(height: 15),
                    _buildDropdown(),
                  ],

                  const SizedBox(height: 15),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Admin Mode",
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    value: _isAdmin,
                    activeColor: amarilloBoton,
                    onChanged: (v) => setState(() => _isAdmin = v),
                  ),

                  if (_isAdmin) ...[
                    _buildTextField(
                      controller: _key,
                      label: "Admin Password",
                      icon: Icons.lock_outline,
                      obscure: true,
                    ),
                  ],

                  SizedBox(height: _isAdmin ? 30 : 60),

                  _cargando
                      ? CircularProgressIndicator(color: amarilloBoton)
                      : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        AudioService.playClick();
                        _acceder();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amarilloBoton,
                        foregroundColor: azulProfundo,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        "SIGN IN",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(
        color: azulProfundo,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(
          color: Colors.black38,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: Icon(icon, color: Colors.black54),
        filled: true,
        fillColor: grisCampos,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 25,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: azulProfundo, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 4),
      decoration: BoxDecoration(
        color: grisCampos,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.transparent),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.arrow_drop_down_circle_outlined,
            color: Colors.black54,
          ),
          hint: const Text(
            "Select your Group",
            style: TextStyle(
              color: Colors.black38,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: _grupoSeleccionado,
          style: TextStyle(
            color: azulProfundo,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          items: _grupos.map((String grupo) {
            return DropdownMenuItem<String>(
              value: grupo,
              child: Text(grupo),
            );
          }).toList(),
          onChanged: (String? nuevoValor) {
            setState(() => _grupoSeleccionado = nuevoValor);
          },
        ),
      ),
    );
  }
}