import SwiftUI

// MARK: - Contenedores

struct Tarjeta<Content: View>: View {
    var relleno: CGFloat = Theme.margen
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.superficie,
                in: RoundedRectangle(cornerRadius: Theme.radio, style: .continuous)
            )
            .shadow(color: Theme.sombra, radius: 14, y: 6)
    }
}

struct EtiquetaSeccion: View {
    let texto: String

    var body: some View {
        Text(texto.uppercased())
            .font(Theme.etiqueta)
            .tracking(1.4)
            .foregroundStyle(Theme.tintaSuave)
    }
}

/// Cabecera de pantalla. Siempre el mismo formato: título serif grande y,
/// opcionalmente, una acción a la derecha.
struct Cabecera<Accion: View>: View {
    let titulo: String
    var subtitulo: String?
    @ViewBuilder var accion: Accion

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.tinta)

                if let subtitulo {
                    Text(subtitulo)
                        .font(Theme.cuerpo(13))
                        .foregroundStyle(Theme.tintaTenue)
                }
            }

            Spacer()

            accion
        }
        .padding(.top, 6)
    }
}

extension Cabecera where Accion == EmptyView {
    init(_ titulo: String, subtitulo: String? = nil) {
        self.init(titulo: titulo, subtitulo: subtitulo) {
            EmptyView()
        }
    }
}

// MARK: - Insignia (icono dentro de un círculo de color)

struct Insignia: View {
    let simbolo: Ilus.Simbolo
    var fondo: Color = Theme.lila
    var diametro: CGFloat = 36
    var tinta: Color = Theme.tinta

    var body: some View {
        Ilus(simbolo, diametro * 0.46, color: tinta)
            .frame(width: diametro, height: diametro)
            .background(fondo, in: Circle())
    }
}

// MARK: - Botones

struct Boton: View {
    let titulo: String
    var simbolo: Ilus.Simbolo?
    let color: Color
    var compacto = false
    let accion: () -> Void

    init(
        titulo: String,
        simbolo: Ilus.Simbolo? = nil,
        color: Color,
        compacto: Bool = false,
        accion: @escaping () -> Void
    ) {
        self.titulo = titulo
        self.simbolo = simbolo
        self.color = color
        self.compacto = compacto
        self.accion = accion
    }

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 8) {
                if let simbolo {
                    Ilus(simbolo, compacto ? 15 : 17, color: Theme.tinta)
                }

                Text(titulo)
                    .font(Theme.cuerpo(compacto ? 14 : 15, .semibold))
                    .foregroundStyle(Theme.tinta)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compacto ? 11 : 15)
            .background(color, in: Capsule())
        }
        .buttonStyle(BotonPresionable())
    }
}

struct BotonSecundario: View {
    let titulo: String
    var simbolo: Ilus.Simbolo?
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 7) {
                if let simbolo {
                    Ilus(simbolo, 14, color: Theme.indigo)
                }

                Text(titulo)
                    .font(Theme.cuerpo(14, .medium))
                    .foregroundStyle(Theme.indigo)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.lila.opacity(0.20), in: Capsule())
        }
        .buttonStyle(BotonPresionable())
    }
}

struct BotonIcono: View {
    let simbolo: Ilus.Simbolo
    var color: Color = Theme.lila
    var diametro: CGFloat = 44
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Insignia(simbolo: simbolo, fondo: color, diametro: diametro)
        }
        .buttonStyle(BotonPresionable())
    }
}

/// Botón específico para lactancia materna: corazón + letra D/I debajo.
struct BotonPecho: View {
    let lado: LadoPecho
    var color: Color = Theme.melocoton
    var diametro: CGFloat = 40
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            VStack(spacing: 3) {
                Insignia(
                    simbolo: .corazon,
                    fondo: color,
                    diametro: diametro
                )

                Text(lado.letra)
                    .font(Theme.cuerpo(10, .bold))
                    .foregroundStyle(Theme.tintaSuave)
            }
        }
        .buttonStyle(BotonPresionable())
        .accessibilityLabel(lado.titulo)
    }
}

