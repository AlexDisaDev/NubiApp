# Nubi — revisión y v2

## 1. Qué he cambiado en el proyecto

**Archivos que sustituyes** (mismo nombre, contenido nuevo):
`Theme.swift`, `Almacen.swift`, `Paywall.swift`, `Suscripcion.swift`, `NubiApp.swift`, `VistaInicio.swift`

**Archivos nuevos:**
`Ilustraciones.swift`, `Componentes.swift`, `Modelos.swift`, `CalendarioVacunal.swift`,
`Recordatorios.swift`, `VistaLinea.swift`, `VistaCrecimiento.swift`, `VistaSalud.swift`,
`VistaDiario.swift`, `VistaAjustes.swift`

**Archivos que borras del proyecto:**
- `ContentView.swift` — es la plantilla de Xcode, no se usaba.
- `Models.swift` — lo sustituye `Modelos.swift`.
- `CintaDelDia.swift` — ahora vive dentro de `VistaLinea.swift`.

**Archivo que se queda igual:** `VentanasDespierto.swift`.

---

## 2. Errores y riesgos que había

| | Qué pasaba | Estado |
|---|---|---|
| 1 | El paywall escribía **"Probar 7 días gratis"** a mano en dos sitios. Si cambias la oferta en App Store Connect, la app miente. Es causa típica de rechazo por la guía 3.1.2. | Corregido: todo sale de `Product` vía `suscripcion.textoLlamada`. |
| 2 | `registros` tenía `didSet { guardar() }`, así que escribía a disco **durante la carga inicial** y en cada paso intermedio. | Corregido con una bandera `cargando` y guardado explícito. |
| 3 | `cerrarSueñosAbiertos` podía dejar un sueño con duración 0 o negativa. | Corregido con el mismo mínimo de 1 min que `terminarSueño`. |
| 4 | No había forma de **borrar los datos** ni de exportarlos. | Añadido en Ajustes (borrado total + CSV compartible). |
| 5 | El `.storekit` describe el producto como *"Ventanas adaptadas, avisos, historial y **sonidos**"*, y la app no tiene sonidos. Ese texto también va en App Store Connect. | **Te toca a ti**: quita "sonidos" de la descripción, o impleméntalos. |
| 6 | `https://nubi.app/privacidad` y `/terminos` no existen. | **Bloqueante**: sin una URL de privacidad que responda de verdad, App Store Connect no te deja enviar la app. |
| 7 | Sin icono de app ni pantalla de lanzamiento. | **Te toca a ti** (ver punto 5). |

---

## 3. Estructura nueva

Cinco pestañas, que es el máximo que entra en un iPhone X sin que aparezca el menú "Más":

1. **Hoy** — registro rápido, contador de sueño en vivo, predicción de ventana, últimas 24 h, próxima cita. Ajustes está en el botón de arriba a la derecha.
2. **Día** — la línea de tiempo, sola, con selector de día. Arriba la cinta del cielo (00:00 → 24:00) y debajo la línea vertical donde van cayendo los registros en orden, con los huecos de vigilia etiquetados.
3. **Crece** — peso, estatura y perímetro craneal. Tres cifras arriba, curva de evolución y historial editable.
4. **Salud** — dos secciones: calendario vacunal español desplegable por edades (con marcado y fecha) y citas de pediatra/enfermería con aviso local la tarde anterior.
5. **Diario** — anécdotas e hitos, con filtro "Solo hitos".

### Iconografía
No queda ni un solo SF Symbol. `Ilustraciones.swift` define 24 símbolos dibujados con formas de SwiftUI sobre un lienzo de 24×24 (nube, luna, sol, biberón, corazón, hoja, báscula, regla, jeringa, botiquín, calendario, cuaderno…). Se escalan a cualquier tamaño sin perder nitidez y todos comparten el mismo grosor de trazo, así que la app tiene cara propia.

La barra de pestañas también es propia: la del sistema obliga a usar SF Symbols.

### Qué es de pago
- Predicción de ventanas
- Historial más allá de ayer
- Curva de crecimiento (con 3+ medidas)
- Diario ilimitado (gratis: 5 entradas)

