import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../application/app_controller.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/product_tile.dart';
import '../widgets/scan_landing.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showScanner = true;
  CollectionKind? _selected;
  Future<void>? _loading;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_showScanner) _loading ??= AppScope.of(context).reload();
  }

  String _title(CollectionKind? kind) => switch (kind) {
    null => 'Resumen',
    CollectionKind.all => 'Mis productos',
    CollectionKind.shopping => 'Por comprar',
    CollectionKind.favorites => 'Favoritos',
    CollectionKind.contributions => 'Mis aportaciones',
  };

  Color _color(CollectionKind kind) => switch (kind) {
    CollectionKind.all => AppColors.blue,
    CollectionKind.shopping => AppColors.orange,
    CollectionKind.favorites => AppColors.red,
    CollectionKind.contributions => AppColors.purple,
  };

  IconData _icon(CollectionKind kind) => switch (kind) {
    CollectionKind.all => CupertinoIcons.tray_full_fill,
    CollectionKind.shopping => CupertinoIcons.cart_fill,
    CollectionKind.favorites => CupertinoIcons.heart_fill,
    CollectionKind.contributions => CupertinoIcons.person_2_fill,
  };

  void _select(CollectionKind? kind, {bool closeDrawer = false}) {
    final app = AppScope.of(context);
    setState(() {
      _showScanner = false;
      _selected = kind;
      _loading ??= app.reload();
    });
    if (closeDrawer) Navigator.pop(context);
  }

  void _selectScanner({bool closeDrawer = false}) {
    setState(() {
      _showScanner = true;
      _selected = null;
    });
    if (closeDrawer) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1040;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            Navigator.pushNamed(context, AppRoutes.search),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            Navigator.pushNamed(context, AppRoutes.search),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          drawer: wide
              ? null
              : Drawer(
                  backgroundColor: AppColors.background(context),
                  child: SafeArea(child: _sidebar(app, drawer: true)),
                ),
          appBar: wide
              ? null
              : AppBar(
                  title: const Text(
                    'uBuy',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                      fontSize: 23,
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.account),
                      tooltip: 'Mi cuenta',
                      icon: const Icon(CupertinoIcons.person_crop_circle),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          body: Row(
            children: [
              if (wide) SizedBox(width: 270, child: _sidebar(app)),
              if (wide)
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: .6),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (wide) _desktopBar(app),
                    Expanded(
                      child: _showScanner
                          ? const ScanLanding()
                          : FutureBuilder<void>(
                              future: _loading,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState !=
                                    ConnectionState.done) {
                                  return const Center(
                                    child: CupertinoActivityIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return EmptyState(
                                    icon:
                                        CupertinoIcons.exclamationmark_triangle,
                                    title: 'No pudimos abrir tu bitácora',
                                    description: snapshot.error.toString(),
                                    action: FilledButton(
                                      onPressed: () => setState(
                                        () => _loading = app.reload(),
                                      ),
                                      child: const Text('Reintentar'),
                                    ),
                                  );
                                }
                                return _content(app);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _showScanner ? 0 : 1,
                  onDestinationSelected: (index) =>
                      index == 0 ? _selectScanner() : _select(null),
                  backgroundColor: AppColors.surface(context),
                  indicatorColor: AppColors.blue.withValues(alpha: .12),
                  elevation: 0,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(CupertinoIcons.barcode_viewfinder),
                      label: 'Escanear',
                    ),
                    NavigationDestination(
                      icon: Icon(CupertinoIcons.square_grid_2x2),
                      selectedIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
                      label: 'Resumen',
                    ),
                  ],
                ),
          floatingActionButton: wide || _showScanner
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  onPressed: () => scanAndOpen(context),
                  icon: const Icon(CupertinoIcons.barcode_viewfinder),
                  label: const Text('Escanear'),
                ),
        ),
      ),
    );
  }

  Widget _desktopBar(AppController app) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 36),
    child: Row(
      children: [
        Text(
          'Tu espacio',
          style: TextStyle(color: AppColors.secondary(context), fontSize: 12),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            CupertinoIcons.chevron_right,
            size: 10,
            color: AppColors.secondary(context),
          ),
        ),
        Text(
          _showScanner ? 'Escanear' : _title(_selected),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Icon(CupertinoIcons.checkmark_shield, size: 14, color: AppColors.green),
        const SizedBox(width: 6),
        Text(
          app.auth.isCloud
              ? 'Conexión con la nube'
              : 'Guardado en este dispositivo',
          style: TextStyle(fontSize: 11, color: AppColors.secondary(context)),
        ),
        const SizedBox(width: 22),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.account),
          tooltip: 'Mi cuenta',
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.blue.withValues(alpha: .1),
            child: Text(
              (app.user?.name ?? 'T').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sidebar(AppController app, {bool drawer = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 24, 28),
              child: Row(
                children: [
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Text(
                    'uBuy',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _searchBox(compact: true),
            ),
            const SizedBox(height: 26),
            _navItem(
              'Escanear',
              CupertinoIcons.barcode_viewfinder,
              AppColors.blue,
              _showScanner,
              () => _selectScanner(closeDrawer: drawer),
            ),
            _navItem(
              'Resumen',
              CupertinoIcons.square_grid_2x2_fill,
              AppColors.blue,
              !_showScanner && _selected == null,
              () => _select(null, closeDrawer: drawer),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 30, 16, 12),
              child: Text(
                'MIS LISTAS',
                style: TextStyle(
                  color: AppColors.secondary(context),
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final kind in CollectionKind.values)
              _navItem(
                _title(kind),
                _icon(kind),
                _color(kind),
                !_showScanner && _selected == kind,
                () => _select(kind, closeDrawer: drawer),
                count: app.collection(kind).length,
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextButton.icon(
                onPressed: () {
                  if (drawer) Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.create);
                },
                icon: const Icon(CupertinoIcons.add_circled, size: 20),
                label: const Text(
                  'Nueva aportación',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          CupertinoIcons.leaf_arrow_circlepath,
                          size: 18,
                          color: AppColors.green,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pequeñas decisiones.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Más información para elegir mejor, un producto a la vez.',
                      style: TextStyle(
                        color: AppColors.secondary(context),
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: ListTile(
          dense: true,
          leading: const Icon(CupertinoIcons.person_crop_circle, size: 28),
          title: Text(
            app.user?.name ?? 'Tu espacio personal',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            app.user == null
                ? 'Crea tu cuenta'
                : app.auth.isCloud
                ? 'Cuenta en la nube'
                : 'Cuenta local',
            style: const TextStyle(fontSize: 10),
          ),
          trailing: const Icon(CupertinoIcons.chevron_right, size: 12),
          onTap: () {
            if (drawer) Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.account);
          },
        ),
      ),
    ],
  );

  Widget _navItem(
    String text,
    IconData icon,
    Color color,
    bool selected,
    VoidCallback onTap, {
    int? count,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    child: Material(
      color: selected
          ? AppColors.blue.withValues(alpha: .09)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        minTileHeight: 45,
        leading: Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        title: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: count == null
            ? null
            : Text(
                '$count',
                style: TextStyle(
                  color: AppColors.secondary(context),
                  fontSize: 12,
                ),
              ),
        onTap: onTap,
      ),
    ),
  );

  Widget _searchBox({bool compact = false}) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF303033)
        : const Color(0xFFEAEAED),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.pushNamed(context, AppRoutes.search),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 11 : 16,
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.search,
              size: compact ? 16 : 20,
              color: AppColors.secondary(context),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                compact
                    ? 'Buscar productos'
                    : 'Nombre, marca o código de barras',
                style: TextStyle(
                  color: AppColors.secondary(context),
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.mic,
              size: compact ? 16 : 20,
              color: AppColors.secondary(context),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _content(AppController app) {
    final narrow = MediaQuery.sizeOf(context).width < 650;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        narrow ? 22 : 42,
        narrow ? 20 : 25,
        narrow ? 22 : 42,
        110,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selected == null) ...[
                Text(
                  'TU COMPRA, UN POCO MÁS CONSCIENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.secondary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Lo bueno empieza\npor saber qué compras.',
                  style: TextStyle(
                    fontSize: narrow ? 32 : 40,
                    height: 1.12,
                    letterSpacing: -1.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Escanea, descubre y elige con más información.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondary(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                _summaryGrid(app),
                const SizedBox(height: 26),
                _scanBanner(narrow),
              ] else ...[
                Text(
                  _title(_selected),
                  style: TextStyle(
                    fontSize: narrow ? 32 : 38,
                    fontWeight: FontWeight.w800,
                    color: _color(_selected!),
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${app.collection(_selected!).length} productos en esta lista',
                  style: TextStyle(
                    color: AppColors.secondary(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                _searchBox(),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final aside = _selected == null && constraints.maxWidth > 780;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _entryList(app)),
                      if (aside) ...[
                        const SizedBox(width: 28),
                        SizedBox(width: 260, child: _discoveryCard()),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 25),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryGrid(AppController app) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 600 ? 2 : 4;
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final kind in CollectionKind.values)
            SizedBox(
              width: width,
              child: Material(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => _select(kind),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 33,
                              height: 33,
                              decoration: BoxDecoration(
                                color: _color(kind),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _icon(kind),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${app.collection(kind).length}',
                              style: const TextStyle(
                                fontSize: 29,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _title(kind),
                          style: TextStyle(
                            color: AppColors.secondary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _scanBanner(bool narrow) => Container(
    padding: EdgeInsets.all(narrow ? 22 : 28),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF163154)
          : const Color(0xFFE9F2FF),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'De la etiqueta a una mejor elección.',
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: -.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ingredientes, información nutricional y una lectura\nclara de lo que llevas a casa.',
                style: TextStyle(
                  color: AppColors.secondary(context),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => scanAndOpen(context),
                    icon: const Icon(
                      CupertinoIcons.barcode_viewfinder,
                      size: 19,
                    ),
                    label: const Text('Escanear producto'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.search),
                    icon: const Icon(CupertinoIcons.search, size: 16),
                    label: const Text('Buscar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!narrow)
          Padding(
            padding: const EdgeInsets.only(left: 25, right: 14),
            child: Transform.rotate(
              angle: -.10,
              child: Container(
                width: 110,
                height: 132,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: .09),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.leaf_arrow_circlepath,
                      size: 47,
                      color: AppColors.green,
                    ),
                    SizedBox(height: 14),
                    Icon(
                      CupertinoIcons.barcode,
                      size: 35,
                      color: AppColors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _entryList(AppController app) {
    final entries = app.collection(_selected ?? CollectionKind.all);
    final shown = _selected == null ? entries.take(5).toList() : entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          _selected == null ? 'Tu actividad reciente' : 'Productos',
          trailing: _selected == null
              ? TextButton(
                  onPressed: () => _select(CollectionKind.all),
                  child: const Text(
                    'Ver todos',
                    style: TextStyle(fontSize: 12),
                  ),
                )
              : IconButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.create),
                  tooltip: 'Nueva entrada',
                  icon: const Icon(CupertinoIcons.add_circled),
                ),
        ),
        ContentCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: shown.isEmpty
              ? EmptyState(
                  icon: _selected == null
                      ? CupertinoIcons.tray
                      : _icon(_selected!),
                  title: _selected == CollectionKind.favorites
                      ? 'Tus favoritos, a mano'
                      : _selected == CollectionKind.shopping
                      ? 'Tu próxima compra empieza aquí'
                      : 'Cada producto tiene una historia',
                  description: _selected == CollectionKind.favorites
                      ? 'Abre un producto y toca el corazón para encontrarlo aquí.'
                      : _selected == CollectionKind.contributions
                      ? 'Añade un producto con sus ingredientes y una foto de su etiqueta.'
                      : 'Busca o escanea tu primer producto y guárdalo en tu bitácora.',
                  action: TextButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      _selected == CollectionKind.contributions
                          ? AppRoutes.create
                          : AppRoutes.search,
                    ),
                    icon: Icon(
                      _selected == CollectionKind.contributions
                          ? CupertinoIcons.add
                          : CupertinoIcons.search,
                      size: 17,
                    ),
                    label: Text(
                      _selected == CollectionKind.contributions
                          ? 'Crear aportación'
                          : 'Descubrir un producto',
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      ProductTile(
                        product: shown[i].product,
                        entry: shown[i],
                        heroTag: 'home-${shown[i].id}',
                        onCheck: _selected == CollectionKind.shopping
                            ? () => runAction(
                                context,
                                () => app.updateEntry(
                                  shown[i].copyWith(
                                    purchased: !shown[i].purchased,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if (i < shown.length - 1)
                        const Divider(height: 1, indent: 82),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _discoveryCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Un poco más de contexto'),
      ContentCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.lightbulb,
                color: AppColors.green,
                size: 23,
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              'No todo está\nen el frente.',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'La lista de ingredientes y la tabla nutricional cuentan el resto de la historia.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondary(context),
                height: 1.7,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            for (final item in [
              'Compara alimentos similares',
              'Revisa el tamaño de la porción',
              'Comprueba los alérgenos',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        CupertinoIcons.checkmark,
                        color: AppColors.green,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.about),
              child: const Text(
                'Cómo evaluamos',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _footer() => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 20,
    runSpacing: 8,
    children: [
      Text(
        'Hecho para elegir con más información.',
        style: TextStyle(fontSize: 10, color: AppColors.secondary(context)),
      ),
      InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.about),
        child: Text(
          'Datos abiertos de Open Food Facts ↗',
          style: TextStyle(fontSize: 10, color: AppColors.secondary(context)),
        ),
      ),
    ],
  );
}
