import 'package:flutter/material.dart';
import '../services/google_sheets.dart';
import 'admin_student_progress_screen.dart';
import '../services/audio_service.dart';

class AdminGroupStudentsScreen extends StatefulWidget {
  final String nombreGrupo;
  const AdminGroupStudentsScreen({super.key, required this.nombreGrupo});

  @override
  State<AdminGroupStudentsScreen> createState() => _AdminGroupStudentsScreenState();
}

class _AdminGroupStudentsScreenState extends State<AdminGroupStudentsScreen> {
  final Color bgColorOscuro = const Color(0xFFD6DBE8);
  final Color azulProfundo = const Color(0xFF090B22);
  final Color amarilloBoton = const Color(0xFFFFCA28);
  final Color grisCampos = const Color(0xFFF0F0F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColorOscuro,
      body: Stack(
        children: [
          Positioned.fill(top: 40, child: Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topRight: Radius.circular(100))))),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(color: azulProfundo, borderRadius: const BorderRadius.vertical(top: Radius.elliptical(400, 150)), image: DecorationImage(image: const AssetImage('assets/planeta.png'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(azulProfundo.withOpacity(0.6), BlendMode.darken))),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(onTap: (){
                      AudioService.playClick();
                      Navigator.pop(context);
                    }, child: CircleAvatar(backgroundColor: amarilloBoton, radius: 22, child: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18))),
                  ),
                ),
                Text(widget.nombreGrupo.toUpperCase(), style: TextStyle(color: azulProfundo, fontSize: 24, fontWeight: FontWeight.w900)),
                const Text("Estudiantes Registrados", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: GoogleSheetsService.obtenerUsuarios(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      final estudiantes = snapshot.data!.where((u) => u['grupo'] == widget.nombreGrupo).toList();
                      if (estudiantes.isEmpty) return const Center(child: Text("No hay estudiantes en este grupo"));

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: estudiantes.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: grisCampos, borderRadius: BorderRadius.circular(20)),
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminStudentProgressScreen(
                                      // 🔥 AQUÍ PASAMOS EL 'correo' COMO NOMBRE
                                      nombreEstudiante: estudiantes[index]['correo'],
                                      correoEstudiante: estudiantes[index]['correo'],
                                    ),
                                  ),
                                );
                              },
                              leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.indigo)),
                              // 🔥 MOSTRAMOS EL 'correo' COMO TITULO Y EL 'nombre' COMO CÓDIGO
                              title: Text(estudiantes[index]['correo'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Código: ${estudiantes[index]['nombre']}"),
                              trailing: const Icon(Icons.chevron_right, color: Colors.black54),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}