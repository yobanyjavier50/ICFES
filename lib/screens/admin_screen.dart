import 'package:flutter/material.dart';
import '../services/google_sheets.dart';
import 'admin_add_question.dart';
import 'admin_blocks_screen.dart';
import 'admin_metrics_screen.dart';
import 'login_screen.dart';
import 'admin_group_students_screen.dart';
import '../services/audio_service.dart';


class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final TextEditingController _grupoController = TextEditingController();
  bool _cargando = false;

  // --- COLORES UNIFICADOS CON EL LOGIN ---
  final Color bgColorOscuro = const Color(0xFFD6DBE8);
  final Color azulProfundo = const Color(0xFF090B22);
  final Color amarilloBoton = const Color(0xFFFFCA28);
  final Color grisCampos = const Color(0xFFF0F0F5);

  void _mostrarDialogoNuevoGrupo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Crear Nuevo Grupo"),
        content: TextField(
            controller: _grupoController,
            decoration: const InputDecoration(labelText: "Nombre del Grupo")
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(onPressed: _guardarGrupo, child: const Text("Guardar")),
        ],
      ),
    );
  }

  Future<void> _guardarGrupo() async {
    if (_grupoController.text.trim().isEmpty) return;
    Navigator.pop(context);
    setState(() => _cargando = true);
    await GoogleSheetsService.crearGrupo(_grupoController.text.trim());
    setState(() => _cargando = false);
    _grupoController.clear();
  }

  Future<void> _eliminarGrupoConfirmacion(String nombreGrupo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Grupo"),
        content: Text("¿Estás seguro de que deseas eliminar el grupo '$nombreGrupo'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Eliminar")
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _cargando = true);
      await GoogleSheetsService.eliminarGrupo(nombreGrupo);
      setState(() => _cargando = false);
    }
  }

  Widget _buildControlCard(String title, IconData icon, Color color, Widget screen) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        width: 105, // Un poco más compacto para que quepan 3 en fila
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: azulProfundo)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColorOscuro,
      body: Stack(
        children: [
          // --- CAPA BLANCA SUPERIOR ---
          Positioned.fill(
            top: 40,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topRight: Radius.circular(100)),
              ),
            ),
          ),

          // --- SEMICÍRCULO INFERIOR CON IMAGEN ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: azulProfundo,
                borderRadius: const BorderRadius.vertical(top: Radius.elliptical(400, 150)),
                image: DecorationImage(
                  image: const AssetImage('assets/planeta.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(azulProfundo.withOpacity(0.6), BlendMode.darken),
                ),
              ),
            ),
          ),

          // --- CONTENIDO ---
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Botón Regresar (Atrás al Login)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () {
                        AudioService.playClick();
                        Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false
                        );
                      },
                      child: CircleAvatar(
                        backgroundColor: amarilloBoton,
                        radius: 22,
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Text("ADMIN PANEL", style: TextStyle(color: azulProfundo, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        const Text("Control Center", style: TextStyle(color: Colors.blueGrey, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 30),

                        // --- ACCIONES PRINCIPALES ---
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildControlCard("New Block", Icons.add_box, Colors.teal, const AdminAddQuestionScreen()),
                            _buildControlCard("Manage", Icons.view_list, Colors.orange, const AdminBlocksScreen()),
                            _buildControlCard("Metrics", Icons.bar_chart, Colors.purple, const AdminMetricsScreen()),
                          ],
                        ),

                        const SizedBox(height: 30),
                        const Divider(thickness: 1),
                        const SizedBox(height: 10),
                        Text("STUDENT GROUPS", style: TextStyle(color: azulProfundo, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),

                        // --- LISTA DE GRUPOS ---
                        _cargando
                            ? const CircularProgressIndicator()
                            : FutureBuilder<List<String>>(
                          future: GoogleSheetsService.obtenerGrupos(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            final grupos = snapshot.data!;
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: grupos.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: grisCampos,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  // AQUI REEMPLAZAMOS EL LIST TILE
                                  child: ListTile(
                                    onTap: () {
                                      AudioService.playClick();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminGroupStudentsScreen(nombreGrupo: grupos[index]),
                                        ),
                                      );
                                    },
                                    leading: const Icon(Icons.groups, color: Colors.indigo),
                                    title: Text(grupos[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: const Text("Toca para ver estudiantes", style: TextStyle(fontSize: 11)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _eliminarGrupoConfirmacion(grupos[index]),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 100), // Espacio para el semicírculo
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevoGrupo,
        backgroundColor: amarilloBoton,
        foregroundColor: azulProfundo,
        label: const Text("ADD GROUP", style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.group_add),
      ),
    );
  }
}