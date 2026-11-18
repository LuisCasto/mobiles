import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acerca de uBuy')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              CupertinoIcons.checkmark_seal_fill,
              color: AppColors.blue,
              size: 64,
            ),
            const SizedBox(height: 20),
            const Text(
              'Elegir mejor empieza\npor entender.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.3,
                height: 1.2,
              ),
            ),
            const SectionLabel('Qué hace uBuy'),
            const ContentCard(
              child: Text(
                'uBuy convierte el código de barras en una ficha fácil de entender. Puedes buscar alimentos, leer sus ingredientes, '
                'conservar una bitácora y crear aportaciones con cámara o galería. El micrófono te ayuda a dictar tus búsquedas.',
                style: TextStyle(height: 1.8),
              ),
            ),
            const SectionLabel('Cómo leemos una etiqueta'),
            const ContentCard(
              child: Text(
                'Nutri-Score resume el perfil nutricional con letras de A a E; resulta útil para comparar productos similares. '
                'NOVA clasifica el grado de procesamiento, del 1 al 4. Son indicadores distintos.\n\n'
                'La lectura nutricional usa reglas explicables sobre estos indicadores y los datos de la etiqueta. '
                'Si un dato falta, se muestra como no disponible. Las aportaciones locales no reciben un Nutri-Score ni un NOVA automático.',
                style: TextStyle(height: 1.8),
              ),
            ),
            const SectionLabel('Nuestra escala del 1 al 10'),
            const ContentCard(
              child: Text(
                'El índice uBuy es una escala propia y orientativa: Nutri-Score A=10, B=8, C=6, D=4 y E=2. '
                'Se resta 1 punto si el producto es NOVA 4. No se vuelven a penalizar los nutrientes que ya considera Nutri-Score.\n\n'
                '8–10: perfil favorable. 6–7: opción intermedia. 4–5: mejor comparar. 1–3: poco recomendable según estos indicadores. '
                'Si falta Nutri-Score no se asigna nota; si falta NOVA la nota es parcial. No es una calificación oficial de Open Food Facts.\n\n'
                'Con 5 o menos se consultan hasta dos categorías específicas del producto. Se muestran hasta tres alternativas '
                'con al menos 6/10, mejor puntuación y Nutri-Score igual o mejor. Si el original tiene NOVA, las alternativas '
                'también deben tenerlo. No se inventan sustitutos cuando faltan datos o no hay mejores resultados.',
                style: TextStyle(height: 1.8),
              ),
            ),
            const SectionLabel('Datos abiertos, crédito compartido'),
            ContentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'El catálogo y las fichas provienen de Open Food Facts, una base colaborativa. '
                    'Base de datos: Open Database License (ODbL). Contenidos individuales: Database Contents License. '
                    'Imágenes: Creative Commons Attribution-ShareAlike (CC BY-SA).\n\n'
                    'Las entradas creadas en uBuy se guardan en tu bitácora. Con Supabase configurado puedes compartirlas en la comunidad de uBuy; '
                    'no se publican automáticamente en Open Food Facts. El detalle incluye un enlace para contribuir allí.',
                    style: TextStyle(height: 1.8),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: () => runAction(context, () async {
                      if (!await launchUrl(
                        Uri.parse('https://world.openfoodfacts.org'),
                        mode: LaunchMode.externalApplication,
                      )) {
                        throw StateError('No se pudo abrir el sitio.');
                      }
                    }),
                    icon: const Icon(
                      CupertinoIcons.arrow_up_right_square,
                      size: 16,
                    ),
                    label: const Text('Conocer Open Food Facts'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'uBuy 1.0 · Flutter & Dart · Hecho para compartir conocimiento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondary(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
