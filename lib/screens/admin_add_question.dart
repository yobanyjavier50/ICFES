import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../services/google_sheets.dart';
import '../services/audio_service.dart';

class AdminAddQuestionScreen extends StatefulWidget {
  const AdminAddQuestionScreen({super.key});
  @override
  State<AdminAddQuestionScreen> createState() => _AdminAddQuestionScreenState();
}

class _AdminAddQuestionScreenState extends State<AdminAddQuestionScreen> {
  String _cat = 'practica';
  String _tipoGrupo = '1';
  int _numOpciones = 8; // 🔥 Dinámico según el tipo

  List<Map<String, dynamic>> _preguntasBloque = [];
  bool _isUploadingImage = false;
  bool _isSavingGroup = false;

  final _textoBaseController = TextEditingController(); // 🔥 NUEVO: Para el texto fijo
  final _preg = TextEditingController();
  List<TextEditingController> _ops = [];
  final _retro = TextEditingController();
  String _correcta = '0';
  File? _file;

  @override
  void initState() {
    super.initState();
    _generarOpciones();
  }

  void _generarOpciones() {
    _ops = List.generate(_numOpciones, (_) => TextEditingController());
    _correcta = '0';
  }

  void _cambiarTipoGrupo(String tipo) {
    setState(() {
      _tipoGrupo = tipo;
      // Adaptación automática al formato real del ICFES:
      if (tipo == '1') {
        _numOpciones = 8; // Parte 1 usa A-H
      } else if (tipo == '6' || tipo == '7') {
        _numOpciones = 4; // Partes 6 y 7 usan A, B, C, D
      } else {
        _numOpciones = 3; // Partes 2, 3, 4 y 5 usan solo A, B, C
      }
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

  Future<void> _saveFullGroup() async {
    if (_preguntasBloque.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agrega al menos 1 pregunta al grupo")));
      return;
    }

    setState(() => _isSavingGroup = true);
    bool exito = await GoogleSheetsService.guardarGrupoPreguntas(_cat, _tipoGrupo, _preguntasBloque);
    setState(() => _isSavingGroup = false);

    if (exito && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Grupo completo guardado con éxito")));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al guardar grupo"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Constructor de Grupos (ICFES)")),
      body: _isSavingGroup
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Guardando Bloque Completo...")]))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    const Text("Configuración del Bloque", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        DropdownButton<String>(value: _cat, items: const [DropdownMenuItem(value: 'practica', child: Text("Práctica")), DropdownMenuItem(value: 'real', child: Text("Real"))], onChanged: (v) => setState(() => _cat = v!)),
                        DropdownButton<String>(
                            value: _tipoGrupo,
                            items: const [
                              DropdownMenuItem(value: '1', child: Text("Parte 1 (Vocabulario)")),
                              DropdownMenuItem(value: '2', child: Text("Parte 2 (Avisos)")),
                              DropdownMenuItem(value: '3', child: Text("Parte 3 (Conversaciones)")),
                              DropdownMenuItem(value: '4', child: Text("Parte 4 (Texto Incompleto)")),
                              DropdownMenuItem(value: '5', child: Text("Parte 5 (Lectura Literal)")),
                              DropdownMenuItem(value: '6', child: Text("Parte 6 (Lectura Inferencial)")),
                              DropdownMenuItem(value: '7', child: Text("Parte 7 (Texto Complejo)"))
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
            const Text("Agregar Pregunta a este bloque", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),

            // 🔥 CAMPO PARA EL TEXTO FIJO / LECTURA
            TextField(
                controller: _textoBaseController,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: "Texto Base o Enunciado Fijo (Opcional)",
                    hintText: "Escribe aquí la lectura o instrucción que comparten todas las preguntas de este grupo",
                    border: OutlineInputBorder()
                )
            ),
            const SizedBox(height: 15),

            TextField(controller: _preg, decoration: const InputDecoration(labelText: "Pregunta o Descripción específica")),

            ...List.generate(_numOpciones, (i) => TextField(controller: _ops[i], decoration: InputDecoration(labelText: "Opción ${String.fromCharCode(65 + i)}"))), // Pone A, B, C...

            DropdownButton<String>(isExpanded: true, value: _correcta, items: List.generate(_numOpciones, (i) => DropdownMenuItem(value: i.toString(), child: Text("Opción ${String.fromCharCode(65 + i)} es la correcta"))), onChanged: (v) => setState(() => _correcta = v!)),

            TextField(controller: _retro, decoration: const InputDecoration(labelText: "Retroalimentación")),
            const SizedBox(height: 10),
            ElevatedButton.icon(
                onPressed: () async {
                  final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 15, maxWidth: 500);
                  if (p != null) setState(() => _file = File(p.path));
                },
                icon: const Icon(Icons.image), label: const Text("Elegir Imagen Opcional")
            ),
            if (_file != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Image.file(_file!, height: 100)),

            const SizedBox(height: 10),
            _isUploadingImage
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo, side: const BorderSide(color: Colors.indigo)),
                onPressed: () {
                  AudioService.playClick(); // 🔥 Sonido al añadir pregunta individual
                  _addQuestionToBlock();
                },
                icon: const Icon(Icons.add), label: const Text("Añadir Pregunta al Bloque actual")
            ),

            const SizedBox(height: 30),
            const Divider(thickness: 2),

            Text("Preguntas en este Bloque: ${_preguntasBloque.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
            const SizedBox(height: 10),

            if (_preguntasBloque.isEmpty)
              const Text("Aún no hay preguntas. Añade al menos una arriba.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
            else
              ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _preguntasBloque.length,
                  itemBuilder: (context, index) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text("${index + 1}")),
                        title: Text(_preguntasBloque[index]['pregunta'], maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              AudioService.playClick(); // 🔥 Sonido al remover de la lista temporal
                              setState(() => _preguntasBloque.removeAt(index));
                            }
                        ),
                      ),
                    );
                  }
              ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  AudioService.playClick(); // 🔥 Sonido al subir todo a internet
                  _saveFullGroup();
                },
                icon: const Icon(Icons.check_circle),
                label: const Text("FINALIZAR Y GUARDAR GRUPO", style: TextStyle(fontWeight: FontWeight.bold))
            )
          ],
        ),
      ),
    );
  }
}