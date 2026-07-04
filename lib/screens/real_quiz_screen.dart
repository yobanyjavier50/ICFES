import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/google_sheets.dart';
import '../services/audio_service.dart';

class RealQuizScreen extends StatefulWidget {
  final List<dynamic> preguntas;
  final bool esReal;

  const RealQuizScreen({
    super.key,
    required this.preguntas,
    required this.esReal,
  });

  @override
  State<RealQuizScreen> createState() => _RealQuizScreenState();
}

class _RealQuizScreenState extends State<RealQuizScreen> {
  int _idx = 0;
  int _t = 0;

  Timer? _timer;
  Map<int, String> _userAns = {};

  bool _puedeSalir = false;
  bool _finalizando = false;

  final Color azulProfundo = const Color(0xFF090B22);
  final Color amarilloBoton = const Color(0xFFFFCA28);
  final Color grisCampos = const Color(0xFFF0F0F5);

  @override
  void initState() {
    super.initState();

    if (widget.esReal) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
            (t) {
          if (mounted) {
            setState(() => _t++);
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() async {
    if (_finalizando) return;

    setState(() {
      _finalizando = true;
    });

    _timer?.cancel();

    int score = 0;
    Map<String, int> fallosEnEsteExamen = {};
    Map<String, int> totalEnEsteExamen = {};

    for (int i = 0; i < widget.preguntas.length; i++) {
      String tipo = widget.preguntas[i]['tipoGrupo']?.toString() ?? 'General';

      totalEnEsteExamen[tipo] = (totalEnEsteExamen[tipo] ?? 0) + 1;

      if (_userAns[i] == widget.preguntas[i]['respuesta'].toString()) {
        score += 10;
      } else {
        fallosEnEsteExamen[tipo] = (fallosEnEsteExamen[tipo] ?? 0) + 1;
      }
    }

    int maxScorePosible = widget.preguntas.length * 10;
    double porcentaje = maxScorePosible > 0 ? (score / maxScorePosible) : 0;

    if (porcentaje >= 0.6) {
      AudioService.playSuccess();
    } else {
      AudioService.playFail();
    }

    final prefs = await SharedPreferences.getInstance();

    for (var entry in totalEnEsteExamen.entries) {
      String tipo = entry.key;
      int totalActual = entry.value;
      int fallosActuales = fallosEnEsteExamen[tipo] ?? 0;

      int totalPrevio = prefs.getInt('total_tipo_$tipo') ?? 0;
      int fallosPrevios = prefs.getInt('errores_tipo_$tipo') ?? 0;

      await prefs.setInt('total_tipo_$tipo', totalPrevio + totalActual);
      await prefs.setInt('errores_tipo_$tipo', fallosPrevios + fallosActuales);
    }

    final email = prefs.getString('email') ?? "";
    final grupo = prefs.getString('grupo') ?? "";

    await GoogleSheetsService.guardarResultado(
      email,
      grupo,
      widget.esReal ? "Real" : "Practica",
      score,
    );

    // 🔥 Si fue examen real, consume el intento localmente y luego lo sincroniza.
    if (widget.esReal) {
      await GoogleSheetsService.cambiarEstadoExamen(email, false);
    }

    if (!mounted) return;

    setState(() {
      _puedeSalir = true;
      _finalizando = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("¡Examen Finalizado!"),
        content: Text("Tu puntaje es: $score"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _mostrarRetroalimentacion(String retro) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(
          left: 25,
          right: 25,
          top: 20,
          bottom: 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Feedback",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: azulProfundo,
                  ),
                ),
                IconButton(
                  icon: CircleAvatar(
                    backgroundColor: grisCampos,
                    radius: 16,
                    child: const Icon(
                      Icons.close,
                      color: Colors.black87,
                      size: 18,
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(thickness: 1.5),
            const SizedBox(height: 10),
            Text(
              retro.trim().isEmpty
                  ? "Sin retroalimentación para esta pregunta."
                  : retro,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.blueGrey,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.preguntas.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text("No hay preguntas"),
        ),
      );
    }

    final p = widget.preguntas[_idx];

    return PopScope(
      canPop: _puedeSalir,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        bool confirmar = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("¿Abandonar prueba?"),
            content: const Text(
              "Si te sales ahora, la prueba se dará por terminada y todas las preguntas sin responder se calificarán como incorrectas. ¿Estás seguro?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  "Continuar prueba",
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Sí, terminar y salir",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ?? false;

        if (confirmar && mounted) {
          _finish();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            widget.esReal
                ? "Tiempo: ${(_t ~/ 60).toString().padLeft(2, '0')}:${(_t % 60).toString().padLeft(2, '0')}"
                : "Practice Mode",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p['textoBase'] != null &&
                        p['textoBase'].toString().trim().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          p['textoBase'],
                          style: const TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                    if (p['img'] != null && p['img'].isNotEmpty)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            p['img'],
                            height: 200,
                            errorBuilder: (_, __, ___) {
                              return const Icon(Icons.broken_image);
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    Text(
                      p['pregunta'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: azulProfundo,
                      ),
                    ),

                    const SizedBox(height: 20),

                    ...p['opciones'].map<Widget>((o) {
                      final stringValue = o.toString();
                      bool isSelected = _userAns[_idx] == stringValue;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? azulProfundo.withValues(alpha: 0.05)
                              : grisCampos,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                            isSelected ? azulProfundo : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: RadioListTile<String>(
                          title: Text(
                            stringValue,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: azulProfundo,
                            ),
                          ),
                          value: stringValue,
                          groupValue: _userAns[_idx],
                          activeColor: azulProfundo,
                          onChanged: (v) {
                            AudioService.playClick();
                            setState(() => _userAns[_idx] = v!);
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amarilloBoton,
                    foregroundColor: azulProfundo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  onPressed: _finalizando
                      ? null
                      : () {
                    AudioService.playClick();

                    if (!widget.esReal) {
                      _mostrarRetroalimentacion(p['retro'] ?? "");
                    }

                    if (_idx < widget.preguntas.length - 1) {
                      setState(() => _idx++);
                    } else {
                      _finish();
                    }
                  },
                  child: _finalizando
                      ? const CircularProgressIndicator()
                      : Text(
                    _idx < widget.preguntas.length - 1
                        ? "NEXT QUESTION"
                        : "FINISH",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}