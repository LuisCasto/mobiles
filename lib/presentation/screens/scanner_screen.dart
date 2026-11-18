import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme.dart';

/// Returns a barcode; the caller performs the lookup after camera disposal.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.itf14,
    ],
  );
  final _manual = TextEditingController();
  bool _returned = false;
  String? _validation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed && !_returned) {
      unawaited(_controller.start().catchError((Object _) {}));
    } else if (state != AppLifecycleState.resumed) {
      unawaited(_controller.stop().catchError((Object _) {}));
    }
  }

  void _finish(String code) {
    if (_returned || !mounted) return;
    if (!RegExp(r'^\d{8,14}$').hasMatch(code)) {
      setState(
        () => _validation = 'El código debe tener entre 8 y 14 dígitos.',
      );
      return;
    }
    _returned = true;
    Navigator.pop(context, code);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear producto')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Acerca la cámara\na su código de barras.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Busca buena luz y mantén el código dentro del encuadre.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondary(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final code = barcode.rawValue;
                          if (code != null &&
                              RegExp(r'^\d{8,14}$').hasMatch(code)) {
                            _finish(code);
                            break;
                          }
                        }
                      },
                      errorBuilder: (context, error) => Container(
                        color: const Color(0xFF23232B),
                        padding: const EdgeInsets.all(28),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.camera,
                              size: 40,
                              color: Colors.white70,
                            ),
                            SizedBox(height: 18),
                            Text(
                              'No se pudo abrir la cámara.\nPermite su uso en el navegador o escribe el código abajo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        width: 260,
                        height: 160,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white70, width: 2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'También puedes escribirlo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manual,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: _finish,
              decoration: InputDecoration(
                hintText: 'Código EAN / UPC',
                prefixIcon: const Icon(CupertinoIcons.barcode),
                errorText: _validation,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _finish(_manual.text.trim()),
              child: const Text('Consultar producto'),
            ),
          ],
        ),
      ),
    ),
  );
}
