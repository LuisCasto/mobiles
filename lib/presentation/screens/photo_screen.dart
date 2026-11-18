import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/common.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});
  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  late Future<void> _ready;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ready = _initialize();
  }

  Future<void> _initialize() async {
    final cameras = await availableCameras();
    if (!mounted) return;
    if (cameras.isEmpty) throw StateError('No se encontró una cámara.');
    final back = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    final controller = CameraController(
      back.isEmpty ? cameras.first : back.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _camera = controller;
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A permission dialog can make the app inactive before initialization.
    if (_camera != null && !_camera!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      final camera = _camera;
      _camera = null;
      camera?.dispose();
    } else if (state == AppLifecycleState.resumed &&
        mounted &&
        _camera == null) {
      setState(() => _ready = _initialize());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    if (_taking) return;
    setState(() => _taking = true);
    try {
      final image = await _camera!.takePicture();
      if (mounted) Navigator.pop(context, image);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'No se pudo tomar la foto. Intenta otra vez o usa la galería.',
        );
        setState(() => _taking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fotografiar producto')),
    body: FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            icon: CupertinoIcons.camera,
            title: 'La cámara no está disponible',
            description:
                'Permite el acceso a la cámara y vuelve a abrir esta pantalla. También puedes seleccionar una imagen de la galería.',
          );
        }
        if (snapshot.connectionState != ConnectionState.done ||
            _camera == null) {
          return const Center(child: CupertinoActivityIndicator());
        }
        return Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _camera!.value.aspectRatio,
                  child: CameraPreview(_camera!),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton.icon(
                onPressed: _taking ? null : _take,
                icon: const Icon(CupertinoIcons.camera_fill),
                label: Text(_taking ? 'Capturando…' : 'Tomar fotografía'),
              ),
            ),
          ],
        );
      },
    ),
  );
}
