import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../services/google_sheets.dart';
import '../services/audio_service.dart';

class AdminEditBlockScreen extends StatefulWidget {
  final String bloqueId;
  final List<dynamic> preguntasIniciales;

  const AdminEditBlockScreen({super.key, required this.bloqueId, required this.preguntasIniciales});

  @override
  State<AdminEditBlockScreen> createState() => _AdminEditBlockScreenState();
}

class _AdminEditBlockScreenState extends State<AdminEditBlockScreen> {
  late String _cat;
  late String _tipoGrupo;
  int _numOpciones = 4;

  List<Map<String, dynamic>> _preguntasBloque = [];
  bool _isUploadingImage = false;
  bool _isSavingGroup = false;

  final _textoBaseController = TextEditingController();
  final _preg = TextEditingController();
  List<TextEditingController> _ops = [];
  final _retro = TextEditingController();
  String _correcta = '0';
  File? _file;

  @override
  void initState() {
    super.initState();
    // Precargar datos del bloque existente
    _cat = widget.preguntasIniciales.first['categoria']?.toString().toLowerCase() == 'real' ? 'real' : 'practica';
    _tipoGrupo = widget.preguntasIniciales.first['tipoGrupo']?.toString() ?? '1';
    _textoBaseController.text = widget.preguntasIniciales.first['textoBase']?.toString() ?? '';

    _preguntasBloque = widget.preguntasIniciales.map((p) {
      return {
        "textoBase": p['textoBase']?.toString() ?? "",
        "pregunta": p['pregunta']?.toString() ?? "",
        "opciones": List<String>.from(p['opciones'] ?? []),
        "respuesta": p['respuesta']?.toString() ?? "",
        "retro": p['retro']?.toString() ?? "",
        "img": p['img']?.toString() ?? ""
      };
    }).toList();

    _cambiarTipoGrupo(_tipoGrupo);
  }

  void _generarOpciones() {
    _ops = List.generate(_numOpciones, (_) => TextEditingController());
    _correcta = '0';
  }

  void _cambiarTipoGrupo(String tipo) {
    setState(() {
      _tipoGrupo = tipo;
      if (tipo == '1') _numOpciones = 8;
      else if (tipo == '2' || tipo == '4') _numOpciones = 3;
      else _numOpciones = 4;
      _generarOpciones();
    });
  }

