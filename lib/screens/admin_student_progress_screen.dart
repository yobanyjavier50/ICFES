import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/google_sheets.dart';
import '../services/audio_service.dart';

class AdminStudentProgressScreen extends StatefulWidget {
  final String nombreEstudiante;
  final String correoEstudiante;

  const AdminStudentProgressScreen({
    super.key,
    required this.nombreEstudiante,
    required this.correoEstudiante
  });

  @override
  State<AdminStudentProgressScreen> createState() => _AdminStudentProgressScreenState();
}

class _AdminStudentProgressScreenState extends State<AdminStudentProgressScreen> {
  List<dynamic> _historial = [];
  bool _cargando = true;

  // --- COLORES UNIFICADOS ---
  final Color bgColorOscuro = const Color(0xFFD6DBE8);
  final Color azulProfundo = const Color(0xFF090B22);
  final Color amarilloBoton = const Color(0xFFFFCA28);
  final Color grisCampos = const Color(0xFFF0F0F5);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final todos = await GoogleSheetsService.obtenerResultados();
    setState(() {
      // Filtramos solo los resultados de este estudiante y que sean exámenes "Reales"
      _historial = todos.where((r) =>
      r['correo'] == widget.correoEstudiante &&
          (r['tipo'].toString().toLowerCase() == 'real' || r['tipoPrueba'].toString().toLowerCase() == 'real')
      ).toList();
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColorOscuro,
      body: Stack(
        children: [
          // Capa Blanca
          Positioned.fill(
            top: 40,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topRight: Radius.circular(100)),
              ),
            ),
          ),

          // Semicírculo inferior
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
                  colorFilter: ColorFilter.mode(azulProfundo.withValues(alpha: 0.6), BlendMode.darken),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Botón de retroceso
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: (){
                        AudioService.playClick();
                        Navigator.pop(context);
                      },
                      child: CircleAvatar(
                        backgroundColor: amarilloBoton,
                        radius: 22,
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
                      ),
                    ),
                  ),
                ),

                // Título
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(widget.nombreEstudiante.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(color: azulProfundo, fontSize: 22, fontWeight: FontWeight.w900)),
                      const Text("Progreso en Exámenes Reales", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Contenido principal
                Expanded(
                  child: _cargando
                      ? const Center(child: CircularProgressIndicator())
                      : _historial.isEmpty
                      ? const Center(child: Text("El estudiante aún no tiene resultados.", style: TextStyle(fontWeight: FontWeight.bold)))
                      : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // GRÁFICA
                        Container(
                          height: 200,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: grisCampos,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true, drawVerticalLine: false),
                                titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) => Text("Int. ${value.toInt() + 1}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            reservedSize: 22
                                        )
                                    )
                                ),
                                borderData: FlBorderData(show: false),
                                minY: 0,
                                lineBarsData: [
                                  LineChartBarData(
                                      spots: List.generate(_historial.length, (index) => FlSpot(index.toDouble(), double.tryParse(_historial[index]['puntaje'].toString()) ?? 0)),
                                      isCurved: true,
                                      color: azulProfundo,
                                      barWidth: 4,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(show: true, color: azulProfundo.withValues(alpha: 0.2))
                                  )
                                ],
                              )
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text("Historial de Intentos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        // LISTA DE INTENTOS
                        Expanded(
                            child: ListView.builder(
                                itemCount: _historial.length,
                                itemBuilder: (context, index) {
                                  // Mostramos del más reciente al más antiguo
                                  final intento = _historial.reversed.toList()[index];
                                  return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: ListTile(
                                          leading: CircleAvatar(backgroundColor: amarilloBoton.withValues(alpha: 0.3), child: Icon(Icons.assignment_turned_in, color: azulProfundo)),
                                          title: Text("Puntaje: ${intento['puntaje']}", style: TextStyle(fontWeight: FontWeight.bold, color: azulProfundo)),
                                          subtitle: Text(intento['fecha']?.toString().substring(0, 16) ?? "Sin fecha"),
                                          trailing: const Text("EXAMEN", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))
                                      )
                                  );
                                }
                            )
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
    );
  }
}