/// Micro-interacción única de la app: todo lo pulsable se hunde un poco.
struct BotonPresionable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Piezas menores

struct Pastilla: View {
    let texto: String
    var color: Color = Theme.lila

    var body: some View {
        Text(texto)
            .font(Theme.cuerpo(12, .medium))
            .foregroundStyle(Theme.indigo)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.20), in: Capsule())
    }
}

struct EstadoVacio: View {
    let simbolo: Ilus.Simbolo
    let titulo: String
    let texto: String
    var color: Color = Theme.lila

    var body: some View {
        VStack(spacing: 12) {
            Insignia(simbolo: simbolo, fondo: color, diametro: 68)

            Text(titulo)
                .font(Theme.display(20))
                .foregroundStyle(Theme.tinta)

            Text(texto)
                .font(Theme.cuerpo(13))
                .foregroundStyle(Theme.tintaSuave)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
    }
}

struct OpcionSelector<T: Hashable>: Identifiable {
    let valor: T
    let titulo: String

    var id: T { valor }
}

struct SelectorNubi<T: Hashable>: View {
    let opciones: [OpcionSelector<T>]
    @Binding var seleccion: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(opciones) { op in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        seleccion = op.valor
                    }
                } label: {
                    Text(op.titulo)
                        .font(Theme.cuerpo(14, .semibold))
                        .foregroundStyle(
                            seleccion == op.valor
                                ? Theme.tinta
                                : Theme.tintaSuave
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if seleccion == op.valor {
                                Capsule()
                                    .fill(Theme.superficie)
                                    .shadow(color: Theme.sombra, radius: 6, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.lila.opacity(0.18), in: Capsule())
    }
}

struct Desplegable<Content: View>: View {
    let titulo: String
    var subtitulo: String?
    var insignia: (Ilus.Simbolo, Color)?
    @State private var abierto: Bool
    @ViewBuilder var contenido: Content

    init(
        titulo: String,
        subtitulo: String? = nil,
        insignia: (Ilus.Simbolo, Color)? = nil,
        abiertoInicial: Bool = false,
        @ViewBuilder contenido: () -> Content
    ) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.insignia = insignia
        self._abierto = State(initialValue: abiertoInicial)
        self.contenido = contenido()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    abierto.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    if let insignia {
                        Insignia(
                            simbolo: insignia.0,
                            fondo: insignia.1,
                            diametro: 34
                        )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(titulo)
                            .font(Theme.cuerpo(15, .semibold))
                            .foregroundStyle(Theme.tinta)

                        if let subtitulo {
                            Text(subtitulo)
                                .font(Theme.cuerpo(12))
                                .foregroundStyle(Theme.tintaSuave)
                        }
                    }

                    Spacer()

                    Ilus(.chevronDer, 15, color: Theme.tintaTenue)
                        .rotationEffect(.degrees(abierto ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if abierto {
                VStack(alignment: .leading, spacing: 10) {
                    contenido
                }
                .padding(.top, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Gráfica de línea dibujada a mano

struct PuntoGrafica: Identifiable {
    let id = UUID()
    let fecha: Date
    let valor: Double
}

struct GraficaLinea: View {
    let puntos: [PuntoGrafica]
    var color: Color = Theme.indigo
    var alto: CGFloat = 130

    private var rango: (min: Double, max: Double) {
        let vs = puntos.map(\.valor)
        let lo = vs.min() ?? 0
        let hi = vs.max() ?? 1
        let margen = max((hi - lo) * 0.18, 0.4)
        return (lo - margen, hi + margen)
    }

    var body: some View {
        GeometryReader { geo in
            let ps = coordenadas(w: geo.size.width, h: geo.size.height)

            ZStack {
                if ps.count >= 2 {
                    area(ps, h: geo.size.height)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.22), color.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    curva(ps)
                        .stroke(
                            color,
                            style: StrokeStyle(
                                lineWidth: 2.6,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }

                ForEach(Array(ps.enumerated()), id: \.offset) { _, punto in
                    Circle()
                        .fill(Theme.superficie)
                        .overlay(Circle().strokeBorder(color, lineWidth: 2.4))
                        .frame(width: 9, height: 9)
                        .position(punto)
                }
            }
        }
        .frame(height: alto)
    }

    private func coordenadas(w: CGFloat, h: CGFloat) -> [CGPoint] {
        guard !puntos.isEmpty else { return [] }

        let orden = puntos.sorted { $0.fecha < $1.fecha }
        let t0 = orden[0].fecha.timeIntervalSince1970
        let t1 = orden[orden.count - 1].fecha.timeIntervalSince1970
        let dt = max(t1 - t0, 1)
        let r = rango
        let dv = max(r.max - r.min, 0.001)

        return orden.map { p in
            let x: CGFloat = orden.count == 1
                ? w / 2
                : CGFloat((p.fecha.timeIntervalSince1970 - t0) / dt) * (w - 12) + 6

            let y = h - CGFloat((p.valor - r.min) / dv) * (h - 16) - 8

            return CGPoint(x: x, y: y)
        }
    }

    private func curva(_ ps: [CGPoint]) -> Path {
        var path = Path()
        guard let first = ps.first else { return path }

        path.move(to: first)

        for i in 1..<ps.count {
            let a = ps[i - 1]
            let b = ps[i]
            let mx = (a.x + b.x) / 2

            path.addCurve(
                to: b,
                control1: CGPoint(x: mx, y: a.y),
                control2: CGPoint(x: mx, y: b.y)
            )
        }

        return path
    }

    private func area(_ ps: [CGPoint], h: CGFloat) -> Path {
        var path = curva(ps)

        if let last = ps.last, let first = ps.first {
            path.addLine(to: CGPoint(x: last.x, y: h))
            path.addLine(to: CGPoint(x: first.x, y: h))
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Menú de teta personalizado (para pantalla Hoy)

struct MenuPecho: View {
    let onSelect: (LadoPecho) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            botonLado(.izquierda)
            botonLado(.derecha)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radio, style: .continuous)
                .fill(Theme.superficie)
                .shadow(color: Theme.sombraFuerte, radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radio, style: .continuous)
                .strokeBorder(Theme.separador, lineWidth: 1)
        )
    }
    
    private func botonLado(_ lado: LadoPecho) -> some View {
        Button {
            onSelect(lado)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.melocoton)
                        .frame(width: 36, height: 36)
                    
                    Ilus(.corazon, 16, color: Theme.tinta)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(lado.titulo)
                        .font(Theme.cuerpo(14, .semibold))
                        .foregroundStyle(Theme.tinta)
                    
                    Text("Pecho \(lado.letra)")
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaSuave)
                }
                
                Spacer(minLength: 0)
                
                Ilus(.chevronDer, 12, color: Theme.tintaTenue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.radioChico, style: .continuous)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BotonPresionable())
    }
}

// MARK: - Menú de teta para hoja de hora (pantalla Día)

struct MenuPechoHora: View {
    let onSelect: (LadoPecho) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            botonLado(.izquierda)
            botonLado(.derecha)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radio, style: .continuous)
                .fill(Theme.superficie)
                .shadow(color: Theme.sombraFuerte, radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radio, style: .continuous)
                .strokeBorder(Theme.separador, lineWidth: 1)
        )
    }
    
    private func botonLado(_ lado: LadoPecho) -> some View {
        Button {
            onSelect(lado)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.melocoton)
                        .frame(width: 36, height: 36)
                    
                    Ilus(.corazon, 16, color: Theme.tinta)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(lado.titulo)
                        .font(Theme.cuerpo(14, .semibold))
                        .foregroundStyle(Theme.tinta)
                    
                    Text("Elegir hora")
                        .font(Theme.cuerpo(11))
                        .foregroundStyle(Theme.tintaSuave)
                }
                
                Spacer(minLength: 0)
                
                Ilus(.reloj, 14, color: Theme.tintaTenue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.radioChico, style: .continuous)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BotonPresionable())
    }