**Vacunas y citas quedan gratis a propósito.** Cobrar por que un padre vea cuándo toca una vacuna da mala imagen y trae reseñas malas; además es lo que engancha a abrir la app fuera de la crisis del sueño.

---

## 4. Cómo lo montas en Xcode

1. Arrastra los archivos nuevos al proyecto (marcando *Copy items if needed* y el target Nubi).
2. Borra del proyecto `ContentView.swift`, `Models.swift` y `CintaDelDia.swift` (**Move to Trash**).
3. Target → General → **Minimum Deployments: iOS 16.0**. Es el tope del iPhone X.
4. Signing & Capabilities: **no hace falta** añadir capacidad de notificaciones; los avisos locales funcionan solo con `requestAuthorization`.
5. Edit Scheme → Run → Options → **StoreKit Configuration: Nubi.storekit** para probar la compra en el simulador y en tu iPhone.
6. Compila. Si algo se queja, suele ser un archivo antiguo que sigue en el target.

Los datos antiguos (`nubi.json`) se leen sin problema: los campos nuevos son opcionales.

---

## 5. Lo que falta para poder enviar a la App Store

Por orden de bloqueo:

1. **URL de política de privacidad que exista.** Es obligatoria y se comprueba. Una página estática en GitHub Pages o Notion sirve. Cambia las dos URLs de `Paywall.swift` y `VistaAjustes.swift`.
2. **Ficha de privacidad en App Store Connect.** Como no sales del iPhone, marcas *No se recopilan datos*. Esto es una ventaja competitiva real frente a Napper: dilo en la descripción.
3. **Icono de app** (1024×1024, sin transparencia, sin esquinas redondeadas). Con la paleta y la nube de `Ilus` tienes la base.
4. **Capturas**: necesitas 6,7" y 6,5". Las de 5,8" (tu iPhone X) ya no son obligatorias pero se aceptan.
5. **Categoría**: te recomiendo *Estilo de vida* o *Salud y forma física*. Si la pones en *Medicina*, la revisión es notablemente más exigente con las afirmaciones.
6. **Family Sharing**: en el `.storekit` está a `true`, actívalo también en App Store Connect o el paywall estará prometiendo algo que no da.
7. **Textos de suscripción en la ficha**: precio, duración y qué incluye, en la descripción de la app. Apple lo pide explícitamente para apps con suscripción.
8. Quita "sonidos" de la descripción de los productos.

---

## 6. Sobre los ingresos pasivos — lo que veo

Te lo digo claro porque es mejor saberlo antes de invertir dos meses:

**El seguimiento del sueño infantil es una categoría carísima de conquistar.** Napper y Huckleberry gastan mucho en ASO y en contenido, y la palabra clave "sueño bebé" está peleada. Publicar la app y esperar no va a producir ingresos apreciables.

**Dónde sí tienes un hueco:**
- **En español y sin cuenta.** Napper te obliga a registrarte y su traducción es regular. "Todo se queda en tu iPhone" es un argumento que en España vende, especialmente con datos de un bebé.
- **Ya no es solo sueño.** Con vacunas, citas, medidas y diario, lo que tienes es *la libreta del bebé completa*. Ese es un posicionamiento distinto y menos peleado que "app de sueño". Yo cambiaría el enfoque de la ficha hacia ahí y dejaría la predicción de sueño como la función estrella, no como la definición del producto.
- El calendario vacunal español bien hecho es algo que las apps grandes (americanas) no tienen.

**Lo realista:** con 9,99 €/año y sin marketing, hablamos de decenas de euros al mes en el mejor de los casos durante el primer año. Como proyecto de portfolio y como cosa que crece despacio, tiene sentido. Como fuente de ingresos pasivos que note tu nómina, no, salvo que le dediques esfuerzo continuado a ASO y a contenido (que ya no sería pasivo).

Una prueba barata antes de invertir más: publica la v1, mira la tasa de conversión del paywall a los 30 días. Si está por debajo del 2 %, el problema es el producto o el posicionamiento, no el precio.
