import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleSheetsService {
  // ⚠️ TU URL ORIGINAL INTACTA
  static const String _url =
      "https://script.google.com/macros/s/AKfycbxhA73eQAnlgTS0E2E6Zvx4iqEEynWiPAK3OJgJH_MpwJCTj3WbLljsJxXhD7MuPl19/exec";
  // --- ESCUDO CONTRA REDIRECCIONES HTML Y ERRORES DE FORMATO ---
  static Future<String> _obtenerBodyReal(http.Response r) async {
    if ((r.statusCode == 302 || r.statusCode == 200) &&
        r.body.contains("Moved Temporarily")) {
      final regex = RegExp(r'HREF="([^"]+)"', caseSensitive: false);
      final match = regex.firstMatch(r.body);

      if (match != null && match.groupCount >= 1) {
        final cleanUrl = match.group(1)!.replaceAll("&amp;", "&");

        final res = await http
            .get(Uri.parse(cleanUrl))
            .timeout(const Duration(seconds: 15));

        return res.body;
      }
    }

    return r.body;
  }

  // ============================================================
  // SINCRONIZACIÓN OFFLINE -> ONLINE
  // ============================================================

  // 🔥 RESULTADOS OFFLINE -> ONLINE
  static Future<void> sincronizarColaResultados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cola = prefs.getStringList('cola_resultados') ?? [];

      // Aunque no haya resultados pendientes, intentamos sincronizar estados de examen.
      if (cola.isEmpty) {
        await sincronizarColaEstadosExamen();
        return;
      }

      String payloadBatch = "[${cola.join(',')}]";

      final r = await http.post(Uri.parse(_url), body: {
        "action": "sincronizarCola",
        "resultados": payloadBatch,
      }).timeout(const Duration(seconds: 15));

      if (r.statusCode == 200 || r.statusCode == 302) {
        final body = await _obtenerBodyReal(r);

        try {
          final data = jsonDecode(body);

          if (data['success'] == true) {
            await prefs.remove('cola_resultados');
            print("Sincronización exitosa: ${cola.length} exámenes subidos.");

            await sincronizarColaEstadosExamen();
          }
        } catch (_) {
          // Si el servidor respondió bien pero no se pudo leer JSON,
          // mantenemos compatibilidad con tu comportamiento anterior.
          await prefs.remove('cola_resultados');
          print("Sincronización exitosa: ${cola.length} exámenes subidos.");

          await sincronizarColaEstadosExamen();
        }
      }
    } catch (e) {
      print("Aún sin internet. La sincronización se hará luego.");
    }
  }

  // 🔥 ESTADOS DE EXAMEN OFFLINE -> ONLINE
  static Future<void> sincronizarColaEstadosExamen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cola = prefs.getStringList('cola_estados_examen') ?? [];

      if (cola.isEmpty) return;

      List<String> pendientes = [];

      for (String item in cola) {
        try {
          final data = json.decode(item);

          final response = await http.post(
            Uri.parse(_url),
            body: {
              "action": "cambiarEstadoExamen",
              "correo": data["correo"].toString(),
              "estado": data["estado"].toString(),
            },
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200 || response.statusCode == 302) {
            final body = await _obtenerBodyReal(response);
            final res = jsonDecode(body);

            if (res['success'] != true) {
              pendientes.add(item);
            }
          } else {
            pendientes.add(item);
          }
        } catch (e) {
          pendientes.add(item);
        }
      }

      if (pendientes.isEmpty) {
        await prefs.remove('cola_estados_examen');
        print("Estados de examen sincronizados correctamente.");
      } else {
        await prefs.setStringList('cola_estados_examen', pendientes);
        print("Quedan ${pendientes.length} estados de examen pendientes.");
      }
    } catch (e) {
      print("No se pudo sincronizar la cola de estados de examen: $e");
    }
  }

  // ==========================================
  // MÉTODOS DE USUARIOS Y GRUPOS
  // ==========================================

  static Future<List<String>> obtenerGrupos() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final r = await http
          .get(Uri.parse("$_url?action=obtenerGrupos"))
          .timeout(const Duration(seconds: 15));

      final body = await _obtenerBodyReal(r);

      await prefs.setString('cache_grupos', body);

      List<dynamic> data = json.decode(body);
      return data.map((g) => g.toString()).toList();
    } catch (e) {
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
      final r = await http
          .get(Uri.parse("$_url?action=obtenerUsuarios"))
          .timeout(const Duration(seconds: 15));

      final body = await _obtenerBodyReal(r);

      await prefs.setString('cache_usuarios', body);

      return json.decode(body);
    } catch (e) {
      String? cache = prefs.getString('cache_usuarios');
      return cache != null ? json.decode(cache) : [];
    }
  }

  static Future<Map<String, dynamic>> verificarUsuario(String correo) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final r = await http
          .get(Uri.parse("$_url?action=verificarUsuario&correo=$correo"))
          .timeout(const Duration(seconds: 15));

      final body = await _obtenerBodyReal(r);

      // Si hay internet, intentamos sincronizar pendientes.
      sincronizarColaResultados();

      final res = json.decode(body);

      if (res['success'] == true) {
        await prefs.setString(
          'perfil_offline_$correo',
          json.encode(res['usuario']),
        );
      }

      return res;
    } catch (e) {
      // MODO OFFLINE: permite entrar si ya hizo login con internet antes.
      String? userJson = prefs.getString('perfil_offline_$correo');

      if (userJson != null) {
        return {
          "success": true,
          "usuario": json.decode(userJson),
          "offline": true,
        };
      }

      return {
        "success": false,
        "message": "Sin internet y el usuario no está en el celular.",
      };
    }
  }

  static Future<Map<String, dynamic>> registrarUsuario(
      String correo,
      String rol,
      String grupo,
      String nombre,
      ) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "registrarUsuario",
        "correo": correo,
        "rol": rol,
        "grupo": grupo,
        "nombre": nombre,
      }).timeout(const Duration(seconds: 15));

      final body = await _obtenerBodyReal(r);

      return json.decode(body);
    } catch (e) {
      print("Error en registrarUsuario: $e");

      return {
        "success": false,
        "message": "Error de conexión",
      };
    }
  }

  static Future<bool> crearGrupo(String nombre) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "crearGrupo",
        "nombreGrupo": nombre,
      }).timeout(const Duration(seconds: 15));

      return r.statusCode == 200 || r.statusCode == 302;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> eliminarGrupo(String nombre) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "eliminarGrupo",
        "nombreGrupo": nombre,
      }).timeout(const Duration(seconds: 15));

      return r.statusCode == 200 || r.statusCode == 302;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> eliminarUsuario(String correo) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        body: {
          "action": "eliminarUsuario",
          "correo": correo,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final body = await _obtenerBodyReal(response);
        final data = jsonDecode(body);

        return data['success'] == true;
      }
    } catch (e) {
      print("Error al eliminar usuario: $e");
    }

    return false;
  }

  // ==========================================
  // MÉTODOS DE PREGUNTAS Y RESULTADOS
  // ==========================================

  static Future<List<dynamic>> obtenerPreguntas(String cat) async {
    final prefs = await SharedPreferences.getInstance();

    final cacheKey =
    cat.isEmpty ? 'cache_preguntas_todas' : 'cache_preguntas_$cat';

    try {
      final r = await http
          .get(Uri.parse("$_url?action=obtenerPreguntas&categoria=$cat"))
          .timeout(const Duration(seconds: 15));

      final body = await _obtenerBodyReal(r);

      await prefs.setString(cacheKey, body);

      List<dynamic> data = json.decode(body);

      return data.map((p) {
        return {
          ...p,
          "respuesta": p['respuesta'].toString(),
          "opciones": (p['opciones'] as List).map((o) => o.toString()).toList(),
        };
      }).toList();
    } catch (e) {
      String? cache = prefs.getString(cacheKey);

      if (cache != null) {
        List<dynamic> data = json.decode(cache);

        return data.map((p) {
          return {
            ...p,
            "respuesta": p['respuesta'].toString(),
            "opciones":
            (p['opciones'] as List).map((o) => o.toString()).toList(),
          };
        }).toList();
      }

      return [];
    }
  }

  static Future<bool> guardarResultado(
      String correo,
      String grupo,
      String tipo,
      int pts,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> payload = {
      "correo": correo,
      "grupo": grupo,
      "tipoPrueba": tipo,
      "puntaje": pts.toString(),
    };

    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "guardarResultado",
        ...payload,
        "respuestas": "{}",
      }).timeout(const Duration(seconds: 10));

      if (r.statusCode == 200 || r.statusCode == 302) {
        sincronizarColaResultados();
        return true;
      }

      throw Exception("Fallo en servidor");
    } catch (e) {
      // MODO OFFLINE: guarda resultado local para sincronizar después.
      List<String> cola = prefs.getStringList('cola_resultados') ?? [];

      cola.add(json.encode(payload));

      await prefs.setStringList('cola_resultados', cola);

      print("Resultado guardado en modo offline. Se subirá luego.");

      return true;
    }
  }

  static Future<List<dynamic>> obtenerResultados() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final r = await http
          .get(Uri.parse("$_url?action=obtenerResultados"))
          .timeout(const Duration(seconds: 15));

      final body = await _obtenerBodyReal(r);

      await prefs.setString('cache_resultados', body);

      return json.decode(body);
    } catch (e) {
      String? cache = prefs.getString('cache_resultados');
      return cache != null ? json.decode(cache) : [];
    }
  }

  // ==========================================
  // MÉTODOS DE ADMINISTRADOR DE PREGUNTAS
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
        "imagenesURLs": p['img'] ?? "",
      }).timeout(const Duration(seconds: 15));

      return r.statusCode == 200 || r.statusCode == 302;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> guardarGrupoPreguntas(
      String cat,
      String tipo,
      dynamic preguntas,
      ) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "guardarGrupoPreguntas",
        "categoria": cat,
        "tipoGrupo": tipo,
        "preguntas": json.encode(preguntas),
      }).timeout(const Duration(seconds: 20));

      return r.statusCode == 200 || r.statusCode == 302;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> editarPregunta(Map<String, dynamic> p) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "editarPregunta",
        "idPregunta": p['idPregunta'],
        "pregunta": p['pregunta'],
        "opciones": json.encode(p['opciones']),
        "respuesta": p['respuesta'],
        "retro": p['retro'],
      }).timeout(const Duration(seconds: 15));

      return r.statusCode == 200 || r.statusCode == 302;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> eliminarBloque(String bloqueId) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "eliminarBloque",
        "bloqueId": bloqueId.toString(),
      }).timeout(const Duration(seconds: 15));

      return r.statusCode == 200 || r.statusCode == 302;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> eliminarPregunta(String idPregunta) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "eliminarPregunta",
        "idPregunta": idPregunta.toString(),
      }).timeout(const Duration(seconds: 15));

      return r.statusCode == 200 || r.statusCode == 302;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> subirImagenDrive(String base64, String name) async {
    try {
      final r = await http.post(Uri.parse(_url), body: {
        "action": "subirImagen",
        "base64": base64,
        "mimeType": "image/jpeg",
        "name": name,
      }).timeout(const Duration(seconds: 30));

      final body = await _obtenerBodyReal(r);

      return json.decode(body)['url'];
    } catch (e) {
      print("Error en subirImagenDrive: $e");
      return null;
    }
  }

  // ==========================================
  // HABILITACIÓN DE EXAMEN REAL CON SOPORTE OFFLINE
  // ==========================================

  static Future<bool> verificarIntentoHabilitado(String correo) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'examen_habilitado_$correo';

    try {
      await sincronizarColaResultados();
      await sincronizarColaEstadosExamen();

      final response = await http
          .get(Uri.parse('$_url?action=verificarIntento&correo=$correo'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final body = await _obtenerBodyReal(response);
        final data = jsonDecode(body);

        final habilitado = data['habilitado'] == true;

        await prefs.setBool(cacheKey, habilitado);

        return habilitado;
      }
    } catch (e) {
      print("Sin internet al verificar intento. Usando caché local: $e");
    }

    // Si no hay internet, usa el último estado guardado localmente.
    return prefs.getBool(cacheKey) ?? false;
  }

  static Future<bool> cambiarEstadoExamen(String correo, bool estado) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'examen_habilitado_$correo';

    // Primero actualiza localmente.
    // Si estado = false, evita repetir el examen aunque esté offline.
    await prefs.setBool(cacheKey, estado);

    try {
      final response = await http.post(
        Uri.parse(_url),
        body: {
          "action": "cambiarEstadoExamen",
          "correo": correo,
          "estado": estado.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final body = await _obtenerBodyReal(response);
        final data = jsonDecode(body);

        if (data['success'] == true) {
          await sincronizarColaEstadosExamen();
          return true;
        }
      }

      throw Exception("No se pudo actualizar el estado del examen en servidor");
    } catch (e) {
      print("Estado de examen guardado localmente para sincronizar después: $e");

      List<String> cola = prefs.getStringList('cola_estados_examen') ?? [];

      cola.add(json.encode({
        "correo": correo,
        "estado": estado,
      }));

      await prefs.setStringList('cola_estados_examen', cola);

      return true;
    }
  }

  static Future<bool> cambiarEstadoGlobal(String grupo, bool estado) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        body: {
          "action": "cambiarEstadoGlobal",
          "grupo": grupo,
          "estado": estado.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final body = await _obtenerBodyReal(response);
        final data = jsonDecode(body);

        return data['success'] == true;
      }
    } catch (e) {
      print("Error al cambiar estado masivo: $e");
    }

    return false;
  }
}