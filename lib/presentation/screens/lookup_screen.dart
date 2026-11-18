import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../application/app_controller.dart';
import '../../domain/product.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

class LookupScreen extends StatefulWidget {
  const LookupScreen({super.key, required this.barcode});
  final String barcode;
  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  Future<Product?>? _lookup;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lookup ??= _find();
  }

  Future<Product?> _find() async {
    final app = AppScope.of(context);
    final saved = app.entryFor(widget.barcode);
    return saved?.product ?? await app.products.findByBarcode(widget.barcode);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Product?>(
    future: _lookup,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          snapshot.data != null) {
        return DetailScreen(arguments: ProductDetailArguments(snapshot.data!));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Consultar código')),
        body: snapshot.connectionState != ConnectionState.done
            ? const Center(child: CupertinoActivityIndicator())
            : EmptyState(
                icon: snapshot.hasError
                    ? CupertinoIcons.wifi_exclamationmark
                    : CupertinoIcons.barcode,
                title: snapshot.hasError
                    ? 'No se pudo consultar'
                    : 'Este producto aún no está registrado',
                description: snapshot.hasError
                    ? snapshot.error.toString()
                    : 'Código ${widget.barcode}. Puedes aportar su foto e ingredientes para comenzar su ficha.',
                action: snapshot.hasError
                    ? FilledButton(
                        onPressed: () => setState(() => _lookup = _find()),
                        child: const Text('Reintentar'),
                      )
                    : FilledButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.create,
                          arguments: widget.barcode,
                        ),
                        icon: const Icon(CupertinoIcons.add),
                        label: const Text('Registrar producto'),
                      ),
              ),
      );
    },
  );
}
