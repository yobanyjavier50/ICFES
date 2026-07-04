import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/google_sheets.dart';

class StudentResultsScreen extends StatefulWidget {
  const StudentResultsScreen({super.key});
  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  List<dynamic> _historial = [];
  bool _cargando = true;

  List<MapEntry<String, double>> _temasPorMejorar = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final miCorreo = prefs.getString('email') ?? "";
    final todos = await GoogleSheetsService.obtenerResultados();

    Map<String, double> fallosPorcentaje = {};
    List<String> tipos = ['1', '2', '3', '4', '5', '6', '7'];

    for (String tipo in tipos) {
      int total = prefs.getInt('total_tipo_$tipo') ?? 0;
      int errores = prefs.getInt('errores_tipo_$tipo') ?? 0;

      if (total > 0) {
        double porcentaje = (errores / total) * 100;
        if (porcentaje >= 60.0) {
          fallosPorcentaje[tipo] = porcentaje;
        }
      }
    }

    var listaFallos = fallosPorcentaje.entries.toList();
    listaFallos.sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _historial = todos.where((r) => r['correo'] == miCorreo && r['tipo'].toString().toLowerCase() == 'real').toList();
      _temasPorMejorar = listaFallos;
      _cargando = false;
    });
  }

  String _obtenerNombreTema(String tipo) {
    switch (tipo) {
      case '1': return "Parte 1 (Vocabulario / Descripciones)";
      case '2': return "Parte 2 (Avisos / Carteles)";
      case '3': return "Parte 3 (Conversaciones Cortas)";
      case '4': return "Parte 4 (Textos Incompletos Básicos)";
      case '5': return "Parte 5 (Comprensión de Lectura Literal)";
      case '6': return "Parte 6 (Comprensión de Lectura Inferencial)";
      case '7': return "Parte 7 (Textos Incompletos Avanzados)";
      default: return "Tema General";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Progreso")),
      body: _cargando ? const Center(child: CircularProgressIndicator()) : _historial.isEmpty ? const Center(child: Text("Aún no tienes resultados en exámenes reales."))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Evolución de Puntaje (Examen Real)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              flex: 2,
              child: LineChart(LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text("Intento ${value.toInt() + 1}", style: const TextStyle(fontSize: 10)), reservedSize: 30))),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)), minY: 0,
                lineBarsData: [LineChartBarData(spots: List.generate(_historial.length, (index) => FlSpot(index.toDouble(), double.tryParse(_historial[index]['puntaje'].toString()) ?? 0)), isCurved: true, color: Colors.indigo, barWidth: 4, isStrokeCapRound: true, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: Colors.indigo.withOpacity(0.2)))],
              )),
            ),
            const SizedBox(height: 20),

            if (_temasPorMejorar.isNotEmpty) ...[
              const Text("Insights de Estudio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.orange.shade200, width: 2)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Basado en tus errores, te recomendamos repasar más:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    const SizedBox(height: 8),
                    ..._temasPorMejorar.take(2).map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.deepOrange),
                          const SizedBox(width: 8),
                          Expanded(child: Text("${_obtenerNombreTema(entry.key)} (${entry.value.toInt()}% fallos)", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 14))),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            const Text("Historial Detallado", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(flex: 3, child: ListView.builder(itemCount: _historial.length, itemBuilder: (context, index) {
              final intento = _historial.reversed.toList()[index];
              return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.indigo.shade100, child: const Icon(Icons.assignment_turned_in, color: Colors.indigo)), title: Text("Puntaje: ${intento['puntaje']}", style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(intento['fecha'].toString().substring(0, 16)), trailing: const Text("Examen Real", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))));
            })),
          ],
        ),
      ),
    );
  }
}