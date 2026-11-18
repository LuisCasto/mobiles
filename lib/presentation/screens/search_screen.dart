import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../application/app_controller.dart';
import '../../application/device_services.dart';
import '../../domain/product.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/product_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  List<Product> _results = [];
  bool _loading = false;
  bool _searched = false;
  bool _listening = false;
  String? _error;
  String _submitted = '';
  int _request = 0;
  int _page = 1;
  bool _hasMore = false;

  @override
  void dispose() {
    unawaited(DictationService.instance.cancel());
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search({bool more = false}) async {
    final text = (more ? _submitted : _query.text).trim();
    if (text.length < 2) {
      showMessage(context, 'Escribe al menos dos caracteres.');
      return;
    }
    _focus.unfocus();
    if (_listening) await DictationService.instance.stop();
    if (!mounted) return;
    final app = AppScope.of(context);
    final request = ++_request;
    final page = more ? _page + 1 : 1;
    final isBarcode = RegExp(r'^\d{8,14}$').hasMatch(text);
    final local = app.entries
        .map((e) => e.product)
        .where(
          (p) => '${p.name} ${p.brand} ${p.barcode}'.toLowerCase().contains(
            text.toLowerCase(),
          ),
        )
        .toList();
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _submitted = text;
      if (!more) {
        _results = local;
        _hasMore = false;
      }
    });
    try {
      List<Product> remote;
      if (isBarcode) {
        final product = await app.products.findByBarcode(text);
        remote = product == null ? [] : [product];
      } else {
        remote = await app.products.search(text, page: page);
      }
      if (!mounted || request != _request) return;
      // Local and OFF data remain usable if the optional community is offline.
      List<Product> community = [];
      if (app.cloud != null && !isBarcode && !more) {
        try {
          community = await app.cloud!.search(text);
        } catch (_) {
          if (mounted && request == _request) {
            _error =
                'La comunidad no está disponible. Se muestran Open Food Facts y tu bitácora.';
          }
        }
      }
      if (!mounted || request != _request) return;
      final unique = {
        for (final p in more ? _results : <Product>[]) p.barcode: p,
      };
      for (final product in [...remote, ...community, ...local]) {
        unique[product.barcode] = product;
      }
      setState(() {
        _results = unique.values.toList();
        _page = page;
        _hasMore = !isBarcode && remote.length == 20;
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e.toString());
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _dictate() async {
    if (_listening) {
      await DictationService.instance.stop();
      return;
    }
    _focus.unfocus();
    await DictationService.instance.start(
      onWords: (words, finalResult) {
        if (!mounted) return;
        _query.value = TextEditingValue(
          text: words,
          selection: TextSelection.collapsed(offset: words.length),
        );
        // The user submits explicitly: no per-word calls to the rate-limited API.
      },
      onStatus: (value) {
        if (mounted) setState(() => _listening = value);
      },
      onError: (message) {
        if (mounted) showMessage(context, message);
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Buscar productos'),
      actions: [
        IconButton(
          onPressed: () => scanAndOpen(context),
          tooltip: 'Escanear código',
          icon: const Icon(CupertinoIcons.barcode_viewfinder),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 50),
          children: [
            const Text(
              'Encuentra lo que\nvas a llevar a casa.',
              style: TextStyle(
                fontSize: 34,
                letterSpacing: -1.3,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Consulta el catálogo abierto de Open Food Facts o tus propias aportaciones.',
              style: TextStyle(
                color: AppColors.secondary(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _query,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Nombre, marca o código de barras',
                prefixIcon: const Icon(CupertinoIcons.search, size: 21),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_query.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                        tooltip: 'Borrar búsqueda',
                        icon: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 17,
                        ),
                      ),
                    IconButton(
                      onPressed: _dictate,
                      tooltip: _listening
                          ? 'Detener dictado'
                          : 'Buscar con la voz',
                      icon: Icon(
                        _listening
                            ? CupertinoIcons.stop_circle_fill
                            : CupertinoIcons.mic,
                        color: _listening ? AppColors.red : AppColors.blue,
                        size: 23,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_listening)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.waveform,
                      color: AppColors.red,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Escuchando… di el nombre del producto.',
                        style: TextStyle(
                          color: AppColors.secondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'El dictado escribe tu búsqueda. Toca Buscar para consultar.',
                    style: TextStyle(
                      color: AppColors.secondary(context),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : () => _search(),
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.search, size: 17),
                  label: const Text('Buscar'),
                ),
              ],
            ),
            if (!_searched) ...[
              const SectionLabel('¿Por dónde empezamos?'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final term in [
                    'Avena',
                    'Yogur natural',
                    'Pan integral',
                    'Leche',
                    'Chocolate',
                  ])
                    ActionChip(
                      label: Text(term),
                      avatar: const Icon(CupertinoIcons.search, size: 14),
                      onPressed: () {
                        _query.text = term;
                        _search();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const ContentCard(
                child: EmptyState(
                  icon: CupertinoIcons.search,
                  title: 'Una etiqueta, muchas respuestas',
                  description:
                      'Encuentra ingredientes, alérgenos, Nutri-Score y nivel de procesamiento. Puedes escribir, dictar o escanear.',
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.wifi_exclamationmark,
                        color: AppColors.orange,
                      ),
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(height: 1.6)),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _loading ? null : () => _search(),
                        child: const Text('Reintentar consulta'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_searched) ...[
              SectionLabel(
                _loading
                    ? 'Consultando el catálogo…'
                    : '${_results.length} resultados para “$_submitted”',
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_results.isNotEmpty)
                ContentCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (var i = 0; i < _results.length; i++) ...[
                        ProductTile(
                          product: _results[i],
                          heroTag: 'search-${_results[i].barcode}',
                          entry: AppScope.of(
                            context,
                          ).entryFor(_results[i].barcode),
                        ),
                        if (i < _results.length - 1)
                          const Divider(height: 1, indent: 82),
                      ],
                    ],
                  ),
                ),
              if (!_loading && _results.isEmpty && _error == null)
                ContentCard(
                  child: EmptyState(
                    icon: CupertinoIcons.cube_box,
                    title: 'Aún no encontramos ese producto',
                    description:
                        'Prueba con otra marca o con su código de barras. También puedes ser la primera persona en registrarlo.',
                    action: FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.create,
                        arguments: RegExp(r'^\d{8,14}$').hasMatch(_submitted)
                            ? _submitted
                            : null,
                      ),
                      icon: const Icon(CupertinoIcons.add, size: 18),
                      label: const Text('Registrar producto'),
                    ),
                  ),
                ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Center(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _search(more: true),
                      child: const Text('Cargar más productos'),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 30),
            Text(
              'Catálogo: Open Food Facts · Datos ODbL · Imágenes CC BY-SA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.secondary(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
