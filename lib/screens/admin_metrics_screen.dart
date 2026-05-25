import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/google_sheets.dart';

class AdminMetricsScreen extends StatefulWidget {
  const AdminMetricsScreen({super.key});
  @override
  State<AdminMetricsScreen> createState() => _AdminMetricsScreenState();
}

class _AdminMetricsScreenState extends State<AdminMetricsScreen> {
  Map<String, double> _promediosPorGrupo = {};
  Map<String, Map<String, List<int>>> _puntajesPorUsuario = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _calcularMetricas();
  }

  Future<void> _calcularMetricas() async {
    final resultados = await GoogleSheetsService.obtenerResultados();

    Map<String, List<int>> puntajesPorGrupo = {};
    Map<String, Map<String, List<int>>> puntajesUsuarios = {};

    for (var r in resultados) {
      if (r['tipo'].toString().toLowerCase() == 'real') {
        String grupo = r['grupo'].toString();
        // 🔥 AHORA TOMAMOS EL CORREO (QUE TIENE EL NOMBRE DE VERDAD) PARA AGRUPAR
        String nombreUser = r['correo'].toString().toUpperCase();
        int puntaje = int.tryParse(r['puntaje'].toString()) ?? 0;

        puntajesPorGrupo.putIfAbsent(grupo, () => []).add(puntaje);
        puntajesUsuarios.putIfAbsent(grupo, () => {});
        puntajesUsuarios[grupo]!.putIfAbsent(nombreUser, () => []).add(puntaje);
      }
    }

    Map<String, double> promedios = {};
    puntajesPorGrupo.forEach((grupo, puntajes) {
      double suma = puntajes.reduce((a, b) => a + b).toDouble();
      promedios[grupo] = suma / puntajes.length;
    });

    setState(() {
      _promediosPorGrupo = promedios;
      _puntajesPorUsuario = puntajesUsuarios;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<String> grupos = _promediosPorGrupo.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Metrics")),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _promediosPorGrupo.isEmpty
          ? const Center(child: Text("No data from Real Tests yet.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Group Averages", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
            const SizedBox(height: 20),
            Container(
              height: 250,
              padding: const EdgeInsets.only(top: 20, right: 20, left: 10, bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black, width: 2), boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))]),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround, maxY: 100, barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(grupos[value.toInt()], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black87))))),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 1, dashArray: [5, 5])),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(grupos.length, (index) {
                    return BarChartGroupData(x: index, barRods: [BarChartRodData(toY: _promediosPorGrupo[grupos[index]]!, color: const Color(0xFF80CBC4), width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)), borderSide: const BorderSide(color: Colors.black, width: 2))]);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text("Student Performance", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                itemCount: grupos.length,
                itemBuilder: (context, index) {
                  String grupoActual = grupos[index];
                  Map<String, List<int>> alumnosDeEsteGrupo = _puntajesPorUsuario[grupoActual]!;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: const Color(0xFFFFCC80), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 2), boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(5, 5))]),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        iconColor: Colors.black, collapsedIconColor: Colors.black,
                        leading: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.black, width: 2))), child: const Icon(Icons.groups, color: Colors.black)),
                        title: Text("Grupo: $grupoActual", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
                        subtitle: Text("Promedio general: ${_promediosPorGrupo[grupoActual]!.toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                        children: alumnosDeEsteGrupo.keys.map((nombreAlumno) {
                          List<int> puntajesAlumno = alumnosDeEsteGrupo[nombreAlumno]!;
                          double promedioAlumno = puntajesAlumno.reduce((a, b) => a + b) / puntajesAlumno.length;

                          return Container(
                            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black, width: 2)), borderRadius: BorderRadius.vertical(bottom: Radius.circular(18))),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: const CircleAvatar(backgroundColor: Color(0xFFF3E5F5), child: Icon(Icons.person, color: Colors.black87)),
                              title: Text(nombreAlumno, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              subtitle: Text("Participación: ${puntajesAlumno.length} pruebas", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: promedioAlumno >= 60 ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black, width: 2)),
                                child: Text("${promedioAlumno.toInt()} pts", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}