# uBuy

Aplicación Flutter/Dart para consultar alimentos en **Open Food Facts**, escanear
códigos de barras y conservar una bitácora de productos. Interfaz inspirada en
Recordatorios de Apple, con listas, favoritos, modo claro/oscuro y diseño adaptable.

## Ejecutar desde Android Studio

1. Abre la carpeta `uBuy` completa, donde está `pubspec.yaml`.
2. Instala los plugins **Flutter** y **Dart** y configura el SDK de Flutter.
   En el equipo de desarrollo está en `C:\flutter`.
3. Pulsa **Pub get** en `pubspec.yaml`.
4. Abre `lib/main.dart`, selecciona **Chrome (web)** o un dispositivo Android
   y pulsa **Run**.

En Windows, si aparece `Building with plugins requires symlink support`, activa
**Configuración → Sistema → Para desarrolladores → Modo de desarrollador** y
vuelve a ejecutar Pub get. Los proyectos Flutter con plugins nativos requieren
este permiso para crear enlaces simbólicos.

También puedes usar la terminal PowerShell de Android Studio desde esta carpeta:

```powershell
& "C:\flutter\bin\flutter.bat" pub get
& "C:\flutter\bin\flutter.bat" run -d chrome --web-port 7357
```

Usa siempre el mismo puerto al probar la versión web: las cuentas y los datos
locales pertenecen al origen del navegador (dominio y puerto). Un navegador
distinto o un puerto diferente tiene su propio almacenamiento.

Para un Android conectado por USB, activa la depuración USB, acepta la
autorización del teléfono y selecciónalo en Android Studio. También puedes
consultar su identificador con `flutter devices` y usar `flutter run -d ID`.

### Preparación y verificación de Android

Se verificó la compilación del APK de depuración, su instalación y el arranque
en un Motorola One físico. La pantalla del escáner se mostró en el dispositivo;
la lectura de productos y los demás gadgets requieren sus pruebas manuales.

El proyecto requiere el **NDK 28.2.13676358**. Si falta en otro equipo, abre
**Tools → SDK Manager → SDK Tools** en Android Studio, activa
**Show Package Details**, despliega **NDK (Side by side)** y selecciona
**28.2.13676358**. Aplica los cambios y espera a que termine la descarga. Después
selecciona tu teléfono o emulador y pulsa Run. La ejecución web no necesita el NDK.

`android/build.gradle.kts` añade `androidx.concurrent:concurrent-futures:1.2.0`
como `compileOnly` al módulo `camera_android_camerax`. Es el ajuste para que
CameraX 1.5.3 compile con Javac 25 sin el error de `CallbackToFutureAdapter`.

## Funciones disponibles

- Inicio centrado en un botón grande **Escanear**. El dashboard se conserva en
  **Resumen**: ambas secciones están en la barra inferior del teléfono y en
  la navegación lateral de escritorio. La cámara se abre al tocar Escanear.
- Búsqueda por nombre, marca o código, enviada al pulsar **Buscar**.
- Consulta real de ingredientes, alérgenos, nutrientes, Nutri-Score y NOVA.
- Puntuación orientativa uBuy del 1 al 10 y alternativas mejor puntuadas de la
  misma categoría cuando la nota es de 5 o menos.
- Escaneo de códigos EAN/UPC con cámara; alternativa de escritura manual.
- Dictado de la búsqueda mediante el micrófono. El usuario confirma la consulta
  con **Buscar**, evitando una llamada por cada palabra reconocida.
- Nuevas entradas con fotografía desde cámara o galería y notas personales.
- Persistencia local con SharedPreferences, incluyendo el contenido de las fotos.
- Favoritos, lista **Por comprar**, marcado de comprado y edición de notas.
- Registro e inicio de sesión locales; bitácoras separadas para cada cuenta e invitado.
- Navegación con Routes/Navigator, Drawer en pantallas pequeñas y transiciones Hero.

La lectura nutricional utiliza los indicadores que proporciona Open Food Facts
y reglas explicables. **Esta versión no integra IA ni necesita claves de IA.**
Las aportaciones locales no reciben un Nutri-Score o NOVA inventado ni se
publican automáticamente en Open Food Facts.

### Escala y alternativas

La puntuación propia de **uBuy** parte del Nutri-Score: **A=10, B=8, C=6,
D=4 y E=2**. Si NOVA es 4 se resta un punto; no se vuelven a puntuar azúcar,
sal o grasas, ya consideradas por Nutri-Score. Sin Nutri-Score se muestra
**Sin puntuación**, y sin NOVA se indica que la nota es parcial.

- **8–10:** perfil favorable.
- **6–7:** opción intermedia.
- **4–5:** mejor comparar.
- **1–3:** poco recomendable según estos indicadores.

