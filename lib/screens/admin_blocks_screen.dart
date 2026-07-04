import 'package:flutter/material.dart';
import '../services/google_sheets.dart';
import 'admin_edit_block_screen.dart';
import '../services/audio_service.dart';

class AdminBlocksScreen extends StatefulWidget {
  const AdminBlocksScreen({super.key});

  @override
  State<AdminBlocksScreen> createState() => _AdminBlocksScreenState();
}

class _AdminBlocksScreenState extends State<AdminBlocksScreen> {
  Map<String, List<dynamic>> _bloques = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarBloques();
  }

  Future<void> _cargarBloques() async {
    setState(() => _cargando = true);
    // Ahora pasamos "" y el nuevo Google Script traerá todas las preguntas
    final todasLasPreguntas = await GoogleSheetsService.obtenerPreguntas("");

    Map<String, List<dynamic>> bloquesAgrupados = {};
    for (var p in todasLasPreguntas) {
      String bId = p['bloqueId']?.toString() ?? "Individuales";
      bloquesAgrupados.putIfAbsent(bId, () => []).add(p);
    }

    setState(() {
      _bloques = bloquesAgrupados;
      _cargando = false;
    });
  }

  // --- NUEVA FUNCIÓN: Dialogo de Edición ---
  Future<void> _editarPreguntaDialogo(Map<String, dynamic> p) async {
    final pregCtrl = TextEditingController(text: p['pregunta']);
    final retroCtrl = TextEditingController(text: p['retro']);

    List<dynamic> ops = p['opciones'];
    List<TextEditingController> opsCtrls = List.generate(4, (i) => TextEditingController(text: ops.length > i ? ops[i].toString() : ""));
    String? respCorrecta = p['respuesta'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text("Editar Pregunta"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: pregCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Pregunta")),
                    const Divider(),
                    ...List.generate(4, (i) => TextField(
                      controller: opsCtrls[i],
                      decoration: InputDecoration(labelText: "Opción ${String.fromCharCode(65 + i)}"), // A, B, C, D
                      onChanged: (v) => setStateSB((){}), // Refrescar el dropdown al escribir
                    )),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Respuesta Correcta"),
                      value: opsCtrls.any((c) => c.text == respCorrecta) ? respCorrecta : null,
                      items: opsCtrls.where((c) => c.text.isNotEmpty).map((c) => DropdownMenuItem(value: c.text, child: Text(c.text))).toList(),
                      onChanged: (v) => setStateSB(() => respCorrecta = v),
                    ),
                    TextField(controller: retroCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Retroalimentación")),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _cargando = true);
                    await GoogleSheetsService.editarPregunta({
                      "idPregunta": p['id'],
                      "pregunta": pregCtrl.text.trim(),
                      "opciones": opsCtrls.map((c) => c.text.trim()).toList(),
                      "respuesta": respCorrecta ?? opsCtrls[0].text.trim(),
                      "retro": retroCtrl.text.trim(),
                    });
                    await _cargarBloques();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pregunta actualizada")));
                  },
                  child: const Text("Guardar Cambios"),
                )
              ],
            );
          }
      ),
    );
  }

  Future<void> _borrarBloqueCompleto(String bloqueId) async {
    bool confirmar = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Eliminar Bloque"),
          content: const Text("¿Estás seguro? Esto borrará TODAS las preguntas de este grupo."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text("Sí, Eliminar", style: TextStyle(color: Colors.white))),
          ],
        )
    ) ?? false;

    if (confirmar) {
      setState(() => _cargando = true);
      await GoogleSheetsService.eliminarBloque(bloqueId);
      await _cargarBloques();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bloque eliminado")));
    }
  }

  Future<void> _borrarPregunta(String idPregunta) async {
    bool confirmar = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Eliminar Pregunta"),
          content: const Text("¿Deseas eliminar solo esta pregunta?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.white))),
          ],
        )
    ) ?? false;

    if (confirmar) {
      setState(() => _cargando = true);
      await GoogleSheetsService.eliminarPregunta(idPregunta);
      await _cargarBloques();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pregunta eliminada")));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> llavesBloques = _bloques.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Gestión de Bloques Creados")),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _bloques.isEmpty
          ? const Center(child: Text("No hay preguntas registradas en el sistema."))
          : ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: llavesBloques.length,
        itemBuilder: (context, index) {
          String bloqueId = llavesBloques[index];
          List<dynamic> preguntasDelBloque = _bloques[bloqueId]!;
          String tipoGrupo = preguntasDelBloque.first['tipoGrupo']?.toString() ?? "N/A";
          String categoria = preguntasDelBloque.first['categoria']?.toString().toLowerCase() ?? "N/A";
          String textoBase = preguntasDelBloque.first['textoBase']?.toString() ?? "";

          // --- COLORES SEGÚN CATEGORÍA ---
          bool esReal = categoria == 'real';
          Color badgeColor = esReal ? Colors.red.shade400 : Colors.green.shade400;
          String badgeText = esReal ? "EXAMEN REAL" : "PRÁCTICA";

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(side: BorderSide(color: badgeColor, width: 2), borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              leading: Icon(Icons.view_carousel, color: badgeColor, size: 30),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                    child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text("Parte $tipoGrupo", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              subtitle: Text("Contiene ${preguntasDelBloque.length} preguntas"),
              children: [
                if (textoBase.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.yellow.shade50,
                    child: Text("Texto Base:\n$textoBase", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                  ),

                ...preguntasDelBloque.map((p) => Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
                  child: ListTile(
                    title: Text(p['pregunta'], maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text("Respuesta: ${p['respuesta']}"),
                  ),
                )),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue),
                            onPressed: () async {
                              // Navegamos a la pantalla de edición y pasamos los datos
                              final huboCambios = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AdminEditBlockScreen(
                                          bloqueId: bloqueId,
                                          preguntasIniciales: preguntasDelBloque
                                      )
                                  )
                              );

                              // Si se guardaron cambios, recargamos la lista
                              if (huboCambios == true) {
                                _cargarBloques();
                              }
                            },
                            icon: const Icon(Icons.edit_document),
                            label: const Text("EDITAR TODO EL BLOQUE")
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
                            onPressed: () => _borrarBloqueCompleto(bloqueId),
                            icon: const Icon(Icons.delete_forever),
                            label: const Text("ELIMINAR TODO EL BLOQUE")
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}