    /// Barra horizontal de 0 a 24 horas con:
    /// - Zona de rango óptimo destacada dentro
    /// - Círculo grande que muestra las horas dormidas
    /// - Borde dinámico: naranja si está fuera del rango, verde si está dentro
    struct BarraSueño24h: View {
        let horas: Double
        let rango: ClosedRange<Double>

        private var dentro: Bool {
            rango.contains(horas)
        }

        private var colorBorde: Color {
            dentro ? Theme.menta : Theme.melocoton
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                EtiquetaSeccion(texto: "Sueño de hoy")

                GeometryReader { geo in
                    let ancho = geo.size.width
                    let alto: CGFloat = 34

                    // Posiciones
                    let posHoras    = CGFloat(min(max(horas, 0), 24) / 24) * ancho
                    let posRangoIni = CGFloat(max(rango.lowerBound, 0) / 24) * ancho
                    let posRangoFin = CGFloat(min(rango.upperBound, 24) / 24) * ancho
                    let anchoRango  = max(4, posRangoFin - posRangoIni)

                    ZStack(alignment: .leading) {
                        // Fondo de la barra con gradiente día/noche sutil
                        LinearGradient(
                            colors: [
                                Theme.indigo.opacity(0.15),
                                Theme.cielo.opacity(0.20),
                                Theme.cielo.opacity(0.20),
                                Theme.indigo.opacity(0.15)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: alto)

                        // Zona de rango óptimo
                        Rectangle()
                            .fill(Theme.menta.opacity(0.45))
                            .frame(width: anchoRango, height: alto)
                            .offset(x: posRangoIni)

                        // Marcas de 6, 12, 18
                        ForEach([6, 12, 18], id: \.self) { h in
                            Rectangle()
                                .fill(Theme.tintaTenue.opacity(0.4))
                                .frame(width: 1, height: alto)
                                .offset(x: CGFloat(h) / 24 * ancho)
                        }

                        // Círculo con las horas dentro
                        ZStack {
                            Circle()
                                .fill(Theme.superficie)
                                .overlay(Circle().strokeBorder(colorBorde, lineWidth: 3))
                                .frame(width: 44, height: 44)
                                .shadow(color: Theme.sombra, radius: 4, y: 2)

                            Text(formatear(horas))
                                .font(Theme.cuerpo(11, .bold))
                                .foregroundStyle(Theme.tinta)
                                .monospacedDigit()
                        }
                        .offset(x: max(22, min(posHoras, ancho - 22)) - 22)
                    }
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(colorBorde, lineWidth: 2.5)
                    )
                }
                .frame(height: 44) // Altura del círculo + margen

                // Etiquetas debajo
                HStack {
                    Text("0h")
                        .font(Theme.cuerpo(9))
                        .foregroundStyle(Theme.tintaTenue)

                    Spacer()

                    Text("12h")
                        .font(Theme.cuerpo(9))
                        .foregroundStyle(Theme.tintaTenue)

                    Spacer()

                    Text("24h")
                        .font(Theme.cuerpo(9))
                        .foregroundStyle(Theme.tintaTenue)
                }
                .padding(.horizontal, 4)
            }
        }

        private func formatear(_ h: Double) -> String {
            let horas = Int(h)
            let minutos = Int((h - Double(horas)) * 60)
            if minutos == 0 {
                return "\(horas)h"
            }
            return "\(horas)h\(minutos)"
        }
    }
}