  Future<void> _addQuestionToBlock() async {
    if (_preg.text.trim().isEmpty || _ops.any((o) => o.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Llena la pregunta y todas las opciones")));
      return;
    }

    setState(() => _isUploadingImage = true);
    try {
      String imgLink = "";
      if (_file != null) {
        final bytes = await _file!.readAsBytes();
        imgLink = await GoogleSheetsService.subirImagenDrive(base64Encode(bytes), "img_${DateTime.now().millisecondsSinceEpoch}.jpg") ?? "";
        if (imgLink.isEmpty) throw Exception("Error al subir imagen");
      }

      setState(() {
        _preguntasBloque.add({
          "textoBase": _textoBaseController.text.trim(),
          "pregunta": _preg.text.trim(),
          "opciones": _ops.map((e) => e.text.trim()).toList(),
          "respuesta": _ops[int.parse(_correcta)].text.trim(),
          "retro": _retro.text.trim(),
          "img": imgLink
        });

        _preg.clear();
        for(var o in _ops) { o.clear(); }
        _retro.clear();
        _file = null;
        _correcta = '0';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pregunta añadida al bloque")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  // --- NUEVA FUNCIÓN: Editar pregunta individual localmente antes de guardar el bloque ---
  Future<void> _editarPreguntaLocal(int index) async {
    final p = _preguntasBloque[index];
    final pregCtrl = TextEditingController(text: p['pregunta']);
    final retroCtrl = TextEditingController(text: p['retro']);

    List<String> ops = List<String>.from(p['opciones']);
    List<TextEditingController> opsCtrls = List.generate(ops.length, (i) => TextEditingController(text: ops[i]));
    String respCorrecta = p['respuesta'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text("Editar Detalles de Pregunta"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: pregCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Pregunta")),
                    const Divider(),
                    ...List.generate(opsCtrls.length, (i) => TextField(
                      controller: opsCtrls[i],
                      decoration: InputDecoration(labelText: "Opción ${String.fromCharCode(65 + i)}"),
                      onChanged: (v) => setStateSB((){}),
                    )),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Respuesta Correcta"),
                      value: opsCtrls.any((c) => c.text == respCorrecta) ? respCorrecta : (opsCtrls.isNotEmpty ? opsCtrls[0].text : null),
                      items: opsCtrls.where((c) => c.text.isNotEmpty).map((c) => DropdownMenuItem(value: c.text, child: Text(c.text))).toList(),
                      onChanged: (v) => setStateSB(() => respCorrecta = v ?? ""),
                    ),
                    TextField(controller: retroCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Retroalimentación")),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _preguntasBloque[index]['pregunta'] = pregCtrl.text.trim();
                      _preguntasBloque[index]['opciones'] = opsCtrls.map((c) => c.text.trim()).toList();
                      _preguntasBloque[index]['respuesta'] = respCorrecta;
                      _preguntasBloque[index]['retro'] = retroCtrl.text.trim();
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text("Confirmar"),
                )
              ],
            );
          }
      ),
    );
  }

  Future<void> _saveFullGroup() async {
    if (_preguntasBloque.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El bloque no puede quedar vacío")));
      return;
    }

    setState(() => _isSavingGroup = true);

    // 1. Actualizamos el texto base de todas las preguntas con lo que haya en el controlador
    String textoBaseFinal = _textoBaseController.text.trim();
    List<Map<String, dynamic>> bloqueFinal = _preguntasBloque.map((p) {
      return { ...p, "textoBase": textoBaseFinal };
    }).toList();

    // 2. Eliminamos el bloque antiguo de la base de datos
    await GoogleSheetsService.eliminarBloque(widget.bloqueId);

    // 3. Subimos la nueva versión
    bool exito = await GoogleSheetsService.guardarGrupoPreguntas(_cat, _tipoGrupo, bloqueFinal);

    setState(() => _isSavingGroup = false);

    if (exito && mounted) {
      Navigator.pop(context, true); // Retornamos true para indicar que hubo cambios
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bloque actualizado con éxito")));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al actualizar bloque"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editando Bloque Existente")),
      body: _isSavingGroup
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Aplicando cambios en la base de datos...")]))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    const Text("Propiedades del Bloque", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        DropdownButton<String>(value: _cat, items: const [DropdownMenuItem(value: 'practica', child: Text("Práctica")), DropdownMenuItem(value: 'real', child: Text("Real"))], onChanged: (v) => setState(() => _cat = v!)),
                        DropdownButton<String>(
                            value: _tipoGrupo,
                            items: const [
                              DropdownMenuItem(value: '1', child: Text("Parte 1 (A-H)")),
                              DropdownMenuItem(value: '2', child: Text("Parte 2 (Convers.)")),
                              DropdownMenuItem(value: '3', child: Text("Parte 3 (Lectura Larga)")),
                              DropdownMenuItem(value: '4', child: Text("Parte 4 (Lectura Corta)")),
                              DropdownMenuItem(value: '5', child: Text("Parte 5 (Completar texto)"))
                            ],
                            onChanged: (v) => _cambiarTipoGrupo(v!)
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
                controller: _textoBaseController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: "Texto Base o Lectura (Compartido)", border: OutlineInputBorder())
            ),

            const SizedBox(height: 30),
            Text("Preguntas Existentes (${_preguntasBloque.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
            const Divider(),

            ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _preguntasBloque.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text("${index + 1}")),
                      title: Text(_preguntasBloque[index]['pregunta'], maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                AudioService.playClick(); // 🔥 Sonido
                                _editarPreguntaLocal(index);
                              }
                          ),
                          IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                AudioService.playClick(); // 🔥 Sonido
                                setState(() => _preguntasBloque.removeAt(index));
                              }
                          ),
                        ],
                      ),
                    ),
                  );
                }
            ),

            const SizedBox(height: 30),
            const Text("Añadir Nueva Pregunta a este Bloque", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
            const Divider(),

            TextField(controller: _preg, decoration: const InputDecoration(labelText: "Nueva Pregunta o Descripción")),
            ...List.generate(_numOpciones, (i) => TextField(controller: _ops[i], decoration: InputDecoration(labelText: "Opción ${String.fromCharCode(65 + i)}"))),
            DropdownButton<String>(isExpanded: true, value: _correcta, items: List.generate(_numOpciones, (i) => DropdownMenuItem(value: i.toString(), child: Text("Opción ${String.fromCharCode(65 + i)} es correcta"))), onChanged: (v) => setState(() => _correcta = v!)),
            TextField(controller: _retro, decoration: const InputDecoration(labelText: "Retroalimentación")),

            const SizedBox(height: 10),
            OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo, side: const BorderSide(color: Colors.indigo)),
                onPressed: () {
                  AudioService.playClick(); // 🔥 Sonido
                  _addQuestionToBlock();
                },
                icon: const Icon(Icons.add), label: const Text("Añadir al Bloque")
            ),

            const SizedBox(height: 40),
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  AudioService.playClick(); // 🔥 Sonido definitivo de guardado
                  _saveFullGroup();
                },
                icon: const Icon(Icons.save),
                label: const Text("GUARDAR CAMBIOS DEL BLOQUE", style: TextStyle(fontWeight: FontWeight.bold))
            )
          ],
        ),
      ),
    );
  }
}