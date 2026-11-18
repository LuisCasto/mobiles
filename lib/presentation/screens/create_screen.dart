import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../application/app_controller.dart';
import '../../domain/product.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'photo_screen.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.barcode});
  final String? barcode;
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _form = GlobalKey<FormState>();
  late final _barcode = TextEditingController(text: widget.barcode);
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _quantity = TextEditingController();
  final _ingredients = TextEditingController();
  final _notes = TextEditingController();
  final _sugars = TextEditingController();
  final _salt = TextEditingController();
  String _photo = '';
  bool _saving = false;
  bool _picking = false;
  bool _share = false;

  @override
  void dispose() {
    for (final controller in [
      _barcode,
      _name,
      _brand,
      _quantity,
      _ingredients,
      _notes,
      _sugars,
      _salt,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _photoFrom({required bool camera}) async {
    setState(() => _picking = true);
    try {
      final XFile? file = camera
          ? await Navigator.of(context).push<XFile>(
              MaterialPageRoute(builder: (_) => const PhotoScreen()),
            )
          : await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1200,
              maxHeight: 1200,
              imageQuality: 70,
            );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 1024 * 1024) {
        showMessage(
          context,
          'Elige una imagen de menos de 1 MB para guardarla en tu bitácora local.',
        );
        return;
      }
      if (bytes.isEmpty) throw StateError('empty image');
      setState(() => _photo = base64Encode(bytes));
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'No se pudo cargar la imagen. Comprueba los permisos o selecciona otra fotografía.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    final app = AppScope.of(context);
    if (app.entryFor(_barcode.text.trim()) != null) {
      showMessage(
        context,
        'Este código ya está en tu bitácora. Puedes editar sus notas desde el detalle.',
      );
      return;
    }
    setState(() => _saving = true);
    final nutrients = <String, double>{};
    for (final pair in {'sugars_100g': _sugars, 'salt_100g': _salt}.entries) {
      final value = double.tryParse(pair.value.text.replaceAll(',', '.'));
      if (value != null) nutrients[pair.key] = value;
    }
    final product = Product(
      barcode: _barcode.text.trim(),
      name: _name.text.trim(),
      brand: _brand.text.trim(),
      quantity: _quantity.text.trim(),
      ingredients: _ingredients.text.trim(),
      photoBase64: _photo,
      nutrients: nutrients,
      source: ProductSource.contribution,
    );
    try {
      await app.saveProduct(
        product,
        note: _notes.text,
        shared: app.canSync && _share,
      );
      if (!mounted) return;
      showMessage(
        context,
        app.canSync && _share
            ? 'Entrada guardada. Sincroniza tu cuenta para publicarla en la comunidad.'
            : 'Tu aportación quedó guardada en este dispositivo.',
      );
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.detail,
        arguments: ProductDetailArguments(product),
      );
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString());
        setState(() => _saving = false);
      }
    }
  }

  String? _nutrientValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final n = double.tryParse(value.replaceAll(',', '.'));
    return n == null || !n.isFinite || n < 0 || n > 100
        ? 'Usa un número entre 0 y 100.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva aportación')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 50),
              children: [
                const Text(
                  'Lo que sabes,\nnos ayuda a elegir.',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Registra un producto y la información de su etiqueta. Tu entrada se conserva en la bitácora.',
                  style: TextStyle(
                    color: AppColors.secondary(context),
                    height: 1.6,
                  ),
                ),
                const SectionLabel('Una imagen dice mucho'),
                ContentCard(
                  child: Column(
                    children: [
                      if (_photo.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            base64Decode(_photo),
                            height: 190,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Text('No se puede mostrar esta imagen.'),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _photo = ''),
                          icon: const Icon(CupertinoIcons.trash, size: 16),
                          label: const Text('Quitar foto'),
                        ),
                      ] else ...[
                        Icon(
                          CupertinoIcons.camera_on_rectangle,
                          size: 42,
                          color: AppColors.secondary(context),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Fotografía el producto o sus ingredientes',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'La foto se guarda con tu entrada, también en la web.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary(context),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _picking
                                ? null
                                : () => _photoFrom(camera: true),
                            icon: const Icon(CupertinoIcons.camera, size: 19),
                            label: const Text('Usar cámara'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _picking
                                ? null
                                : () => _photoFrom(camera: false),
                            icon: const Icon(CupertinoIcons.photo, size: 19),
                            label: const Text('Abrir galería'),
                          ),
                        ],
                      ),
                      if (_picking)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: CupertinoActivityIndicator(),
                        ),
                    ],
                  ),
                ),
                const SectionLabel('La información esencial'),
                ContentCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _barcode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(14),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Código de barras *',
                          hintText: '8 a 14 dígitos',
                          suffixIcon: IconButton(
                            onPressed: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                AppRoutes.scanner,
                              );
                              if (result is String && mounted) {
                                _barcode.text = result;
                              }
                            },
                            tooltip: 'Escanear código',
                            icon: const Icon(CupertinoIcons.barcode_viewfinder),
                          ),
                        ),
                        validator: (value) =>
                            RegExp(r'^\d{8,14}$').hasMatch(value ?? '')
                            ? null
                            : 'Ingresa un código de 8 a 14 dígitos.',
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _name,
                        maxLength: 150,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del producto *',
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 2
                            ? 'Escribe el nombre del producto.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _brand,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: 'Marca'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantity,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          labelText: 'Contenido',
                          hintText: 'Ej. 500 g o 1 L',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ingredients,
                        minLines: 3,
                        maxLines: 7,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          labelText: 'Ingredientes *',
                          hintText:
                              'Transcribe los ingredientes como aparecen en la etiqueta.',
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 3
                            ? 'Añade los ingredientes que indica la etiqueta.'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Datos de la etiqueta · opcional'),
                ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Por 100 g o 100 ml, según el envase.',
                        style: TextStyle(
                          color: AppColors.secondary(context),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sugars,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Azúcares (g)',
                              ),
                              validator: _nutrientValidator,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _salt,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Sal (g)',
                              ),
                              validator: _nutrientValidator,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'El Nutri-Score y NOVA solo se muestran cuando Open Food Facts los proporciona; no se asignan manualmente.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary(context),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Tu observación'),
                ContentCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText:
                              '¿Qué te gustaría recordar de este producto?',
                        ),
                      ),
                      if (app.canSync)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Compartir con la comunidad',
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Se publicará al sincronizar. No se envían tus notas personales.',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: _share,
                          onChanged: (value) => setState(() => _share = value),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: Icon(
                    _saving
                        ? CupertinoIcons.hourglass
                        : CupertinoIcons.checkmark_circle,
                    size: 20,
                  ),
                  label: Text(_saving ? 'Guardando…' : 'Guardar aportación'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
