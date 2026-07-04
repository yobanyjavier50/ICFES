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

  List<dynamic> _estudiantes = [];
  Map<String, double> _promedios = {};
  bool _cargando = true;
  String _filtroActual = 'Nombre (A-Z)';

  // Controladores para agregar un nuevo estudiante
  final _correoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatosYPromedios();
  }

  Future<void> _cargarDatosYPromedios() async {
    final usuarios = await GoogleSheetsService.obtenerUsuarios();
    final resultados = await GoogleSheetsService.obtenerResultados();

    if (!mounted) return;

    List<dynamic> estudiantesGrupo = usuarios.where((u) => u['grupo'] == widget.nombreGrupo).toList();
    Map<String, List<int>> puntajesPorEstudiante = {};

    for (var r in resultados) {
      if (r['grupo'] == widget.nombreGrupo &&
          (r['tipo'].toString().toLowerCase() == 'real' || r['tipoPrueba']?.toString().toLowerCase() == 'real')) {
        String correo = r['correo'].toString();
        int pts = int.tryParse(r['puntaje'].toString()) ?? 0;
        puntajesPorEstudiante.putIfAbsent(correo, () => []).add(pts);
      }
    }

    Map<String, double> promediosCalculados = {};
    for (var e in estudiantesGrupo) {
      String correo = e['correo'].toString();
      if (puntajesPorEstudiante.containsKey(correo) && puntajesPorEstudiante[correo]!.isNotEmpty) {
        double suma = puntajesPorEstudiante[correo]!.reduce((a, b) => a + b).toDouble();
        promediosCalculados[correo] = suma / puntajesPorEstudiante[correo]!.length;
      } else {
        promediosCalculados[correo] = -1.0;
      }
    }

    setState(() {
      _estudiantes = estudiantesGrupo;
      _promedios = promediosCalculados;
      _cargando = false;
    });

    _aplicarFiltro(_filtroActual);
  }

  void _aplicarFiltro(String filtro) {
    setState(() {
      _filtroActual = filtro;
      if (filtro == 'Nombre (A-Z)') {
        _estudiantes.sort((a, b) => a['correo'].toString().toLowerCase().compareTo(b['correo'].toString().toLowerCase()));
      } else if (filtro == 'Nombre (Z-A)') {
        _estudiantes.sort((a, b) => b['correo'].toString().toLowerCase().compareTo(a['correo'].toString().toLowerCase()));
      } else if (filtro == 'Mejor Puntaje') {
        _estudiantes.sort((a, b) {
          double pA = _promedios[a['correo'].toString()] ?? -1.0;
          double pB = _promedios[b['correo'].toString()] ?? -1.0;
          return pB.compareTo(pA);
        });
      } else if (filtro == 'Menor Puntaje') {
        _estudiantes.sort((a, b) {
          double pA = _promedios[a['correo'].toString()] ?? -1.0;
          double pB = _promedios[b['correo'].toString()] ?? -1.0;
          if (pA == -1.0 && pB != -1.0) return 1;
          if (pB == -1.0 && pA != -1.0) return -1;
          return pA.compareTo(pB);
        });
      }
    });
  }

  // 🔥 NUEVO: Función para mostrar ventana de agregar estudiante
  void _mostrarDialogoAgregarEstudiante() {
    _correoCtrl.clear();
    _nombreCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Añadir Estudiante a ${widget.nombreGrupo}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _correoCtrl, decoration: const InputDecoration(labelText: "Usuario (Ej. brandon123)")),
            const SizedBox(height: 10),
            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: "Contraseña / Código")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (_correoCtrl.text.trim().isEmpty || _nombreCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Llena ambos campos")));
                return;
              }
              Navigator.pop(ctx);
              setState(() => _cargando = true);

              // Reutilizamos la función registrarUsuario
              final res = await GoogleSheetsService.registrarUsuario(
                  _correoCtrl.text.trim().toLowerCase(),
                  "estudiante",
                  widget.nombreGrupo,
                  _nombreCtrl.text.trim()
              );

              if (res['success'] == true) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Estudiante añadido")));
                _cargarDatosYPromedios(); // Refresca la vista
              } else {
                setState(() => _cargando = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al añadir"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Añadir"),
          )
        ],
      ),
    );
  }

  // 🔥 NUEVO: Función para eliminar estudiante
  Future<void> _eliminarEstudiante(String correo) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Estudiante"),
        content: Text("¿Seguro que quieres borrar a $correo? Perderá el acceso."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      setState(() => _cargando = true);
      await GoogleSheetsService.eliminarUsuario(correo);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Estudiante eliminado")));
      _cargarDatosYPromedios(); // Refresca la vista
    }
  }

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
                const SizedBox(height: 15),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    AudioService.playClick();
                    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
                    await GoogleSheetsService.cambiarEstadoGlobal(widget.nombreGrupo, true);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Examen habilitado para TODO el grupo!"), backgroundColor: Colors.green));
                    }
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text("HABILITAR A TODO EL GRUPO", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 15),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Estudiantes Registrados", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filtroActual,
                            icon: const Icon(Icons.sort, color: Colors.indigo, size: 18),
                            style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13),
                            items: ['Nombre (A-Z)', 'Nombre (Z-A)', 'Mejor Puntaje', 'Menor Puntaje'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                            onChanged: (v) => _aplicarFiltro(v!),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 5),

                Expanded(
                  child: _cargando
                      ? const Center(child: CircularProgressIndicator())
                      : _estudiantes.isEmpty
                      ? const Center(child: Text("No hay estudiantes en este grupo"))
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _estudiantes.length,
                    itemBuilder: (context, index) {
                      final est = _estudiantes[index];
                      final correo = est['correo'].toString();
                      final prom = _promedios[correo] ?? -1.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: grisCampos, borderRadius: BorderRadius.circular(20)),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminStudentProgressScreen(nombreEstudiante: correo, correoEstudiante: correo),
                              ),
                            );
                          },
                          leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.indigo)),
                          title: Text(correo.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(prom == -1.0 ? "Código: ${est['nombre']} | Aún sin pruebas" : "Código: ${est['nombre']} | Promedio: ${prom.toStringAsFixed(1)} pts"),
                          // 🔥 NUEVO: Icono de papelera añadido al lado derecho del estudiante
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  AudioService.playClick();
                                  _eliminarEstudiante(correo);
                                },
                              ),
                              const Icon(Icons.chevron_right, color: Colors.black54),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Espacio extra para que la lista no quede escondida bajo el botón flotante
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      // 🔥 NUEVO: Botón Flotante para Añadir Estudiante
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoAgregarEstudiante,
        backgroundColor: amarilloBoton,
        foregroundColor: azulProfundo,
        icon: const Icon(Icons.person_add),
        label: const Text("AÑADIR ESTUDIANTE", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}