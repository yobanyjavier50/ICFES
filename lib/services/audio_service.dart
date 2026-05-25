import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioPlayer _uiPlayer = AudioPlayer();
  static final AudioPlayer _resultPlayer = AudioPlayer();

  // 🔥 NUEVA FUNCIÓN: Fuerza la carga del archivo en la memoria caché
  static Future<void> inicializar() async {
    await _uiPlayer.setPlayerMode(PlayerMode.lowLatency);
    await _uiPlayer.setSource(AssetSource('sounds/click.mp3'));
  }

  static Future<void> playClick() async {
    await _uiPlayer.stop(); // Detiene cualquier reproducción previa para reiniciar el click al instante
    await _uiPlayer.play(AssetSource('sounds/click.mp3'));
  }

  static Future<void> playSuccess() async {
    await _resultPlayer.stop();
    await _resultPlayer.play(AssetSource('sounds/success.mp3'));
  }

  static Future<void> playFail() async {
    await _resultPlayer.stop();
    await _resultPlayer.play(AssetSource('sounds/fail.mp3'));
  }
}