Con **5 o menos**, el detalle busca automáticamente hasta **tres alternativas**
en un máximo de dos categorías específicas de Open Food Facts. Se excluyen el
producto original, duplicados, resultados de otras categorías, productos sin
nota o sin NOVA cuando el original sí lo tiene. Las alternativas deben tener
al menos **6/10**, una puntuación superior y un Nutri-Score igual o mejor.
Cada opción abre su ficha y explica la mejora. Si no hay datos o resultados
adecuados, se informa sin inventar sugerencias.

Esta escala es una heurística transparente de la aplicación, no una nota
oficial de Open Food Facts ni una evaluación personalizada. La explicación
completa está en **¿Cómo se calcula?** dentro del detalle.

## Permisos y prueba de gadgets

En web, cámara y micrófono requieren **localhost o HTTPS**, permiso del usuario
y soporte del navegador. Chrome o Edge son las opciones recomendadas para probar
el dictado. El reconocimiento de voz puede depender de servicios de red del
navegador o del dispositivo.

Para comprobar el escáner y la cámara Android es preferible un teléfono físico.
La galería permite seleccionar una foto; las imágenes locales se limitan a 1 MB
para cuidar el espacio del navegador. Los fallos de permisos y conexión se
muestran en la interfaz.

## Modo local y conexión opcional a Supabase

La app funciona sin configurar Supabase. En ese caso las cuentas son **locales
al dispositivo**; no son cuentas de Open Food Facts ni se sincronizan entre equipos.
Las contraseñas se guardan como hash PBKDF2 con sal aleatoria.

El código incluye adaptadores opcionales para Supabase Auth y tablas `entries`
y `contributions`. Activarlos requiere configurar un proyecto Supabase y sus
tablas/políticas de acceso, y proporcionar `SUPABASE_URL` y `SUPABASE_ANON_KEY`
mediante `--dart-define`. No es necesario para ejecutar ni probar el modo local.

### Qué ocurre con los códigos duplicados

En una misma bitácora local hay una entrada por código de barras: el formulario
rechaza un código ya guardado y guardar de nuevo desde una consulta reutiliza
la entrada existente. Las bitácoras de usuarios distintos son independientes;
dos personas pueden guardar el mismo código sin sobrescribir sus notas o fotos.

El adaptador opcional de Supabase publica aportaciones usando el identificador
de entrada (`id`), no una clave global por código de barras. Por tanto, el código
actual no garantiza que un catálogo compartido tenga un único producto por código.
Para esa garantía haría falta una tabla de productos con código único, bitácoras
que la referencien y aportaciones o revisiones vinculadas al producto existente.
Las nuevas entradas de uBuy no se publican automáticamente en Open Food Facts.

## Estructura

```text
lib/
  domain/          # Productos, entradas, perfiles y lectura nutricional
  data/            # Open Food Facts, almacenamiento local y autenticación
  application/     # Estado de la aplicación y servicio de dictado
  presentation/    # Pantallas, navegación, tema y widgets compartidos
test/              # Pruebas de navegación, diseño, almacenamiento y cuentas
```

La app solicita solo los gadgets elegidos: multimedia y audio/dictado.

## Verificación y compilación

```powershell
& "C:\flutter\bin\flutter.bat" analyze --no-pub
& "C:\flutter\bin\flutter.bat" test --no-pub
& "C:\flutter\bin\flutter.bat" build web --no-pub
```

La versión web compilada queda en `build/web`. Para Android de depuración:
`flutter build apk --debug --no-pub` (necesita Java, Android SDK y Gradle).

## Datos y créditos

Catálogo: [Open Food Facts](https://world.openfoodfacts.org).
Lectura por código: `/api/v3/product/{barcode}.json`.
Búsqueda textual: `/cgi/search.pl`, con respuestas JSON, paginación y campos
seleccionados. Los resultados se almacenan en caché durante la sesión y se
gestionan tiempos de espera, productos ausentes y límites de consultas.
Para alternativas se usa `/api/v2/search` con `categories_tags`,
`sort_by=nutriscore_score`, `page_size=24` y campos limitados. Las categorías
se conservan en los nuevos registros; las entradas antiguas siguen siendo
compatibles y pueden recuperar sus categorías por código al buscar alternativas.

Base de datos **ODbL**, contenidos **Database Contents License** e imágenes
**CC BY-SA**. La app muestra la atribución y enlaces a la ficha original.

## Reporte técnico

El reporte del proyecto incluye justificación, arquitectura, diagramas de clases,
flujo de datos, pruebas y revisión de los requisitos del parcial:

- [Documento Word .doc](docs/Reporte_Tecnico_uBuy.doc)
- [Documento Word .docx](docs/Reporte_Tecnico_uBuy.docx)
- [Versión PDF](docs/Reporte_Tecnico_uBuy.pdf)

Completa los datos de identificación de la portada antes de entregarlo.
