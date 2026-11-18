import 'package:speech_to_text/speech_to_text.dart';

/// One recognizer for the application; callbacks always target the active view.
class DictationService {
  DictationService._();
  static final instance = DictationService._();
  final SpeechToText _speech = SpeechToText();
  void Function(String words, bool finalResult)? _onWords;
  void Function(bool listening)? _onStatus;
  void Function(String message)? _onError;
  bool _initialized = false;

  Future<void> start({
    required void Function(String, bool) onWords,
    required void Function(bool) onStatus,
    required void Function(String) onError,
  }) async {
    _onWords = onWords;
    _onStatus = onStatus;
    _onError = onError;
    try {
      if (!_initialized) {
        _initialized = await _speech.initialize(
          onStatus: (status) => _onStatus?.call(status == 'listening'),
          onError: (_) {
            _onStatus?.call(false);
            _onError?.call(
              'No se pudo reconocer tu voz. Comprueba el permiso del micrófono o escribe tu búsqueda.',
            );
          },
        );
      }
      if (!_initialized) {
        onError(
          'El dictado no está disponible o no tiene permiso. Prueba Chrome o Edge con acceso al micrófono.',
        );
        return;
      }
      final locales = await _speech.locales();
      final spanish = locales
          .where((l) => l.localeId.toLowerCase().startsWith('es'))
          .toList();
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: spanish.isEmpty ? null : spanish.first.localeId,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.search,
        ),
        onResult: (result) =>
            _onWords?.call(result.recognizedWords, result.finalResult),
      );
      _onStatus?.call(_speech.isListening);
    } catch (_) {
      _onStatus?.call(false);
      _onError?.call(
        'No se pudo iniciar el micrófono. Revisa los permisos del navegador.',
      );
    }
  }

  Future<void> stop() async {
    await _speech.stop();
    _onStatus?.call(false);
  }

  Future<void> cancel() async {
    _onWords = null;
    _onStatus = null;
    _onError = null;
    await _speech.cancel();
  }
}
