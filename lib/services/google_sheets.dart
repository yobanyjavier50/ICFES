import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleSheetsService {
  // ⚠️ TU URL ORIGINAL INTACTA
  static const String _url = "https://script.google.com/macros/s/AKfycbxQSvhPRsJplXzT1Fif3Uy2K2GRF6VbOkQ2zzHZdqpz0-Ls_HgDmPsS_NpgGhDAUDEA/exec";

  // --- ESCUDO CONTRA REDIRECCIONES HTML Y ERRORES DE FORMATO ---
  static Future<String> _obtenerBodyReal(http.Response r) async {
    if ((r.statusCode == 302 || r.statusCode == 200) && r.body.contains("Moved Temporarily")) {
      final regex = RegExp(r'HREF="([^"]+)"', caseSensitive: false);
      final match = regex.firstMatch(r.body);
      if (match != null && match.groupCount >= 1) {
        final cleanUrl = match.group(1)!.replaceAll("&amp;", "&");
        // 🔥 AGREGADO: Timeout de 15s para las redirecciones de Google
        final res = await http.get(Uri.parse(cleanUrl)).timeout(const Duration(seconds: 15));
        return res.body;
      }
    }
    return r.body;
  }

  // 🔥 MÉTODO DE SINCRONIZACIÓN OFFLINE -> ONLINE
  static Future<void> sincronizarColaResultados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cola = prefs.getStringList('cola_resultados') ?? [];

      if (cola.isEmpty) return; // No hay nada pendiente por subir

      // Convertimos la lista de strings JSON en un solo Array JSON
      String payloadBatch = "[${cola.join(',')}]";

      final r = await http.post(Uri.parse(_url), body: {
        "action": "sincronizarCola",
        "resultados": payloadBatch
      }).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s

      if (r.statusCode == 200 || r.statusCode == 302) {
        // ¡Éxito! Vaciamos la bóveda local porque ya se subió todo a Sheets
        await prefs.remove('cola_resultados');
        print("Sincronización exitosa: ${cola.length} exámenes subidos.");
      }
    } catch (e) {
      print("Aún sin internet. La sincronización se hará luego.");
    }
  }

  // ==========================================
  // MÉTODOS DE USUARIOS Y GRUPOS (CON CACHÉ)
  // ==========================================

  static Future<List<String>> obtenerGrupos() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final r = await http.get(Uri.parse("$_url?action=obtenerGrupos")).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      final body = await _obtenerBodyReal(r);
      await prefs.setString('cache_grupos', body); // Guardar copia local
      List<dynamic> data = json.decode(body);
      return data.map((g) => g.toString()).toList();
    } catch (e) {
      // MODO OFFLINE
      String? cache = prefs.getString('cache_grupos');
      if (cache != null) {
        List<dynamic> data = json.decode(cache);
        return data.map((g) => g.toString()).toList();
      }
      return [];
    }
  }

  static Future<List<dynamic>> obtenerUsuarios() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final r = await http.get(Uri.parse("$_url?action=obtenerUsuarios")).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      final body = await _obtenerBodyReal(r);
      await prefs.setString('cache_usuarios', body); // Guardar copia local
      return json.decode(body);
    } catch (e) {
      // MODO OFFLINE
      String? cache = prefs.getString('cache_usuarios');
      return cache != null ? json.decode(cache) : [];
    }
  }

  static Future<Map<String, dynamic>> verificarUsuario(String correo) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final r = await http.get(Uri.parse("$_url?action=verificarUsuario&correo=$correo")).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      final body = await _obtenerBodyReal(r);

      // Intentamos sincronizar datos pendientes de paso, ya que sabemos que hay internet
      sincronizarColaResultados();

      final res = json.decode(body);
      if (res['success'] == true) {
        // 🔥 IMPORTANTE: Guardamos este usuario específico para que pueda entrar offline después
        await prefs.setString('perfil_offline_$correo', json.encode(res['usuario']));
      }
      return res;

    } catch (e) {
      // MODO OFFLINE: Buscamos en la caché si el correo existe
      String? userJson = prefs.getString('perfil_offline_$correo');
      if (userJson != null) {
        return {"success": true, "usuario": json.decode(userJson)};
      }
      return {"success": false, "message": "Sin internet y el usuario no está en el celular."};
    }
  }

  static Future<Map<String, dynamic>> registrarUsuario(String correo, String rol, String grupo, String nombre) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "registrarUsuario", "correo": correo, "rol": rol, "grupo": grupo, "nombre": nombre
      }).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      final body = await _obtenerBodyReal(r);
      return json.decode(body);
    } catch (e) {
      print("Error en registrarUsuario: $e");
      return {"success": false, "message": "Error de conexión"};
    }
  }

  static Future<bool> crearGrupo(String nombre) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {"action": "crearGrupo", "nombreGrupo": nombre}).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      return r.statusCode == 200 || r.statusCode == 302;
    } catch(e) { return false; }
  }

  static Future<bool> eliminarGrupo(String nombre) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "eliminarGrupo", "nombreGrupo": nombre
      }).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      return r.statusCode == 200 || r.statusCode == 302;
    } catch(e) { return false; }
  }

  // ==========================================
  // MÉTODOS DE PREGUNTAS Y RESULTADOS (CON CACHÉ Y COLA)
  // ==========================================

  static Future<List<dynamic>> obtenerPreguntas(String cat) async {
    final prefs = await SharedPreferences.getInstance();

    // 🔥 CORRECCIÓN: Evita el error al cargar "Todas las preguntas" en el panel Admin
    final cacheKey = cat.isEmpty ? 'cache_preguntas_todas' : 'cache_preguntas_$cat';

    try {
      final r = await http.get(Uri.parse("$_url?action=obtenerPreguntas&categoria=$cat")).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      final body = await _obtenerBodyReal(r);
      await prefs.setString(cacheKey, body); // Guardar copia

      List<dynamic> data = json.decode(body);
      return data.map((p) => {
        ...p,
        "respuesta": p['respuesta'].toString(),
        "opciones": (p['opciones'] as List).map((o) => o.toString()).toList()
      }).toList();
    } catch (e) {
      // MODO OFFLINE: Rescatar preguntas del teléfono
      String? cache = prefs.getString(cacheKey);
      if (cache != null) {
        List<dynamic> data = json.decode(cache);
        return data.map((p) => {
          ...p,
          "respuesta": p['respuesta'].toString(),
          "opciones": (p['opciones'] as List).map((o) => o.toString()).toList()
        }).toList();
      }
      return [];
    }
  }

  static Future<bool> guardarResultado(String correo, String grupo, String tipo, int pts) async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> payload = {
      "correo": correo,
      "grupo": grupo,
      "tipoPrueba": tipo,
      "puntaje": pts.toString()
    };

    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "guardarResultado", ...payload, "respuestas": "{}"
      }).timeout(const Duration(seconds: 10)); // 🔥 El post en segundo plano está bien en 10s

      if (r.statusCode == 200 || r.statusCode == 302) {
        sincronizarColaResultados(); // Si subió bien este, intenta subir atrasados
        return true;
      }
      throw Exception("Fallo en servidor");
    } catch (e) {
      // 🔥 MODO OFFLINE: Guardar en la bóveda local (Cola)
      List<String> cola = prefs.getStringList('cola_resultados') ?? [];
      cola.add(json.encode(payload));
      await prefs.setStringList('cola_resultados', cola);
      print("Guardado en modo Offline. Se subirá luego.");
      return true; // Retornamos true para no asustar al usuario, su nota ESTÁ a salvo localmente.
    }
  }

  static Future<List<dynamic>> obtenerResultados() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final r = await http.get(Uri.parse("$_url?action=obtenerResultados")).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      final body = await _obtenerBodyReal(r);
      await prefs.setString('cache_resultados', body); // Guardar copia
      return json.decode(body);
    } catch (e) {
      // MODO OFFLINE
      String? cache = prefs.getString('cache_resultados');
      return cache != null ? json.decode(cache) : [];
    }
  }

  // ==========================================
  // MÉTODOS DE ADMINISTRADOR DE PREGUNTAS (Requieren Internet)
  // ==========================================

  static Future<bool> guardarPregunta(Map<String, dynamic> p) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "guardarPregunta",
        "categoria": p['categoria'],
        "pregunta": p['pregunta'],
        "opciones": json.encode(p['opciones']),
        "respuesta": p['respuesta'],
        "retroalimentacion": p['retro'],
        "imagenesURLs": p['img'] ?? ""
      }).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      return r.statusCode == 200 || r.statusCode == 302;
    } catch(e) { return false; }
  }

  static Future<bool> guardarGrupoPreguntas(String cat, String tipo, dynamic preguntas) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "guardarGrupoPreguntas", "categoria": cat, "tipoGrupo": tipo, "preguntas": json.encode(preguntas)
      }).timeout(const Duration(seconds: 20)); // 🔥 Aumentado a 20s (porque manda mucho texto a la vez)
      return r.statusCode == 200 || r.statusCode == 302;
    } catch(e) { return false; }
  }

  static Future<bool> editarPregunta(Map<String, dynamic> p) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "editarPregunta", "idPregunta": p['idPregunta'], "pregunta": p['pregunta'], "opciones": json.encode(p['opciones']), "respuesta": p['respuesta'], "retro": p['retro']
      }).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      return r.statusCode == 200 || r.statusCode == 302;
    } catch(e) { return false; }
  }

  static Future<bool> eliminarBloque(String bloqueId) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "eliminarBloque", "bloqueId": bloqueId.toString()
      }).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      return r.statusCode == 200 || r.statusCode == 302;
    } catch(e) { return false; }
  }

  static Future<bool> eliminarPregunta(String idPregunta) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "eliminarPregunta", "idPregunta": idPregunta.toString()
      }).timeout(const Duration(seconds: 15)); // 🔥 Aumentado a 15s
      return r.statusCode == 200 || r.statusCode == 302;
    } catch(e) { return false; }
  }

  static Future<String?> subirImagenDrive(String base64, String name) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "subirImagen", "base64": base64, "mimeType": "image/jpeg", "name": name
      }).timeout(const Duration(seconds: 30)); // 🔥 Aumentado a 30s (Subir imágenes requiere mucho más tiempo)
      final body = await _obtenerBodyReal(r);
      return json.decode(body)['url'];
    } catch (e) {
      print("Error en subirImagenDrive: $e");
      return null;
    }
  }
}